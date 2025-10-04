// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftfulGamification",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftfulGamification",
            targets: ["SwiftfulGamification"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftfulThinking/IdentifiableByString.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftfulGamification",
            dependencies: [
                .product(name: "IdentifiableByString", package: "IdentifiableByString"),
            ]
        ),
        .testTarget(
            name: "SwiftfulGamificationTests",
            dependencies: ["SwiftfulGamification"]
        ),
    ]
)
