/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Dispatch
import Progress
import Rainbow
import Regex
import SwiftCLI
import SwiftSoup

enum Build {
    case stable
    case snapshot(date: String)

    func stringify() -> String {
        switch self {
            case .stable: return "stable"
            case .snapshot(let date): return "snapshot-\(date)"
        }
    }
}

struct Version {
    var version: String
    var ubuntu: String
    var build: Build
    var url: String
}

class VersionSet {
    var base: String
    var stable: [String: Version] = [:]
    var snapshots: [String: Version] = [:]

    init(base: String) {
        self.base = base
    }
}

extension Dictionary {
    subscript(key: Key, setDefault def: Value) -> Value {
        mutating get {
            if let value = self[key] {
                return value
            } else {
                self[key] = def
                return def
            }
        }
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var ctx: Context?
    var completion: (URL) -> Void
    var sema: DispatchSemaphore
    var progress: ProgressBar

    static let maxProgress = 1000

    init(ctx: Context, completion: @escaping (URL) -> Void, sema: DispatchSemaphore) {
        self.ctx = ctx
        self.completion = completion
        self.sema = sema
        self.progress = ProgressBar(count: DownloadDelegate.maxProgress,
                                    configuration: [ProgressPercent(), ProgressBarLine(barLength: 60)])
    }

    func finish() {
        self.progress.setValue(DownloadDelegate.maxProgress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let percent = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        self.progress.setValue(Int(percent * Double(DownloadDelegate.maxProgress)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo url: URL) {
        finish()
        defer {
            ctx!.delete(url)
        }

        completion(url)
        sema.signal()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error = error {
            finish()
            ctx!.fail("error downloading file: \(error.localizedDescription)")
        }
    }
}

class Context {
    let fm = FileManager.default

    func fail(_ message: String) -> Never {
        print("ERROR: \(message)".red)
        exit(1)
    }

    func warn(_ message: String) {
        print("WARNING: \(message)".magenta)
    }

    func note(_ message: String) {
        print(message.cyan)
    }

    func mkdir(_ url: URL) {
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch Exception.Error(_, let error) {
            fail("error creating \(url.path): \(error)")
        } catch {
            fail("unknown error occurred while creating \(url.path)")
        }
    }

    func delete(_ url: URL) {
        if !fm.fileExists(atPath: url.path) {
            return
        }

        do {
            try fm.removeItem(at: url)
        } catch Exception.Error(_, let error) {
            fail("error removing \(url.path): \(error)")
        } catch {
            fail("unknown error occurred while removing \(url.path)")
        }
    }

    func getUbuntuVersion() -> String {
        note("Determining Ubuntu version...")

        let pipe = Pipe()

        let proc = Process()
        proc.launchPath = "/usr/bin/lsb_release"
        proc.arguments = ["-rs"]
        proc.standardOutput = pipe
        proc.launch()
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let dataString = String(data: data, encoding: .utf8) else {
            self.fail("can't decode lsb_release output data")
        }

        return dataString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getRawSwiftVersionLinks() -> [String] {
        note("Downloading list of Swift versions...")

        let url = URL(string: "https://swift.org/download/")!
        let sema = DispatchSemaphore(value: 0)
        var result = [String]()

        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                self.fail("retreiving swift.org downloads page: \(error)")
            }

            guard let dataString = String(data: data!, encoding: .utf8) else {
                self.fail("can't decode swift.org downloads page data as UTF-8 string")
            }

            do {
                let doc = try SwiftSoup.parse(dataString)
                let versions = try doc.select("a[title='Download']:not(.debug)")
                result = try versions.array().map { try $0.attr("href") }
            } catch Exception.Error(_, let error) {
                self.fail("parsing swift.org downloads page HTML: \(error)")
            } catch {
                self.fail("unknown error occurred")
            }
            sema.signal()
        }
        task.resume()
        _ = sema.wait(timeout: DispatchTime.distantFuture)
        return result.filter { $0.starts(with: "/builds/") && $0.contains("ubuntu") }
    }

    func getSwiftVersions() -> [Version] {
        var result = [Version]()

        let re = try! Regex(pattern:
            "swift-(?:([\\d.]+)-?)(?:(?:DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})-.)|RELEASE)" +
            "-ubuntu(\\d{2}\\.\\d{2})\\.tar\\.gz",
            groupNames: "version", "snapshot", "ubuntu")

        for url in getRawSwiftVersionLinks() {
            guard let filename = url.split(separator: "/").last else {
                continue
            }
            if let match = re.findFirst(in: String.init(filename)) {
                var build = Build.stable
                if let snapshot = match.group(named: "snapshot") {
                    build = Build.snapshot(date: snapshot)
                }

                let versionString = match.group(named: "version")!
                let ubuntuString = match.group(named: "ubuntu")!
                let version = Version(version: versionString, ubuntu: ubuntuString, build: build,
                                      url: url)
                result.append(version)
            }
        }

        return result
    }

    func getSwiftVersionsFor(ubuntu: String) -> Array<Version> {
        let versions = getSwiftVersions()
        let myVersions = versions.filter { $0.ubuntu == ubuntu }

        if (myVersions.isEmpty) {
            warn("No Swift versions available for Ubuntu \(ubuntu); defaulting to Ubuntu 16.10")
            return versions.filter { $0.ubuntu == "16.10" }
        } else {
            return myVersions
        }
    }

    func getSwiftVersionBase(_ version: String) -> String? {
        let re = try! Regex(pattern: "(\\d\\.\\d)", groupNames: "base")
        guard let match = re.findFirst(in: version) else {
            return nil
        }
        return match.group(named: "base")!
    }

    func groupVersions(_ versions: [Version]) -> [String: VersionSet] {
        var versionSets = [String: VersionSet]()

        for version in versions {
            let base = getSwiftVersionBase(version.version)!

            let versionSet = versionSets[base, setDefault: VersionSet(base: base)]
            switch version.build {
            case .stable:
                versionSet.stable[version.version] = version
            case .snapshot(let date):
                versionSet.snapshots[date] = version
            }
        }

        return versionSets
    }

    func getSwiftVersionSetsFor(ubuntu: String) -> [String: VersionSet] {
        return groupVersions(getSwiftVersionsFor(ubuntu: ubuntu))
    }

    func downloadSwift(from url: URL, _ completion: @escaping (URL) -> Void) {
        let sema = DispatchSemaphore(value: 0)
        let session = URLSession.init(configuration: URLSessionConfiguration.default,
                                      delegate: DownloadDelegate(ctx: self, completion: completion, sema: sema),
                                      delegateQueue: nil)

        let task = session.downloadTask(with: url)
        task.resume()
        _ = sema.wait(timeout: DispatchTime.distantFuture)
    }

    func extractSwift(tarFile: URL, outputDir: URL) {
        note("Extracting archive...")
        mkdir(outputDir)

        let proc = Process()
        proc.launchPath = "/usr/bin/env"
        proc.arguments = ["tar", "-xf", tarFile.path, "-C", outputDir.path, "--strip", "2"]
        proc.launch()
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            delete(outputDir)
            fail("tar failed while extracting Swift installation")
        }
    }

    func getSwiftixDir() -> URL {
        let home = fm.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".swiftix", isDirectory: true)
    }

    func getVersionDir(swiftixDir: URL, version: Version) -> URL {
        let versionsDir = swiftixDir.appendingPathComponent("versions", isDirectory: true)
        return versionsDir.appendingPathComponent("swift-\(version.version)-\(version.build.stringify())",
                                                  isDirectory: true)
    }

    func install(_ version: Version) {
        let swiftixDir = getSwiftixDir()
        let versionDir = getVersionDir(swiftixDir: swiftixDir, version: version)

        if fm.fileExists(atPath: versionDir.path) {
            fail("requested version is already installed")
        }

        let url = "https://swift.org/\(version.url)"
        note("Downloading \(url)...")
        downloadSwift(from: URL.init(string: url)!) { url in
            self.extractSwift(tarFile: url, outputDir: versionDir)
        }

        note("Success!")
    }
}

class AvailableCommand: Command {
    let name = "available"
    let shortDescription = "Show the available Swift versions"
    let maxSnapshots = Key<Int>("-s", description: "max number of snapshots to print")

