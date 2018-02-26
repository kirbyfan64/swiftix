import Console

let ctx = Context.sharedInstance
let console = Context.sharedInstance.console

let commands: [Runnable] = [UpdateCommand(), AvailableCommand(), ListCommand(), InstallCommand(),
                            ActivateCommand(), RemoveCommand()]

do {
    try console.run(executable: "swiftix", commands: commands,
                    arguments: Array(CommandLine.arguments.dropFirst(1)),
                    help: ["swiftix manages your installed Swift versions."])
} catch ConsoleError.noCommand {
    ctx.fail("No command given. Use --help to show help.")
} catch is ConsoleError {
}
