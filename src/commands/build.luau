local Commander = require("../dependencies/commander")
local build = require("../libs/build")

local Command = Commander.Command

local command = Command.new("build")
  :description("Build package")
  :option("-r, --release", "Release or Dev")
  :action(function(opts)
    local mode = opts.release and "release" or "dev"
    build.build(mode :: any)
  end)

return command
