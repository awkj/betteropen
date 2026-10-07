// swift-tools-version: 6.4
import PackageDescription

// 无第三方依赖的配置核心同时参与 Xcode 应用编译。
let package = Package(
    name: "BetterOpenCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BetterOpenCore", targets: ["BetterOpenCore"])],
    targets: [
        .target(name: "BetterOpenCore", path: "betteropen/Core"),
        .testTarget(name: "BetterOpenCoreTests", dependencies: ["BetterOpenCore"], path: "Tests/BetterOpenCoreTests")
    ]
)
