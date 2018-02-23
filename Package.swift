// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swiftix",
    dependencies: [
        .package(url: "https://github.com/vapor/console", from: "2.3.1"),
        .package(url: "https://github.com/crossroadlabs/Regex", from: "1.1.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "1.6.1"),
    ],
    targets: [
        .target(name: "swiftix", dependencies: [
            "Console", "Regex", "SwiftSoup"
        ]),
    ]
)
