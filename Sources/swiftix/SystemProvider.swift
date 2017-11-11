import Foundation

class SystemProvider {
    let fm = FileManager.default

    var swiftixDir: URL {
        get { return fm.homeDirectoryForCurrentUser.appendingPathComponent(".swiftix", isDirectory: true) }
    }

    var storeDir: URL {
        get { return swiftixDir.appendingPathComponent("store", isDirectory: true) }
    }

    var activeLink: URL {
        get { return swiftixDir.appendingPathComponent("active") }
    }

    var versionListPath: URL {
        get { return swiftixDir.appendingPathComponent("versions.json") }
    }

    func getVersionStore(for version: Version) -> URL {
        return storeDir.appendingPathComponent(version.directory, isDirectory: true)
    }

    func getUbuntuVersion(ctx: Context) -> String {
        ctx.note("Determining Ubuntu version...")

        let pipe = Pipe()

        let proc = Process()
        proc.launchPath = "/usr/bin/lsb_release"
        proc.arguments = ["-rs"]
        proc.standardOutput = pipe
        proc.launch()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let dataString = String(data: data, encoding: .utf8) else {
            ctx.fail("Can't decode lsb_release output data.")
        }

        return dataString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
