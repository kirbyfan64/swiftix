import Foundation

extension Build {
    private enum CodingKeys: String, CodingKey {
        case release
        case snapshot
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? values.decode(String.self, forKey: .snapshot) {
            self = .snapshot(date: value)
        } else {
            self = .release
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .release:
            try container.encode("", forKey: .release)
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
            ctx.fail("Error serializing version list: \(error)")
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
            ctx.fail("Error deserializing version list: \(error)")
        }
    }
}
