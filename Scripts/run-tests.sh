#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c debug --product MacMediaTestRunner
"$(swift build -c debug --show-bin-path)/MacMediaTestRunner"
