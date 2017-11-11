/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

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
