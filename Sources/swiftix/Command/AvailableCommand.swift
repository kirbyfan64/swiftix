import Console

class AvailableCommand: Command {
    let id = "available"
    let help = ["Show the available Swift versions"]
    let signature = [Option(name: "max-snapshots", help: ["max number of snapshots to print"])]

    let ctx = Context.sharedInstance
    let console = Context.sharedInstance.console

    func run(arguments: [String]) {
        let maxSnapshots = arguments.option("max-snapshots")?.int ?? 5

        let versionSets = VersionSetDict.deserialize(ctx: ctx)

        // Reverse sort.
        for (_, versionSet) in versionSets.sorted(by: { $0.0 > $1.0 }) {
            ctx.print("Version \(versionSet.base):")
            for release in versionSet.release.values {
                ctx.print("  - release: \(release.version)")
            }

            for (_, snapshot) in versionSet.snapshots.sorted(by: { $0.0 > $1.0 }).prefix(maxSnapshots) {
                if case .snapshot(let date) = snapshot.build {
                    ctx.print("  - snapshot: \(date)")
                }
            }
        }
    }
}
