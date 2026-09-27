// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PaperloftKit",
    platforms: [.macOS("27.0")],
    products: [.library(name: "PaperloftKit", targets: ["PaperloftKit"])],
    targets: [
        .target(name: "PaperloftKit"),
        .testTarget(name: "PaperloftKitTests", dependencies: ["PaperloftKit"])
    ],
    swiftLanguageModes: [.v6]
)
