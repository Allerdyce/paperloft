// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PaperloftHandoff",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PaperloftHandoff", targets: ["PaperloftHandoff"])],
    targets: [.target(name: "PaperloftHandoff"),
              .testTarget(name: "PaperloftHandoffTests", dependencies: ["PaperloftHandoff"])],
    swiftLanguageModes: [.v6]
)
