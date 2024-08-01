local Commander = require("../commander")
local build = require("../../libs/build")

local Command = Commander.Command

local command = Command.new("build")
  :description("Build package")
  :option("-D, --dev", "Developer Mode")
  :option("-T, --target <target_build>", "Build target")
  :option("-Z, --zip", "Zip result")
  :option("-C, --comment", "Keep comment")
  :action(function(opts)
    local mode = opts.dev and "dev" or "release"
    build.build(
      mode :: build.BuildMode,
      { target = opts.target, dev = opts.dev, zip = opts.zip, comment = opts.comment }
    )
  end)

return command
