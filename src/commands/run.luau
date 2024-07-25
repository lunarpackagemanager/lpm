local Commander = require("../dependencies/commander")

local script_manager = require("../libs/script_manager")

local Command = Commander.Command

local command = Command.new("run")
  :description("Run script")
  :aliases({ "run-script" })
  :argument("<name>", "Script name")
  :action(function(name: string)
    script_manager.run_hook(name)
  end)

return command
