// swift-tools-version: 6.0
import PackageDescription

/// UI 非依存のドメイン層。Foundation + GRDB のみ。Linux でも `swift test` が通る。
let package = Package(
    name: "Domain",
    platforms: [.macOS(.v14)],
    products: [.library(name: "Domain", targets: ["Domain"])],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(name: "Domain", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
    ]
)
