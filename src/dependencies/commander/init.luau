local Arg = require("./arg")
local Command = require("./command")
local Opt = require("./opt")
local types = require("./types")

export type Command = types.Command
export type Option = types.Opt
export type Argument = types.Arg

return {
  Command = Command,
  Opt = Opt,
  Arg = Arg,
  program = Command.new(),
}
