// swift-tools-version:4.0
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
