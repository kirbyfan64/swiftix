import Foundation

import Console

class InstallCommand: Command {
    let id = "install"
    let help = ["Install the given Swift version"]
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
        install(requestedVersion)
    }

    func install(_ version: Version) {
        let versionDir = ctx.system.provider.getVersionStore(for: version)
        let versionDirTmp = versionDir.appendingPathExtension("tmp")

        if ctx.system.exists(versionDir) {
            ctx.fail("Requested version is already installed.")
        }

        ctx.system.delete(versionDirTmp)

        let url = URL(string: "https://swift.org/\(version.url)")!
        FileDownloader.download(ctx: ctx, from: url) { outputUrl in
            self.extract(tarFile: outputUrl, outputDir: versionDirTmp)
        }

        ctx.system.move(from: versionDirTmp, to: versionDir)
        ctx.success()
    }

    func extract(tarFile: URL, outputDir: URL) {
        ctx.note("Extracting archive...")
        ctx.system.mkdir(outputDir)

        let proc = Process()
        proc.launchPath = "/usr/bin/env"
        proc.arguments = ["tar", "-xf", tarFile.path, "-C", outputDir.path, "--strip", "2"]
        proc.launch()
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            ctx.system.delete(outputDir)
            ctx.fail("tar failed while extracting Swift installation.")
        }
    }
}
