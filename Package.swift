// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TapeDeck",
	 platforms: [
				 .macOS(.v26),
				 .iOS(.v26),
				 .watchOS(.v26)
		  ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TapeDeck",
            targets: ["TapeDeck"]),
    ],
	 dependencies: [
		.package(url: "https://github.com/ios-tooling/Suite.git", from: "1.2.40"),
		.package(url: "https://github.com/ios-tooling/Journalist.git", from: "1.0.12"),

	 ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
			name: "TapeDeck", dependencies: ["Suite", "Journalist"]),
        .testTarget(
            name: "TapeDeckTests",
            dependencies: ["TapeDeck"]),
    ]
)
