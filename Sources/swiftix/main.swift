import Console

let console = Context.sharedInstance.console
let commands: [Runnable] = [UpdateCommand(), AvailableCommand(), ListCommand(), InstallCommand(),
                            ActivateCommand(), RemoveCommand()]
_ = try? console.run(executable: "swiftix", commands: commands,
                     arguments: Array(CommandLine.arguments.dropFirst(1)),
                     help: ["swiftix manages your installed Swift versions."])
