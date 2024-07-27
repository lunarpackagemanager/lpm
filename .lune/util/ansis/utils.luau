local round, floor, max = math.round, math.floor, math.max

local function replaceAll(str: string, searchValue: string, replaceValue: string)
  if searchValue == "" then
    return str
  end

  local substringLength = #searchValue
  local lastPos = 1
  local result = ""
  local pos

  while true do
    pos = string.find(str, searchValue, lastPos, true)
    if not pos then
      break
    end
    result ..= string.sub(str, lastPos, pos - 1) .. replaceValue
    lastPos = pos + substringLength
  end

  return lastPos > 1 and result .. string.sub(str, lastPos) or str
end

local function hexToRgb(value: string): { number }
  local color = string.match(value, "([a-fA-F%d]+)")
  local len = color and #color or 0

  if len == 3 then
    color = string.sub(color :: string, 1, 1)
      .. string.sub(color :: string, 1, 1)
      .. string.sub(color :: string, 2, 2)
      .. string.sub(color :: string, 2, 2)
      .. string.sub(color :: string, 3, 3)
      .. string.sub(color :: string, 3, 3)
  elseif len ~= 6 then
    return { 0, 0, 0 }
  end

  local num = tonumber(color, 16) :: number

  local r = bit32.rshift(bit32.band(num, 0xFF0000), 16)
  local g = bit32.rshift(bit32.band(num, 0x00FF00), 8)
  local b = bit32.band(num, 0x0000FF)

  return { r, g, b }
end

local function rgbToAnsi256(r: number, g: number, b: number): number
  if r == g and g == b then
    if r < 8 then
      return 16
    end
    if r > 248 then
      return 231
    end

    return round(((r - 8) / 247) * 24) + 232
  end

  return 16 + (36 * round(r / 51)) + (6 * round(g / 51)) + round(b / 51)
end

local function ansi256To16(code: number): number
  local r, g, b

  if code < 8 then
    return 30 + code
  end

  if code < 16 then
    return 90 + (code - 8)
  end

  if code >= 232 then
    r = ((code - 232) * 10 + 8) / 255
    g = r
    b = r
  else
    code -= 16

    local remainder = code % 36

    r = floor(code / 36) / 5
    g = floor(remainder / 6) / 5
    b = (remainder % 6) / 5
  end

  local value = max(r, g, b) * 2

  if value == 0 then
    return 30
  end

  local code16 = 30 + (bit32.bor(bit32.lshift(round(b), 2), bit32.lshift(round(g), 1), round(r)))

  return value == 2 and code16 + 60 or code16
end

local function rgbToAnsi16(r: number, g: number, b: number): number
  return ansi256To16(rgbToAnsi256(r, g, b))
end

local function stringEncaseCRLFWithFirstIndex(string_: string, prefix: string, postfix: string, index: number): string
  local endIndex = 1
  local returnValue = ""
  repeat
    local gotCR = string.sub(string_, index - 1, index - 1) == "\r"
    returnValue ..= string.sub(string_, endIndex, if gotCR then index - 2 else index - 1) .. prefix .. (if gotCR
      then "\r\n"
      else "\n") .. postfix
    endIndex = index + 1
    index = string.find(string_, "\n", endIndex) :: number
  until not (index ~= nil)
  returnValue ..= string.sub(string_, endIndex)
  return returnValue
end

return table.freeze({
  replaceAll = replaceAll,
  hexToRgb = hexToRgb,
  rgbToAnsi256 = rgbToAnsi256,
  ansi256To16 = ansi256To16,
  rgbToAnsi16 = rgbToAnsi16,
  stringEncaseCRLFWithFirstIndex = stringEncaseCRLFWithFirstIndex,
})
