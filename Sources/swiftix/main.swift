/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Dispatch

import Console
import Regex
import SwiftSoup

enum Build : Codable {
    case stable
    case snapshot(date: String)

    func stringify() -> String {
        switch self {
        case .stable: return "stable"
        case .snapshot(let date): return "snapshot-\(date)"
        }
    }
}

extension Build {
    private enum CodingKeys: String, CodingKey {
        case stable
        case snapshot
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? values.decode(String.self, forKey: .snapshot) {
            self = .snapshot(date: value)
        } else {
            self = .stable
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stable:
            try container.encode("", forKey: .stable)
        case .snapshot(let date):
            try container.encode(date, forKey: .snapshot)
        }
    }
}

struct Version : Codable {
    var version: String
    var ubuntu: String
    var build: Build
    var url: String
}

class VersionSet : Codable {
    var base: String
    var stable: [String: Version] = [:]
    var snapshots: [String: Version] = [:]

    init(base: String) {
        self.base = base
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
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

    init(ctx: Context, completion: @escaping (URL) -> Void, sema: DispatchSemaphore) {
        self.ctx = ctx
        self.completion = completion
        self.sema = sema

        // Adjust the width to fit everything nicely.
        let width = ctx.console.size.width - 22
        self.progress = ctx.console.progressBar(title: "downloading", width: width)
    }

    func finish() {
        progress.progress = 1
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        progress.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo url: URL) {
        finish()
        defer { ctx!.delete(url) }

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
    let console = Terminal(arguments: CommandLine.arguments)
    static let sharedInstance = Context()

    func fail(_ message: String) -> Never {
        console.error(message)
        exit(1)
    }

    func warn(_ message: String) {
        console.warning(message)
    }

    func note(_ message: String) {
        console.info(message)
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

    func getSwiftixDir() -> URL {
        let home = fm.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".swiftix", isDirectory: true)
    }

    func getVersionStore(swiftixDir: URL, version: Version) -> URL {
        let versionsDir = swiftixDir.appendingPathComponent("store", isDirectory: true)
        return versionsDir.appendingPathComponent("swift-\(version.version)-\(version.build.stringify())",
                                                  isDirectory: true)
    }

    func getVersionListPath(swiftixDir: URL) -> URL {
        return swiftixDir.appendingPathComponent("versions.json")
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

        let session = URLSession(configuration: URLSessionConfiguration.default)
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
            if let match = re.findFirst(in: String(filename)) {
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

    func serializeVersionSets(_ versionSets: [String: VersionSet]) {
        let swiftixDir = getSwiftixDir()
        let versionListPath = getVersionListPath(swiftixDir: swiftixDir)

        note("Saving version list...")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let encoded = try encoder.encode(versionSets)
            if !fm.createFile(atPath: versionListPath.path, contents: encoded) {
                fail("error writing verison list file \(versionListPath.path)")
            }
        } catch Exception.Error(_, let error) {
            fail("error serializing version list: \(error)")
        } catch {
            fail("unknown error occurred serializing version list")
        }
    }

    func deserializeVersionSets() -> [String: VersionSet] {
        let swiftixDir = getSwiftixDir()
        let versionListPath = getVersionListPath(swiftixDir: swiftixDir)

        let decoder = JSONDecoder()

        do {
            let data = try Data(contentsOf: versionListPath)
            let decoded = try decoder.decode([String: VersionSet].self, from: data)
            return decoded
        } catch Exception.Error(_, let error) {
            fail("error deserializing version list: \(error)")
        } catch {
            fail("unknown error occurred deserializing version list")
        }
    }

    func downloadSwift(from url: URL, _ completion: @escaping (URL) -> Void) {
        let sema = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: URLSessionConfiguration.default,
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

    func install(_ version: Version) {
        let swiftixDir = getSwiftixDir()
        let versionDir = getVersionStore(swiftixDir: swiftixDir, version: version)
        let versionDirTmp = versionDir.appendingPathExtension("tmp")

        if fm.fileExists(atPath: versionDir.path) {
            fail("requested version is already installed")
        }

        let url = "https://swift.org/\(version.url)"
        note("Downloading \(url)...")
        downloadSwift(from: URL(string: url)!) { url in
            self.delete(versionDirTmp)
            self.extractSwift(tarFile: url, outputDir: versionDirTmp)
        }

        guard let _ = try? fm.moveItem(atPath: versionDirTmp.path, toPath: versionDir.path) else {
            fail("failed to rename temporary path to final path")
        }
        note("Success!")
    }
}

class UpdateCommand: Command {
    let id = "update"
    let help = ["Update the list of available Swift versions"]
    let signature = [Runnable]()

    let console: ConsoleProtocol

    init(console: ConsoleProtocol) {
        self.console = console
    }

    func run(arguments: [String]) {
        let ctx = Context.sharedInstance
        let versionSets = ctx.getSwiftVersionSetsFor(ubuntu: ctx.getUbuntuVersion())
        ctx.serializeVersionSets(versionSets)
    }
}

class AvailableCommand: Command {
    let id = "available"
    let help = ["Show the available Swift versions"]
    let signature = [Option(name: "max-snapshots", help: ["max number of snapshots to print"])]

    let console: ConsoleProtocol

    init(console: ConsoleProtocol) {
        self.console = console
    }

    func run(arguments: [String]) {
        let ctx = Context.sharedInstance

        let maxSnapshots = arguments.option("max-snapshots")?.int ?? 5

        let versionSets = ctx.deserializeVersionSets()

        // Reverse sort.
        for (_, versionSet) in versionSets.sorted(by: { $0.0 > $1.0 }) {
            // let versionSet = versionSets[versionBase]!
            ctx.console.print("Version \(versionSet.base):")
            for stable in versionSet.stable.values {
                ctx.console.print("  - \(stable.version)")
            }

            for (_, snapshot) in versionSet.snapshots.sorted(by: { $0.0 > $1.0 }).prefix(maxSnapshots) {
                if case .snapshot(let date) = snapshot.build {
                    ctx.console.print("  - snapshot: \(date)")
                }
            }
        }
    }
}

class InstallCommand: Command {
    let id = "install"
    let help = ["Install the given Swift version"]
    let signature = [Value(name: "version", help: ["the Swift version to download"]),
                     Value(name: "snapshot", help: ["the snapshot version to use"])]

    let console: ConsoleProtocol

    init(console: ConsoleProtocol) {
        self.console = console
    }

    func run(arguments: [String]) {
        let ctx = Context.sharedInstance

        guard let version = arguments[safe: 0] else {
            ctx.fail("Argument 'version' is required.")
        }

        let versionSets = ctx.deserializeVersionSets()

        guard let requestedBase = ctx.getSwiftVersionBase(version) else {
            ctx.fail("Invalid version \(version)")
        }
        guard let requestedVersionSet = versionSets[requestedBase] else {
            ctx.fail("Cannot find any matches for version \(version)")
        }

        if let snapshot = arguments[safe: 1] {
            if requestedBase != version {
                ctx.warn("Snapshots are not for patch versions; assuming version \(requestedBase)")
            }

            guard let requestedSnapshot = requestedVersionSet.snapshots[snapshot] else {
                ctx.fail("Cannot find snapshot \(snapshot)")
            }

            ctx.install(requestedSnapshot)
        } else {
            guard let requestedVersion = requestedVersionSet.stable[version] else {
                ctx.fail("Cannot find version \(version) (did you mean to use a snapshot?)")
            }

            ctx.install(requestedVersion)
        }
    }
}

let console = Context.sharedInstance.console
let commands: [Runnable] = [UpdateCommand(console: console), AvailableCommand(console: console), InstallCommand(console: console)]
_ = try? console.run(executable: "swiftix", commands: commands, arguments: Array(CommandLine.arguments.dropFirst(1)),
                     help: ["swiftix manages your installed Swift versions."])
