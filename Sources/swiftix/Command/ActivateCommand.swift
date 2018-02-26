import Foundation

import Console

class ActivateCommand: Command {
    let id = "activate"
    let help = ["Changes the active Swift version."]
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
        let versionDir = ctx.system.provider.getVersionStore(for: requestedVersion)

        if !ctx.system.exists(versionDir) {
            ctx.fail("Version \(version) has not been installed.")
        }

        let activeLink = ctx.system.provider.activeLink
        ctx.system.delete(activeLink)
        ctx.system.symlink(link: activeLink, to: versionDir)
        ctx.success("Success! Make sure ~/.swiftix/active/bin is on your PATH, and get started Swifting!")
        ctx.success("(To add it, run:    echo 'export PATH=$PATH:~/.swiftix/active/bin' >> ~/.bashrc   )")
    }
}
