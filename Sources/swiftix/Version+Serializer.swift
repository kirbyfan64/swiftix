/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

extension Build {
    private enum CodingKeys: String, CodingKey {
        case stable
        case snapshot
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? values.decode(String.self, forKey: .snapshot) {
            self = .snapshot(date: value)
        } else {
            self = .stable
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stable:
            try container.encode("", forKey: .stable)
        case .snapshot(let date):
            try container.encode(date, forKey: .snapshot)
        }
    }
}

extension Dictionary where Key == String, Value == VersionSet {
    func serialize(ctx: Context) {
        let versionListPath = ctx.system.provider.versionListPath

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let encoded = try encoder.encode(self)
            ctx.system.write(data: encoded, to: versionListPath)
        } catch {
            ctx.fail("error serializing version list: \(error)")
        }
    }

    static func deserialize(ctx: Context) -> VersionSetDict {
        let versionListPath = ctx.system.provider.versionListPath

        let decoder = JSONDecoder()

        do {
            let data = try Data(contentsOf: versionListPath)
            let decoded = try decoder.decode([String: VersionSet].self, from: data)
            return decoded
        } catch {
            ctx.fail("error deserializing version list: \(error)")
        }
    }
}
