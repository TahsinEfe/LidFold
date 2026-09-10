// swift-tools-version: 6.0
import PackageDescription

// LidFold is layered from the inside out. Every arrow points towards LidFoldCore,
// which knows nothing about AppKit, Metal, IOKit or ScreenCaptureKit and is therefore
// the only layer that can be unit tested without a display, a GPU or a lid sensor.
//
//   LidFold (executable, composition root)
//     └── LidFoldApp ── LidFoldRender ─┐
//            ├── LidFoldCapture ───────┤
//            └── LidFoldSensing ───────┴── LidFoldCore
let package = Package(
    name: "LidFold",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LidFold", targets: ["LidFold"]),
        .library(name: "LidFoldCore", targets: ["LidFoldCore"])
    ],
    targets: [
        .target(name: "LidFoldCore"),
        .target(name: "LidFoldSensing", dependencies: ["LidFoldCore"]),
        .target(name: "LidFoldCapture", dependencies: ["LidFoldCore"]),
        .target(name: "LidFoldRender", dependencies: ["LidFoldCore"]),
        .target(name: "LidFoldApp", dependencies: ["LidFoldCore", "LidFoldSensing", "LidFoldCapture", "LidFoldRender"]),
        .executableTarget(name: "LidFold", dependencies: ["LidFoldApp"]),
        .testTarget(name: "LidFoldCoreTests", dependencies: ["LidFoldCore"])
    ],
    swiftLanguageModes: [.v5]
)
