// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PaperloftKit",
    platforms: [.macOS("27.0")],
    products: [.library(name: "PaperloftKit", targets: ["PaperloftKit"]),
               .executable(name: "PaperloftEval", targets: ["PaperloftEval"]),
               .executable(name: "PaperloftCrashWorker", targets: ["PaperloftCrashWorker"])],
    targets: [
        .target(name: "PaperloftKit"),
        .executableTarget(name: "PaperloftEval", dependencies: ["PaperloftKit"], path: "Tools/PaperloftEval"),
        .executableTarget(name: "PaperloftCrashWorker", dependencies: ["PaperloftKit"], path: "Tools/PaperloftCrashWorker"),
        .testTarget(name: "PaperloftKitTests", dependencies: ["PaperloftKit"])
    ],
    swiftLanguageModes: [.v6]
)