    func execute() {
        let ctx = Context()
        let versionSets = ctx.getSwiftVersionSetsFor(ubuntu: ctx.getUbuntuVersion())

        // Reverse sort.
        for versionBase in Array(versionSets.keys).sorted(by: { $0 > $1 }) {
            let versionSet = versionSets[versionBase]!
            print("Version \(versionSet.base):")
            for stable in versionSet.stable.values {
                print("  - \(stable.version)")
            }
            for snapshot in versionSet.snapshots.values.prefix(maxSnapshots.value ?? 5) {
                if case .snapshot(let date) = snapshot.build {
                    print("  - snapshot: \(date)")
                }
            }
        }
    }
}

class InstallCommand: Command {
    let name = "install"
    let shortDescription = "Install the given Swift version"
    let version = Parameter()
    let snapshot = OptionalParameter()

    func execute() {
        let ctx = Context()
        let versionSets = ctx.getSwiftVersionSetsFor(ubuntu: ctx.getUbuntuVersion())

        guard let requestedBase = ctx.getSwiftVersionBase(version.value) else {
            ctx.fail("Invalid version \(version.value)")
        }
        guard let requestedVersionSet = versionSets[requestedBase] else {
            ctx.fail("Cannot find any matches for version \(version.value)")
        }

        if let snapshotDate = self.snapshot.value {
            if requestedBase != version.value {
                ctx.warn("Snapshots are not for patch versions; assuming version \(requestedBase)")
            }

            guard let requestedSnapshot = requestedVersionSet.snapshots[snapshotDate] else {
                ctx.fail("Cannot find snapshot \(snapshotDate)")
            }

            ctx.install(requestedSnapshot)
        } else {
            guard let requestedVersion = requestedVersionSet.stable[version.value] else {
                ctx.fail("Cannot find version \(version.value) (did you mean to use a snapshot?)")
            }

            ctx.install(requestedVersion)
        }
    }
}

let cli = CLI(name: "swiftix", version: "0.1.0", description: "description")
cli.commands = [AvailableCommand(), InstallCommand()]
cli.goAndExit()
