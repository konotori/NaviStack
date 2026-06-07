// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NaviStack",
	platforms: [
		.iOS(.v16),
		.macOS(.v13)
	],
    products: [
        .library(
            name: "NaviStack",
            targets: ["NaviStack"]
        ),
    ],
    targets: [
        .target(
            name: "NaviStack"
        ),
        .testTarget(
            name: "NaviStackTests",
            dependencies: ["NaviStack"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
