local LUA_PATTERN_CHARACTERS = string.gsub("([" .. "$%^()-[].?", "(.)", "%%%1") .. "])"

local String = {}

function String.slice(str: string, startIndexStr: string | number, lastIndexStr: (string | number)?): string
  local strLen, invalidBytePosition = utf8.len(str)
  assert(strLen ~= nil, ("string `%s` has an invalid byte at position %s"):format(str, tostring(invalidBytePosition)))
  local startIndex = tonumber(startIndexStr)
  assert(typeof(startIndex) == "number", "startIndexStr should be a number")

  if startIndex + strLen < 0 then
    -- then |start index| is greater than string length
    startIndex = 1
  end

  if startIndex > strLen then
    return ""
  end

  -- if no last index length set, go to str length + 1
  local lastIndex = strLen + 1
  if lastIndexStr ~= nil then
    -- ROBLOX FIXME: add parseInt to encapsulate this logic and use it here
    local NaN = 0 / 0
    lastIndex = tonumber(lastIndexStr) or NaN -- this works because 0 is truthy in Lua
  end
  assert(typeof(lastIndex) == "number", "lastIndexStr should convert to number")

  if lastIndex > strLen then
    lastIndex = strLen + 1
  end

  local startIndexByte = utf8.offset(str, startIndex) :: number
  -- get char length of charset retunred at offset
  local lastIndexByte = utf8.offset(str, lastIndex) :: number - 1

  return string.sub(str, startIndexByte, lastIndexByte)
end

function String.startsWith(value: string, substring: string, position: number?): boolean
  if string.len(substring) == 0 then
    return true
  end
  -- Luau FIXME: we have to use a tmp variable, as Luau doesn't understand the logic below narrow position to `number`
  local position_
  if position == nil or position < 1 then
    position_ = 1
  else
    position_ = position
  end

  if position_ > string.len(value) then
    return false
  end
  return value:find(substring, position_, true) == position_
end

function String.padEnd(str: string, len: number, pad: string?)
  pad = pad or " "

  local strLen = #str
  local padLen = len - strLen

  if padLen <= 0 then
    return str
  end

  local paddedStr = str .. string.rep(pad :: string, padLen)

  return string.sub(paddedStr, 1, strLen < len and len or strLen)
end

function String.gsplit(text: string, pattern: string, plain: boolean?): () -> ...string
  local splitStart, length = 1, #text
  return function(): ...string
    if splitStart then
      local sepStart, sepEnd = string.find(text, pattern, splitStart, plain)
      local ret
      if not sepStart then
        ret = string.sub(text, splitStart)
        splitStart = nil :: any
      elseif sepEnd < sepStart then
        -- Empty separator!
        ret = string.sub(text, splitStart, sepStart)
        if sepStart < length then
          splitStart = sepStart + 1
        else
          splitStart = nil :: any
        end
      else
        ret = sepStart > splitStart and string.sub(text, splitStart, sepStart - 1) or ""
        splitStart = sepEnd :: number + 1
      end
      return ret
    end
  end
end

function String.split(text: string, pattern: string, plain: boolean?)
  local ret = {}
  for match in String.gsplit(text, pattern, plain) do
    table.insert(ret, match)
  end
  return ret
end

function String.includes(str: string, substring: string, position: (string | number)?): boolean
  local strLen, invalidBytePosition = utf8.len(str)
  assert(strLen ~= nil, ("string `%s` has an invalid byte at position %s"):format(str, tostring(invalidBytePosition)))
  if strLen == 0 then
    return false
  end

  if #substring == 0 then
    return true
  end

  local startIndex = 1
  if position ~= nil then
    startIndex = tonumber(position) or 1
    if startIndex > strLen then
      return false
    end
  end

  if startIndex < 1 then
    startIndex = 1
  end

  local init = utf8.offset(str, startIndex)
  local value = string.gsub(substring, LUA_PATTERN_CHARACTERS, "%%%1")
  local iStart, _ = string.find(str, value, init)
  return iStart ~= nil
end

function String.indexOf(str: string, searchElement: string, fromIndex: number?): number
  local length = #str
  local fromIndex_ = if fromIndex ~= nil then if fromIndex < 1 then 1 else fromIndex :: number else 1

  if #searchElement == 0 then
    return if fromIndex_ > length then length else fromIndex_
  end

  if fromIndex_ > length then
    return -1
  end

  searchElement = string.gsub(searchElement, LUA_PATTERN_CHARACTERS, "%%%1")
  local searchElementLength = #searchElement

  for i = fromIndex_, length do
    if string.sub(str, i, i + searchElementLength - 1) == searchElement then
      return i
    end
  end

  return -1
end

function String.trim(source: string)
  return String.trimStart(String.trimEnd(source))
end

function String.trimStart(source: string): string
  return (source:gsub("^[%s]+", ""))
end

function String.trimEnd(source: string): string
  return (source:gsub("[%s]+$", ""))
end

return setmetatable(String, {
  __index = string,
})
