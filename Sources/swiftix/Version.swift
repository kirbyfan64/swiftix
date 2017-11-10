/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Dispatch

import Regex

enum Build : Codable {
    case stable
    case snapshot(date: String)

    func stringify() -> String {
        switch self {
        case .stable: return "stable"
        case .snapshot(let date): return "snapshot-\(date)"
        }
    }
}

struct Version : Codable {
    var version: String
    var ubuntu: String
    var build: Build
    var url: String

    var base: String? {
        get { return Version.getBase(version) }
    }

    static func getBase(_ version: String) -> String? {
        let re = try! Regex(pattern: "(\\d\\.\\d)", groupNames: "base")
        guard let match = re.findFirst(in: version) else {
            return nil
        }
        return match.group(named: "base")!
    }
}

class VersionSet : Codable {
    var base: String
    var stable: [String: Version] = [:]
    var snapshots: [String: Version] = [:]

    init(base: String) {
        self.base = base
    }
}

typealias VersionSetDict = [String: VersionSet]
