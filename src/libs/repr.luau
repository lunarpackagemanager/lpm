local Ansis = require("./ansis")
local libutil = require("@pkg/libutil")
local Table = libutil.table

export type ReprOptions = {
  spaces: number?,
  tabs: boolean?,
  pretty: boolean?,
  semicolons: boolean?,
  sortKeys: boolean?,
  console: boolean?,
}

local DEFAULT_SETTINGS = {
  pretty = true,
  tabs = false,
  semicolons = false,
  spaces = 4,
  sortKeys = true,
  console = false,
}

local keywords = {
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

local function isLuaIdentifier<T>(str: T)
  if type(str) ~= "string" then
    return false
  end
  -- must be nonempty
  if str:len() == 0 then
    return false
  end
  -- can only contain a-z, A-Z, 0-9 and underscore
  if str:find("[^%d%a_]") then
    return false
  end
  -- cannot begin with digit
  if tonumber(str:sub(1, 1)) then
    return false
  end
  -- cannot be keyword
  if keywords[str] then
    return false
  end
  return true
end

local Colors = {
  boolean = Ansis.hex("#f9e2af"),
  number = Ansis.hex("#fab387"),
  ["nil"] = Ansis.hex("#f9e2af"),
  string = Ansis.hex("#a6da95"),
}

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

  local v = value --args[1]
  local tabs = string.rep(INDENT, depth)

  if depth == 0 then
    shown = {}
  end

  if typeof(v) == "string" then
    return Colors.string(string.format("%s", v))
  elseif typeof(v) == "number" then
    if v == math.huge then
      return "math.huge"
    end
    if v == -math.huge then
      return "-math.huge"
    end
    return Colors.number(tostring(v))
  elseif typeof(v) == "boolean" then
    return Colors.boolean(tostring(v))
  elseif typeof(v) == "nil" then
    return Colors["nil"]("nil")
  elseif typeof(v) == "table" then
    if shown[v] then
      return "{CYCLIC}"
    end
    shown[v] = true
    local str = "{" .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or "")
    local isArray = Table.isArray(v)
    if isArray then
      if #v == 0 then
      else
        for i = 1, #v do
          if i ~= 1 then
            str ..= (reprSettings.semicolons and ";" or ",") .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or " ")
          end
          depth = depth + 1
          str = str .. repr(v[i])
          depth = depth - 1
        end
      end
    else
      local keyOrder = {}
      local keyValueStrings = {}
      for k, v in v do
        depth = depth + 1
        local kStr = isLuaIdentifier(k) and ("" .. k .. "") or ("" .. repr(k) .. "")
        local vStr = repr(v)
        table.insert(keyOrder, kStr)
        keyValueStrings[kStr] = vStr
        depth = depth - 1
      end
      if reprSettings.sortKeys then
        table.sort(keyOrder)
      end
      local first = true
      for _, kStr in keyOrder do
        if not first then
          str ..= (reprSettings.semicolons and ";" or ",") .. (reprSettings.pretty and ("\n" .. INDENT .. tabs) or " ")
        end
        str ..= string.format("%s = %s", kStr, keyValueStrings[kStr])
        first = false
      end
    end
    shown[v] = false
    if reprSettings.pretty then
      str = str .. "\n" .. tabs
    end
    str = str .. "}"
    return str
  else
    return "<" .. type(v) .. ">"
  end
end

return repr
