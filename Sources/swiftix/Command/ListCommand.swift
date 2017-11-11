/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import Console
import Regex

class ListCommand: Command {
    let id = "list"
    let help = ["Show the installed Swift versions"]

    let ctx = Context.sharedInstance
    let console = Context.sharedInstance.console

    func run(arguments: [String]) {
        let storeDir = ctx.system.provider.storeDir
        for dir in ctx.system.listdir(storeDir).sorted(by: { $0 > $1 }) {
            switch Version.parseDirectoryName(dir) {
            case (let version, Build.release):
                ctx.print("- \(version) (release)")
            case (let version, Build.snapshot(let date)):
                ctx.print("- \(version) (snapshot: \(date))")
            }
        }
    }
}
