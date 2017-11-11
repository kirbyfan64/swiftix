import Foundation
import Dispatch

import Regex

enum Build : Codable {
    case release
    case snapshot(date: String)

    init(stringified: String) {
        if stringified == "release" {
            self = .release
        } else {
            let date = stringified.replacingOccurrences(of: "snapshot-", with: "")
            self = .snapshot(date: date)
        }
    }

    func stringify() -> String {
        switch self {
        case .release: return "release"
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

    var directory: String {
        get { return "swift-\(version)-\(build.stringify())" }
    }

    static func parseDirectoryName(_ name: String) -> (version: String, build: Build) {
        let re = try! Regex(pattern: "swift-(\\d\\.\\d)-(.+)", groupNames: ["version", "build"])
        let match = re.findFirst(in: name)!
        let build = Build(stringified: match.group(named: "build")!)
        return (version: match.group(named: "version")!, build: build)
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
    var release: [String: Version] = [:]
    var snapshots: [String: Version] = [:]

    init(base: String) {
        self.base = base
    }
}

typealias VersionSetDict = [String: VersionSet]
