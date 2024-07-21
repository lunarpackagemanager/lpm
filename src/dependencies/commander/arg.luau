local types = require("./types")

local libutil = require("@pkg/libutil")

local Table = libutil.table
local String = libutil.string

type Arg = types.Arg

local Arg = {}

Arg.prototype = {}
Arg.interface = {}

Arg.prototype.__type = "Arg"

function Arg.interface.new(name: string, description: string?): Arg
  local argument = {
    variadic = false,
    description = description or "",
    defaultValue = nil,
    defaultValueDescription = nil,
    argChoices = nil,
    parseArg = nil,
  }

  local arg = (setmetatable(argument, {
    __index = Arg.prototype,
  }) :: any) :: Arg

  local firstChar = string.sub(name, 1, 1)

  if firstChar == "<" then
    arg.required = true
    arg._name = String.slice(name, 2, -1)
  elseif firstChar == "[" then
    arg.required = false
    arg._name = String.slice(name, 2, -1)
  end

  if #arg._name > 3 and String.slice(arg._name, -3) == "..." then
    arg.variadic = true
    arg._name = String.slice(arg._name, 1, -3)
  end

  return arg :: Arg
end

function Arg.prototype.name(self: Arg): string
  return self._name
end

function Arg.prototype.default(self: Arg, value: any, description: string?): Arg
  self.defaultValue = value
  self.defaultValueDescription = description
  return self
end

function Arg.prototype.argParser(self: Arg, fn: (value: string, previous: any) -> any): Arg
  self.parseArg = fn
  return self
end

return Arg.interface
