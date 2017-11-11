/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Console

let console = Context.sharedInstance.console
let commands: [Runnable] = [UpdateCommand(), AvailableCommand(), ListCommand(), InstallCommand(),
                            ActivateCommand()]
_ = try? console.run(executable: "swiftix", commands: commands,
                     arguments: Array(CommandLine.arguments.dropFirst(1)),
                     help: ["swiftix manages your installed Swift versions."])
