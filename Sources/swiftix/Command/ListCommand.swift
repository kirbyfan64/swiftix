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

        let activeLink = ctx.system.provider.activeLink
        var active: String? = nil
        if ctx.system.exists(activeLink) {
            let activeVersionDir = ctx.system.readlink(activeLink)
             active = activeVersionDir.lastPathComponent
        }

        for dir in ctx.system.listdir(storeDir).sorted(by: { $0 > $1 }) {
            let prefix = dir == active ? "*" : "-"
            switch Version.parseDirectoryName(dir) {
            case (let version, Build.release):
                ctx.print("\(prefix) \(version) (release)")
            case (let version, Build.snapshot(let date)):
                ctx.print("\(prefix) \(version) (snapshot: \(date))")
            }
        }
    }
}
