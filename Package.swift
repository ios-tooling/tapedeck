// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TapeDeck",
	 platforms: [
				 .macOS(.v15),
				 .iOS(.v18)
		  ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TapeDeck",
            targets: ["TapeDeck"]),
    ],
	 dependencies: [
		.package(url: "https://github.com/ios-tooling/Suite", from: "1.4.11"),
		.package(url: "https://github.com/ios-tooling/Chronicle", from: "0.0.29"),

	 ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
			name: "TapeDeck", dependencies: ["Suite", "Chronicle"]),
        .testTarget(
            name: "TapeDeckTests",
            dependencies: ["TapeDeck"]),
    ]
)
