/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
            ctx.console.print("Version \(versionSet.base):")
            for stable in versionSet.stable.values {
                ctx.console.print("  - stable: \(stable.version)")
            }

            for (_, snapshot) in versionSet.snapshots.sorted(by: { $0.0 > $1.0 }).prefix(maxSnapshots) {
                if case .snapshot(let date) = snapshot.build {
                    ctx.console.print("  - snapshot: \(date)")
                }
            }
        }
    }
}
