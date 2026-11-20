// swift-tools-version: 6.0
// WGPUKit — the GPU foundation shared by SwiftXUI and the shader/format packages built on wgpu-native.
// No UI, no laser, no file-format code: only the C API, the device/queue handle, and GLSL on WGPU.

import PackageDescription

let package = Package(
    name: "WGPUKit",
    products: [
        .library(name: "CWGPU", targets: ["CWGPU"]),
        .library(name: "WGPUKit", targets: ["WGPUKit"]),
        .library(name: "GLSLWGPU", targets: ["GLSLWGPU"]),
    ],
    targets: [
        // wgpu-native prebuilt, assembled by Scripts/fetch-wgpu.sh (not in git).
        .binaryTarget(
            name: "CWGPU",
            path: "Vendor/CWGPU.xcframework"
        ),
        .target(
            name: "WGPUKit",
            dependencies: ["CWGPU"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("Metal", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("QuartzCore", .when(platforms: [.macOS, .iOS])),
                .linkedFramework("IOSurface", .when(platforms: [.iOS])),
                .linkedLibrary("c++"),
            ]
        ),
        // GLSL on WGPU (wgpu's naga front end). Grows to hold the std140 writer, the offscreen pass and the async readback.
        .target(
            name: "GLSLWGPU",
            dependencies: ["WGPUKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
