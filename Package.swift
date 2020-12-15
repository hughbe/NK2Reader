// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NK2Reader",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "NK2Reader",
            targets: ["NK2Reader"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/hughbe/DataStream", from: "2.0.0"),
        .package(name: "MAPI", url: "https://github.com/hughbe/SwiftMAPI", from: "1.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "NK2Reader",
            dependencies: ["DataStream", "MAPI"]),
        .testTarget(
            name: "NK2ReaderTests",
            dependencies: ["NK2Reader"],
            resources: [.process("Resources")]),
    ]
)
