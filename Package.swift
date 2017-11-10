// swift-tools-version:4.0
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import PackageDescription

let package = Package(
    name: "swiftix",
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup", from: "1.5.0"),
        .package(url: "https://github.com/jakeheis/SwiftCLI", from: "4.0.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
        .package(url: "https://github.com/jkandzi/Progress.swift", from: "0.0.0"),
        .package(url: "https://github.com/Coder-256/Regex", .branch("swift4")),
    ],
    targets: [
        .target(name: "swiftix", dependencies: [
            "SwiftSoup", "SwiftCLI", "Rainbow", "Progress", "Regex"
        ]),
    ]
)
