import Foundation
import Dispatch

import Regex
import SwiftSoup

class VersionDownloader {
    class func downloadRawLinks(ctx: Context) -> [String] {
        ctx.note("Downloading list of Swift versions...")

        let url = URL(string: "https://swift.org/download/")!
        let sema = DispatchSemaphore(value: 0)
        var result = [String]()

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                ctx.fail("Retreiving swift.org downloads page: \(error)")
            }

            guard let dataString = String(data: data!, encoding: .utf8) else {
                ctx.fail("Can't decode swift.org downloads page data as UTF-8 string.")
            }

            do {
                let doc = try SwiftSoup.parse(dataString)
                let versions = try doc.select("a[title='Download']:not(.debug)")
                result = try versions.array().map { try $0.attr("href") }
            } catch Exception.Error(_, let error) {
                ctx.fail("Parsing swift.org downloads page HTML: \(error)")
            } catch {
                ctx.fail("Parsing swift.org downloads page HTML: \(error)")
            }
            sema.signal()
        }
        task.resume()
        _ = sema.wait(timeout: DispatchTime.distantFuture)
        return result.filter { $0.starts(with: "/builds/") && $0.contains("ubuntu") }
    }

    class func downloadList(ctx: Context) -> [Version] {
        var result = [Version]()

        let re = try! Regex(pattern:
            "swift-(?:([\\d.]+)-?)(?:(?:DEVELOPMENT-SNAPSHOT-(\\d{4}-\\d{2}-\\d{2})-.)|RELEASE)" +
            "-ubuntu(\\d{2}\\.\\d{2})\\.tar\\.gz",
            groupNames: "version", "snapshot", "ubuntu")

        for url in downloadRawLinks(ctx: ctx) {
            guard let filename = url.split(separator: "/").last else {
                continue
            }
            if let match = re.findFirst(in: String(filename)) {
                var build = Build.release
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
}
