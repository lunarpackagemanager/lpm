local Command = require("@deps/commander").Command
local build = require("../libs/build")

local command = Command.new("build")
  :description("Build package")
  :option("-r, --release", "Release or Dev")
  :action(function(opts)
    local mode = opts.release and "release" or "dev"
    build.build(mode :: any)
  end)

return command
