import Foundation

import Console

class Context {
    static let sharedInstance = Context()

    let console: ConsoleProtocol = Terminal(arguments: CommandLine.arguments)
    let system: System

    init() {
        system = System()
        system.ctx = self
    }

    func fail(_ message: String) -> Never {
        console.error(message)
        exit(1)
    }

    func warn(_ message: String) {
        console.output(message, style: .custom(.magenta), newLine: true)
    }

    func note(_ message: String) {
        console.info(message)
    }

    func success(_ message: String = "Success!") {
        console.success(message)
    }

    func print(_ message: String) {
        console.print(message)
    }
}
