/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Console

class UpdateCommand: Command {
    let id = "update"
    let help = ["Update the list of available Swift versions"]
    let signature = [Runnable]()

    let ctx = Context.sharedInstance
    let console = Context.sharedInstance.console

    func run(arguments: [String]) {
        let versions = VersionDownloader.downloadList(ctx: ctx)
        let versionSets = versions.forUbuntu(ctx: ctx, ubuntu: ctx.system.getUbuntuVersion()).toVersionSets()

        ctx.note("Saving version list...")
        versionSets.serialize(ctx: ctx)
        ctx.success()
    }
}
