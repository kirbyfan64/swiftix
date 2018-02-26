import Foundation

import Console

extension Command {
    func parse(arguments: [String]) -> (Array<String>, Dictionary<String, String>) {
        let ctx = Context.sharedInstance
        let opts = Dictionary(grouping: signature.options, by: { $0.name })

        let resultArgs = Array(arguments.prefix(signature.values.count))
        var resultOpts = [String: String]()

        for option in arguments.dropFirst(signature.values.count) {
            if !option.starts(with: "--") {
                printUsage(executable: "swiftix")
                exit(1)
            }

            let items = option
                .dropFirst(2)
                .split(separator: "=", maxSplits: 1)
                .map { String($0) }
            let (name, value) = (String(items[0]), String(items[1]))
            if opts[name] == nil {
                ctx.error("Invalid option: --\(name)")
                printUsage(executable: "swiftix")
                exit(1)
            } else if value == "true" {
                ctx.error("Option --\(name) requires a value.")
                printUsage(executable: "swiftix")
                exit(1)
            } else {
                resultOpts[name] = value
            }
        }

        return (resultArgs, resultOpts)
    }
}
