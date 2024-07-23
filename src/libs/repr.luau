local Ansis = require("./ansis")
local libutil = require("@pkg/libutil")
local output = require("./output")
local Table = libutil.table

export type ReprOptions = {
  spaces: number?,
  tabs: boolean?,
  pretty: boolean?,
  semicolons: boolean?,
  sortKeys: boolean?,
}

local DEFAULT_SETTINGS = {
  pretty = true,
  tabs = false,
  semicolons = false,
  spaces = 2,
  sortKeys = true,
}

local LUA_KEYWORDS = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true,
}

local function is_lua_identifier<T>(str: T)
  return not (
    type(str) ~= "string"
    or #str == 0
    or string.find(str, "[^%d%a_]")
    or tonumber(string.sub(str, 1, 1))
    or LUA_KEYWORDS[str]
  )
end

local function get_float(num: number): string
  local String = tostring(num)
  if tonumber(String) == num then
    return String
  else
    for Index = 15, 99 do
      String = string.format("%." .. Index .. "f", num)
      if tonumber(String) == num then
        return String
      end
    end

    error("Something failed?", 2)
  end
end

local function integer_or_float(num: number)
  num = tonumber(num) :: number
  return num % 1 == 0 and string.format("%d", num) or get_float(num)
end

local Colors = {
  boolean = Ansis.hex("#f9e2af"),
  number = Ansis.hex("#fab387"),
  ["nil"] = Ansis.hex("#f9e2af"),
  string = Ansis.hex("#a6da95"),
}

local function escape_special_chars(str: string)
  return str:gsub("\\", "\\\\"):gsub("\n", "\\n")
end

local function safe_string_format(format: string, str: string)
  local escaped_str = escape_special_chars(str)
  return string.format(format, escaped_str)
end

local INDENT
local shown
local depth = 0
local function repr<T>(value: T, reprOptions: ReprOptions?): string
  local reprSettings: ReprOptions = reprOptions or {}
  reprSettings = Table.reconcile(reprSettings, DEFAULT_SETTINGS)
  INDENT = string.rep(" ", reprSettings.spaces :: number)
  if reprSettings.tabs then
    INDENT = "\t"
  end

  local newValue = value
  local tabs = string.rep(INDENT, depth)

  if depth == 0 then
    shown = {}
  end

  if typeof(newValue) == "string" then
    return Colors.string(safe_string_format("%q", newValue))
  elseif typeof(newValue) == "number" then
    if newValue == math.huge then
      return "math.huge"
    end
    if newValue == -math.huge then
      return "-math.huge"
    end
    return Colors.number(integer_or_float(newValue))
  elseif typeof(newValue) == "boolean" then
    return Colors.boolean(tostring(newValue))
  elseif typeof(newValue) == "nil" then
    return Colors["nil"]("nil")
  elseif typeof(newValue) == "table" then
    if shown[newValue] then
      return "{CYCLIC}"
    end
    shown[newValue] = true
    local str = "{" .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or "")
    local isArray = Table.isArray(newValue)
    if isArray then
      for index, value in ipairs(newValue) do
        if index ~= 1 then
          str ..= (reprSettings.semicolons and ";" or ",") .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or " ")
        end
        depth += 1
        str ..= repr(value, reprSettings)
        depth -= 1
      end
    else
      local keyOrder = {}
      local keyValueStrings = {}
      local length = 0
      for key, value in next, newValue do
        depth += 1
        local keyString = is_lua_identifier(key) and key or repr(key, reprSettings)
        local valueString = repr(value, reprSettings)

        length += 1
        keyOrder[length] = keyString
        keyValueStrings[keyString] = valueString
        depth -= 1
      end
      if reprSettings.sortKeys then
        table.sort(keyOrder)
      end
      local first = true
      for _, keyString in keyOrder do
        if not first then
          str ..= (reprSettings.semicolons and ";" or ",") .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or " ")
        end
        str ..= string.format("%s = %s", keyString, keyValueStrings[keyString])
        first = false
      end
    end
    shown[newValue] = false
    if reprSettings.pretty then
      str ..= "\n" .. tabs
    end
    return str .. "}"
  else
    return "<" .. typeof(newValue) .. ">"
  end
end

return repr
