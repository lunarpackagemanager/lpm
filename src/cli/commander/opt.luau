local types = require("./types")

local polyfill = require("@pkg/polyfill")

local Array = polyfill.Array
local String = polyfill.String

local Opt = {}
Opt.interface = {}
Opt.prototype = {}

type Opt = types.Opt

export type OptList = types.OptList

local function splitOptionFlags(flags: string)
  local shortFlag
  local longFlag

  -- Use original very loose parsing to maintain backwards compatibility
  -- Split flags based on spaces or commas followed by any number of spaces
  local flagParts = {}

  for part in flags:gmatch("[^%s|,]+") do
    table.insert(flagParts, part)
  end

  if #flagParts > 1 and not flagParts[2]:match("^%[<[") then
    shortFlag = table.remove(flagParts, 1)
  end

  longFlag = table.remove(flagParts, 1)

  -- Add support for lone short flag without significantly changing parsing
  if not shortFlag and longFlag and longFlag:match("^%-[^%-]$") then
    shortFlag = longFlag
    longFlag = nil
  end

  if longFlag then
    longFlag = string.gsub(longFlag, "^-%-", "")
  end

  if shortFlag then
    shortFlag = string.gsub(shortFlag, "^-", "")
  end

  return { shortFlag = shortFlag, longFlag = longFlag }
end

local function camelcase(str: string)
  local splittedString = string.split(str, "-")

  return Array.reduce(splittedString, function(str: string, word)
    local wordSplit = string.split(word, "")
    return str .. wordSplit[1]:upper() .. String.slice(word, 2)
  end)
end

function Opt.interface.new(flags: string, description: string?): Opt
  local optionFlags = splitOptionFlags(flags)

  local option = {
    flags = flags,
    description = description or "",
    long = optionFlags.longFlag and "--" .. optionFlags.longFlag or nil,
    short = optionFlags.shortFlag and "-" .. optionFlags.shortFlag or nil,
    required = String.includes(flags, "<"),
    optional = String.includes(flags, "["),
    mandatory = false,
    defaultValue = nil,
    defaultValueDescription = nil,
    hidden = false,
    parseArg = nil,
  }

  local self = (
    setmetatable(option, {
      __index = Opt.prototype,
      __tostring = function(_)
        return "Opt"
      end,
    })
  )

  return (self :: any) :: Opt
end

function Opt.prototype.default(self: Opt, value: any, description: string?): Opt
  self.defaultValue = value
  self.defaultValueDescription = description

  return self
end

function Opt.prototype.hide(self: Opt, hide: boolean?): Opt
  local actualHide: boolean = hide == nil and true or hide :: boolean
  self.hidden = actualHide

  return self
end

function Opt.prototype.makeOptionMandatory(self: Opt, mandatory: boolean?): Opt
  local actualMandatory: boolean = mandatory == nil and true or mandatory :: boolean

  self.mandatory = not not actualMandatory

  return self
end

function Opt.prototype.name(self: Opt): string
  if self.long then
    local name = string.gsub(self.long, "^-%-", "")
    return name
  end

  local name = string.gsub(self.short :: string, "^-", "")
  return name
end

function Opt.prototype.argParser(self: Opt, fn: (value: string, value: any) -> any): Opt
  self.parseArg = fn

  return self
end

function Opt.prototype.attributeName(self: Opt): string
  return camelcase(self:name())
end

function Opt.prototype.is(self: Opt, arg: string): boolean
  return self.short == arg or self.long == arg
end

function Opt.prototype.isFlag(self: Opt): boolean
  return not self.required and not self.optional
end

return Opt.interface
