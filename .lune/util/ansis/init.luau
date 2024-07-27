local utils = require("./utils")

local hexToRgb = utils.hexToRgb

local ESC = `\x1b`

type Style = {
  open: string,
  close: string,
}

local close = 39
local bgClose = 49

local function esc(open: string | number, close: number): Style
  local open = `{ESC}[{open}m`
  local close = `{ESC}[{close}m`
  return { open = open, close = close }
end

local function fnAnsi256(code: number)
  return esc(`38;5;{code}`, close)
end

local function fnBgAnsi256(code: number)
  return esc(`48;5;{code}`, bgClose)
end

local function fnRgb(r: number, g: number, b: number)
  return esc(`38;2;{r};{g};{b}`, close)
end

local function fnBgRgb(r: number, g: number, b: number)
  return esc(`48;2;{r};{g};{b}m`, bgClose)
end

local function createHexFn(fn: (r: number, g: number, b: number) -> Style)
  return function(hex: string): Style
    local rgb = hexToRgb(hex)
    local r, g, b = rgb[1], rgb[2], rgb[3]
    return fn(r, g, b)
  end
end

local function createStyleWrapper(style: Style, ...: string)
  local strs = {}
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if typeof(value) == "table" then
      value = {}
    end
    if value == nil or type(value) == "string" and #value == 0 then
      return ""
    end

    if string.match(value, `\u{001B}`) then
      value = utils.replaceAll(value, style.close, style.open)
    end

    local lfIndex = string.find(value, "\n")
    if lfIndex ~= nil then
      value = utils.stringEncaseCRLFWithFirstIndex(value, style.open, style.close, lfIndex)
    end

    table.insert(strs, `{style.open}{value}{style.close}`)
  end
  return `{table.concat(strs, " ")}`
end

local function createStyleFunction(style: Style)
  return function(...: string)
    return createStyleWrapper(style, ...)
  end
end

return table.freeze({
  -- misc
  visible = createStyleFunction({ open = "", close = "" }),
  reset = createStyleFunction(esc(0, 0)),
  inverse = createStyleFunction(esc(7, 27)),
  hidden = createStyleFunction(esc(8, 28)),

  -- styles
  bold = createStyleFunction(esc(1, 22)),
  dim = createStyleFunction(esc(2, 22)),
  italic = createStyleFunction(esc(3, 23)),
  underline = createStyleFunction(esc(4, 24)),
  strikethrough = createStyleFunction(esc(9, 29)),
  strike = createStyleFunction(esc(9, 29)), -- alias for strikethrough

  -- foreground colors
  black = createStyleFunction(esc(30, close)),
  red = createStyleFunction(esc(31, close)),
  green = createStyleFunction(esc(32, close)),
  yellow = createStyleFunction(esc(33, close)),
  blue = createStyleFunction(esc(34, close)),
  magenta = createStyleFunction(esc(35, close)),
  cyan = createStyleFunction(esc(36, close)),
  white = createStyleFunction(esc(37, close)),
  grey = createStyleFunction(esc(90, close)),
  gray = createStyleFunction(esc(90, close)),
  blackBright = createStyleFunction(esc(90, close)),
  redBright = createStyleFunction(esc(91, close)),
  greenBright = createStyleFunction(esc(92, close)),
  yellowBright = createStyleFunction(esc(93, close)),
  blueBright = createStyleFunction(esc(94, close)),
  magentaBright = createStyleFunction(esc(95, close)),
  cyanBright = createStyleFunction(esc(96, close)),
  whiteBright = createStyleFunction(esc(97, close)),

  -- background colors
  bgBlack = createStyleFunction(esc(40, bgClose)),
  bgRed = createStyleFunction(esc(41, bgClose)),
  bgGreen = createStyleFunction(esc(42, bgClose)),
  bgYellow = createStyleFunction(esc(43, bgClose)),
  bgBlue = createStyleFunction(esc(44, bgClose)),
  bgMagenta = createStyleFunction(esc(45, bgClose)),
  bgCyan = createStyleFunction(esc(46, bgClose)),
  bgWhite = createStyleFunction(esc(47, bgClose)),
  bgGrey = createStyleFunction(esc(100, close)),
  bgGray = createStyleFunction(esc(100, bgClose)),
  bgBlackBright = createStyleFunction(esc(100, bgClose)),
  bgRedBright = createStyleFunction(esc(101, bgClose)),
  bgGreenBright = createStyleFunction(esc(102, bgClose)),
  bgYellowBright = createStyleFunction(esc(103, bgClose)),
  bgBlueBright = createStyleFunction(esc(104, bgClose)),
  bgMagentaBright = createStyleFunction(esc(105, bgClose)),
  bgCyanBright = createStyleFunction(esc(106, bgClose)),
  bgWhiteBright = createStyleFunction(esc(107, bgClose)),

  -- Methods
  hex = function(hex: string)
    local style: Style = createHexFn(fnRgb)(hex)
    return createStyleFunction(style)
  end,
  bgHex = function(hex: string)
    local style: Style = createHexFn(fnBgRgb)(hex)
    return createStyleFunction(style)
  end,
  rgb = function(r: number, g: number, b: number)
    local style: Style = fnRgb(r, g, b)
    return createStyleFunction(style)
  end,
  bgRgb = function(r: number, g: number, b: number)
    local style: Style = fnBgRgb(r, g, b)
    return createStyleFunction(style)
  end,
  bg = function(ansi: number)
    local style: Style = fnBgAnsi256(ansi)
    return createStyleFunction(style)
  end,
  fg = function(ansi: number)
    local style: Style = fnAnsi256(ansi)
    return createStyleFunction(style)
  end,
})
