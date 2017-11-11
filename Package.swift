// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swiftix",
    dependencies: [
        .package(url: "https://github.com/vapor/console", from: "2.2.0"),
        .package(url: "https://github.com/Coder-256/Regex", .branch("swift4")),
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "1.5.0"),
    ],
    targets: [
        .target(name: "swiftix", dependencies: [
            "Console", "Regex", "SwiftSoup"
        ]),
    ]
)
