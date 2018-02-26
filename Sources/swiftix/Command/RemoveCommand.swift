import Foundation

import Console

class RemoveCommand: Command {
    let id = "remove"
    let help = ["Remove the given Swift version"]
    let signature = [Value(name: "version", help: ["the Swift version to download"]),
                     Option(name: "snapshot", short: "s", help: ["the snapshot version to use"])]
                    as [Argument]

    let ctx = Context.sharedInstance
    let console = Context.sharedInstance.console

    func run(arguments: [String]) {
        let (values, opts) = parse(arguments: arguments)
        let version = values[0]
        let snapshot = opts["snapshot"]

        let versionSets = VersionSetDict.deserialize(ctx: ctx)
        let requestedVersion = versionSets.find(ctx: ctx, version: version, snapshot: snapshot)
        remove(requestedVersion)
    }

    func remove(_ version: Version) {
        let versionDir = ctx.system.provider.getVersionStore(for: version)

        if !ctx.system.exists(versionDir) {
            ctx.fail("Requested version has not been installed.")
        }

        let activeLink = ctx.system.provider.activeLink
        if ctx.system.exists(activeLink) {
            let activeVersionDir = ctx.system.readlink(activeLink)
            if activeVersionDir.path == versionDir.path {
                ctx.fail("Cannot remove the currently active version.")
            }
        }

        ctx.system.delete(versionDir)
        ctx.success()
    }
}
