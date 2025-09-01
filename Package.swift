// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UserKit",
    platforms: [
        .iOS(.v15) // 设置支持的最低iOS版本
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "UserKit",
            targets: ["UserKit"]),
    ],
    dependencies: [
        // 依赖GitHub上的 CoreNetworkKit
        .package(url: "https://github.com/vimo-ai/CoreNetworkKit.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "UserKit",
            dependencies: [
                // UserKit 的代码依赖 CoreNetworkKit 提供的功能
                .product(name: "CoreNetworkKit", package: "CoreNetworkKit")
            ]
        ),
        .testTarget(
            name: "UserKitTests",
            dependencies: ["UserKit"]),
    ]
)