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

    func symlink(link: URL, to dest: URL) {
        let ctx = self.ctx!
        guard let _ = try? fm.createSymbolicLink(atPath: link.path, withDestinationPath: dest.path) else {
            ctx.fail("failed to create symlink at \(link.path) pointing to \(dest.path)")
        }
    }

    func listdir(_ dir: URL) -> [String] {
        let ctx = self.ctx!
        guard let contents = try? fm.contentsOfDirectory(atPath: dir.path) else {
            ctx.fail("failed to list contents of directory \(dir.path)")
        }
        return contents
    }

    func getUbuntuVersion() -> String {
        return provider.getUbuntuVersion(ctx: ctx!)
    }
}
