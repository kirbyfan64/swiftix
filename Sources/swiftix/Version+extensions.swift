extension Array where Iterator.Element == Version {
    func forUbuntu(ctx: Context, ubuntu: String) -> Array<Version> {
        let myVersions = filter { $0.ubuntu == ubuntu }

        if (myVersions.isEmpty) {
            ctx.warn("No Swift versions available for Ubuntu \(ubuntu); defaulting to Ubuntu 16.10.")
            return filter { $0.ubuntu == "16.10" }
        } else {
            return myVersions
        }
    }

    func toVersionSets() -> [String: VersionSet] {
        var versionSets = [String: VersionSet]()

        for version in self {
            let base = version.base!

            let versionSet = versionSets[base, setDefault: VersionSet(base: base)]
            switch version.build {
            case .release:
                versionSet.release[version.version] = version
            case .snapshot(let date):
                versionSet.snapshots[date] = version
            }
        }

        return versionSets
    }
}

extension Dictionary where Key == String, Value == VersionSet {
    func find(ctx: Context, version: String, snapshot: String?) -> Version {
        guard let requestedBase = Version.getBase(version) else {
            ctx.fail("Invalid version \(version).")
        }
        guard let requestedVersionSet = self[requestedBase] else {
            ctx.fail("Cannot find any matches for version \(version).")
        }

        if let snapshot = snapshot {
            if requestedBase != version {
                ctx.warn("Snapshots are not for patch versions; assuming version \(requestedBase).")
            }

            guard let requestedSnapshot = requestedVersionSet.snapshots[snapshot] else {
                ctx.fail("Cannot find snapshot \(snapshot).")
            }

            return requestedSnapshot
        } else {
            guard let requestedVersion = requestedVersionSet.release[version] else {
                ctx.fail("Cannot find version \(version). (Did you mean to use a snapshot?)")
            }

            return requestedVersion
        }
    }
}
