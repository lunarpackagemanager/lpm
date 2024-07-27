local command = require("./util/command")
local process = require("@lune/process")
local testkit = require("./util/testkit")

local BENCHMARK = testkit.benchmark()

do
  BENCHMARK("Building", function()
    command.run("lunew", "src", "--", "build", "--dev", "--zip", "--target", "all")
  end)

  command.run("rm", "./lpm")
  command.run("cp", "./release/lpm", "./lpm")
end
