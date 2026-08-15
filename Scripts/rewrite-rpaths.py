#!/usr/bin/env python3
"""Copy libmpv and recursive dylibs, rewriting install names to @rpath."""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

LIB_DIR = Path(sys.argv[1] if len(sys.argv) > 1 else "Vendor/lib").resolve()
LIB_DIR.mkdir(parents=True, exist_ok=True)

HOMEBREW_PREFIXES = ("/opt/homebrew", "/usr/local/opt", "/usr/local/Cellar")


def otool(path: Path) -> list[str]:
    out = subprocess.check_output(["otool", "-L", str(path)], text=True)
    deps = []
    for line in out.splitlines()[1:]:
        dep = line.strip().split(" (")[0]
        if dep:
            deps.append(dep)
    return deps


def install_name(path: Path) -> str | None:
    out = subprocess.check_output(["otool", "-D", str(path)], text=True)
    lines = [line.strip() for line in out.splitlines() if line.strip()]
    return lines[-1] if len(lines) > 1 else None


def copy_if_needed(src: Path) -> Path:
    dest = LIB_DIR / src.name
    if src.resolve() != dest.resolve():
        shutil.copy2(src, dest)
    return dest


def is_bundled_dep(dep: str) -> bool:
    return dep.startswith(HOMEBREW_PREFIXES) or dep.startswith("@rpath") or Path(dep).name.startswith("lib")


def collect(root: Path) -> set[Path]:
    seen: set[Path] = set()
    queue = [root]
    while queue:
        current = queue.pop()
        current = current.resolve()
        if current in seen or not current.exists():
            continue
        seen.add(current)
        for dep in otool(current):
            if dep.startswith("/usr/lib") or dep.startswith("/System/"):
                continue
            if dep.startswith("@rpath") or dep.startswith("@loader_path") or dep.startswith("@executable_path"):
                candidate = LIB_DIR / Path(dep).name
                if candidate.exists():
                    queue.append(candidate)
                continue
            path = Path(dep)
            if path.exists():
                queue.append(path)
    return seen


def rewrite(path: Path) -> None:
    name = path.name
    subprocess.run(["install_name_tool", "-id", f"@rpath/{name}", str(path)], check=False)
    for dep in otool(path):
        if dep.startswith("/usr/lib") or dep.startswith("/System/"):
            continue
        dep_name = Path(dep).name
        if dep.startswith(HOMEBREW_PREFIXES) or Path(dep).exists():
            subprocess.run(
                ["install_name_tool", "-change", dep, f"@rpath/{dep_name}", str(path)],
                check=False,
            )


def main() -> None:
    roots = list(LIB_DIR.glob("libmpv*.dylib"))
    if not roots:
        print("No libmpv dylib found in", LIB_DIR, file=sys.stderr)
        sys.exit(1)
    all_libs: set[Path] = set()
    for root in roots:
        all_libs |= collect(root)
    for lib in sorted(all_libs):
        if any(str(lib).startswith(p) for p in HOMEBREW_PREFIXES):
            copy_if_needed(lib)
    for lib in LIB_DIR.glob("*.dylib"):
        rewrite(lib)
    # Compatibility names (libavcodec.62.dylib -> libavcodec.62.28.101.dylib)
    needed: set[str] = set()
    for lib in LIB_DIR.glob("*.dylib"):
        if lib.is_symlink():
            continue
        for dep in otool(lib):
            if dep.startswith("@rpath/"):
                needed.add(Path(dep).name)
    for name in sorted(needed):
        dest = LIB_DIR / name
        if dest.exists():
            continue
        prefix = name.replace(".dylib", "")
        matches = [
            p for p in LIB_DIR.glob("*.dylib")
            if p.name.startswith(prefix) and not p.is_symlink()
        ]
        if matches:
            dest.symlink_to(matches[0].name)
            print("symlink", name, "->", matches[0].name)
    print("Rewrote rpaths for", len(list(LIB_DIR.glob("*.dylib"))), "dylibs")


if __name__ == "__main__":
    main()
