local command = require("./util/command")
local process = require("@lune/process")

command.run("lunew", "src", "--", "build", "--dev", "--zip", "--target", "all")
command.run("cp", "./release/lpm", "./lpm")
