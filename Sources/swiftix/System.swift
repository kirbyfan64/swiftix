/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class System {
    let fm = FileManager.default
    weak var ctx: Context?
    let provider: SystemProvider

    init() {
        self.provider = SystemProvider()
    }

    func exists(_ url: URL) -> Bool {
        return fm.fileExists(atPath: url.path)
    }

    func mkdir(_ url: URL) {
        let ctx = self.ctx!
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            ctx.fail("error creating \(url.path): \(error)")
        }
    }

    func delete(_ url: URL) {
        if !exists(url) {
            return
        }

        let ctx = self.ctx!
        do {
            try fm.removeItem(at: url)
        } catch {
            ctx.fail("error removing \(url.path): \(error)")
        }
    }

    func write(data: Data, to url: URL) {
        let ctx = self.ctx!
        guard fm.createFile(atPath: url.path, contents: data) else {
            ctx.fail("failed to write \(url.path)")
        }
    }

    func move(from source: URL, to dest: URL) {
        let ctx = self.ctx!
        guard let _ = try? fm.moveItem(atPath: source.path, toPath: dest.path) else {
            ctx.fail("failed to move \(source.path) to \(dest.path)")
        }
    }

    func getUbuntuVersion() -> String {
        return provider.getUbuntuVersion(ctx: ctx!)
    }
}
