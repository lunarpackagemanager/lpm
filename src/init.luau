-- Set Globals
_G.LPM_OUTPUT_MODE = "CLI"
_G.VERSION = "0.1.0"
_G.DEBUG = true

local api = require("./api")
local commander = require("./cli/commander")
local std = require("@pkg/std")

local process = std.process
local program = commander.program

local function main()
  program:name("lpm"):version("0.1.0"):description("Luau Package Manager")

  for _, command in api.commands do
    program:addCommand(command :: any)
  end

  program:parse()

  process.exit(0)
end

main()
