// swift-tools-version: 5.9
import PackageDescription

let vendorLib = "\(Context.packageDirectory)/Vendor/lib"

let package = Package(
    name: "MacMedia",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacMedia", targets: ["MacMedia"]),
        .executable(name: "MacMediaTestRunner", targets: ["MacMediaTestRunner"]),
        .library(name: "MacMediaCore", targets: ["MacMediaCore"])
    ],
    targets: [
        .target(
            name: "CMpv",
            path: "Sources/CMpv",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("mpv"),
                .unsafeFlags([
                    "-L\(vendorLib)",
                    "-Xlinker", "-rpath", "-Xlinker", vendorLib
                ])
            ]
        ),
        .target(
            name: "MacMediaCore",
            dependencies: ["CMpv"],
            path: "Sources/MacMediaCore",
            linkerSettings: [
                .linkedLibrary("mpv"),
                .linkedFramework("Carbon"),
                .unsafeFlags([
                    "-L\(vendorLib)",
                    "-Xlinker", "-rpath", "-Xlinker", vendorLib
                ])
            ]
        ),
        .executableTarget(
            name: "MacMedia",
            dependencies: ["MacMediaCore"],
            path: "Sources/MacMedia",
            cSettings: [
                .define("GL_SILENCE_DEPRECATION")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-DGL_SILENCE_DEPRECATION"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("OpenGL"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .unsafeFlags([
                    "-L\(vendorLib)",
                    "-Xlinker", "-rpath", "-Xlinker", vendorLib,
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .executableTarget(
            name: "MacMediaTestRunner",
            dependencies: ["MacMediaCore"],
            path: "Tests/MacMediaTestRunner",
            linkerSettings: [
                .linkedLibrary("mpv"),
                .unsafeFlags([
                    "-L\(vendorLib)",
                    "-Xlinker", "-rpath", "-Xlinker", vendorLib
                ])
            ]
        ),
    ]
)
