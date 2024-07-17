_G.LPM_OUTPUT_MODE = "CLI"
_G.VERSION = "0.1.0"
local api = require("./api")
local fs = require("@lune/fs")
local process = require("@deps/std/process")
local stdio = require("@lune/stdio")
local program = require("@deps/commander").program

local function main()
  program:name("lpm"):version("0.1.0"):description("Luau Package Manager")

  for _, command in api.commands do
    program:addCommand(command :: any)
  end

  program:parse()

  process.exit(0)
end

main()
