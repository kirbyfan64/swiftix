/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class SystemProvider {
    let fm = FileManager.default

    var swiftixDir: URL {
        get { return fm.homeDirectoryForCurrentUser.appendingPathComponent(".swiftix", isDirectory: true) }
    }

    var activeLink: URL {
        get { return swiftixDir.appendingPathComponent("active") }
    }

    var versionListPath: URL {
        get { return swiftixDir.appendingPathComponent("versions.json") }
    }

    func getVersionStore(for version: Version) -> URL {
        let versionsDir = swiftixDir.appendingPathComponent("store", isDirectory: true)
        return versionsDir.appendingPathComponent("swift-\(version.version)-\(version.build.stringify())",
                                                  isDirectory: true)
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
            ctx.fail("can't decode lsb_release output data")
        }

        return dataString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
