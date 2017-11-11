import Foundation

import Console

class RemoveCommand: Command {
    let id = "remove"
    let help = ["Remove the given Swift version"]
    let signature = [Value(name: "version", help: ["the Swift version to download"]),
                     Value(name: "snapshot", help: ["the snapshot version to use"])]

    let ctx = Context.sharedInstance
    let console = Context.sharedInstance.console

    func run(arguments: [String]) {
        guard let version = arguments[safe: 0] else {
            ctx.fail("Argument 'version' is required.")
        }
        let snapshot = arguments[safe: 1]

        let versionSets = VersionSetDict.deserialize(ctx: ctx)
        let requestedVersion = versionSets.find(ctx: ctx, version: version, snapshot: snapshot)
        remove(requestedVersion)
    }

    func remove(_ version: Version) {
        let versionDir = ctx.system.provider.getVersionStore(for: version)

        if !ctx.system.exists(versionDir) {
            ctx.fail("requested version has not been installed")
        }

        let activeLink = ctx.system.provider.activeLink
        if ctx.system.exists(activeLink) {
            let activeVersionDir = ctx.system.readlink(activeLink)
            if activeVersionDir.path == versionDir.path {
                ctx.fail("cannot remove the currently active version")
            }
        }

        ctx.system.delete(versionDir)
        ctx.success()
    }
}
