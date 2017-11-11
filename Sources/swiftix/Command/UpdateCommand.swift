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
