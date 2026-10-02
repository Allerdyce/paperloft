// swift-tools-version: 6.0
// Verifier-owned harness (P4, AC-12). Not product code. Depends on the PaperloftKit package in the
// verifier's fresh clone at 28c3cef so it exercises the exact exporter under review.
import PackageDescription
let package = Package(
    name: "IndependentExport",
    platforms: [.macOS("27.0")],
    dependencies: [.package(path: "../../checkouts/p4-28c3cef/Packages/PaperloftKit")],
    targets: [
        .executableTarget(name: "IndependentExport", dependencies: [.product(name: "PaperloftKit", package: "PaperloftKit")])
    ],
    swiftLanguageModes: [.v5]
)
