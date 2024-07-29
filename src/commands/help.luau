local Commander = require("../dependencies/commander")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process

local Command = Commander.Command
local Helper = require("../dependencies/commander/helper")

return Command.new("help")
  :description("Help command")
  :argument("<command>", "Command name")
  :action(function(command, _, cmd)
    local commands = Helper.getAllCommands(cmd.parent)
    if fs.isFile(`./docs/commands/{command}.md`) then
      process.spawn(
        "glow",
        { `./docs/commands/{command}.md`, `-s`, `~/.config/glow/styles/catppuccin_mocha.json` },
        { stdio = "forward" }
      )
    end
  end)
