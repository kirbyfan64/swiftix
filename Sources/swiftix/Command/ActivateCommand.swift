/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import Console

class ActivateCommand: Command {
    let id = "activate"
    let help = ["Changes the active Swift version."]
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
        let versionDir = ctx.system.provider.getVersionStore(for: requestedVersion)

        if !ctx.system.exists(versionDir) {
            ctx.fail("Version \(version) has not been installed.")
        }

        let activeLink = ctx.system.provider.activeLink
        ctx.system.delete(activeLink)
        ctx.system.symlink(link: activeLink, to: versionDir)
        ctx.note("Success!")
    }
}
