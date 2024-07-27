--!nocheck

local disable_ansi = false

local color = {
  white_underline = function(s: string): string
    return if disable_ansi then s else `\27[1;4m{s}\27[0m`
  end,

  white = function(s: string): string
    return if disable_ansi then s else `\27[37;1m{s}\27[0m`
  end,

  green = function(s: string): string
    return if disable_ansi then s else `\27[32;1m{s}\27[0m`
  end,

  red = function(s: string): string
    return if disable_ansi then s else `\27[31;1m{s}\27[0m`
  end,

  yellow = function(s: string): string
    return if disable_ansi then s else `\27[33;1m{s}\27[0m`
  end,

  red_highlight = function(s: string): string
    return if disable_ansi then s else `\27[41;1;30m{s}\27[0m`
  end,

  green_highlight = function(s: string): string
    return if disable_ansi then s else `\27[42;1;30m{s}\27[0m`
  end,

  gray = function(s: string): string
    return if disable_ansi then s else `\27[38;1m{s}\27[0m`
  end,

  orange = function(s: string): string
    return if disable_ansi then s else `\27[38;5;208m{s}\27[0m`
  end,
}

local WALL = color.gray("│")

local function convert_units(unit: string, value: number): (number, string)
  local sign = math.sign(value)
  value = math.abs(value)

  local prefix_colors = {
    [4] = color.red,
    [3] = color.red,
    [2] = color.yellow,
    [1] = color.yellow,
    [0] = color.green,
    [-1] = color.red,
    [-2] = color.yellow,
    [-3] = color.green,
    [-4] = color.red,
  }

  local prefixes = {
    [4] = "T",
    [3] = "G",
    [2] = "M",
    [1] = "k",
    [0] = " ",
    [-1] = "m",
    [-2] = "u",
    [-3] = "n",
    [-4] = "p",
  }

  local order = 0

  while value >= 1000 do
    order += 1
    value /= 1000
  end

  while value ~= 0 and value < 1 do
    order -= 1
    value *= 1000
  end

  if value >= 100 then
    value = math.floor(value)
  elseif value >= 10 then
    value = math.floor(value * 1e1) / 1e1
  elseif value >= 1 then
    value = math.floor(value * 1e2) / 1e2
  end

  return value * sign, prefix_colors[order](prefixes[order] .. unit)
end

--------------------------------------------------------------------------------
-- Benchmarking
--------------------------------------------------------------------------------

type Bench = {
  time_start: number?,
  memory_start: number?,
  iterations: number?,
}

local bench: Bench?

function START(iter: number?): number
  local n = iter or 1
  assert(n > 0, "iterations must be greater than 0")
  assert(bench, "no active benchmark")
  assert(not bench.time_start, "clock was already started")

  bench.iterations = n
  bench.memory_start = gcinfo()
  bench.time_start = os.clock()
  return n
end

local function BENCH(name: string, fn: () -> ())
  local active = bench
  assert(not active, "a benchmark is already in progress")

  bench = {}
  assert(bench);
  (collectgarbage :: any)("collect")

  local mem_start = gcinfo()
  local time_start = os.clock()
  local err_msg: string?

  local success = xpcall(fn, function(m: string)
    err_msg = m .. debug.traceback(nil, 2)
  end)

  local time_stop = os.clock()
  local mem_stop = gcinfo()

  if not success then
    print(`{WALL}{color.red("ERROR")}{WALL} {name}`)
    print(color.gray(err_msg :: string))
  else
    time_start = bench.time_start or time_start
    mem_start = bench.memory_start or mem_start

    local n = bench.iterations or 1
    local d, d_unit = convert_units("s", (time_stop - time_start) / n)
    local a, a_unit = convert_units("B", math.round((mem_stop - mem_start) / n * 1e3))

    local function round(x: number): string
      return x > 0 and x < 10 and (x - math.floor(x)) > 0 and string.format("%2.1f", x) or string.format("%3.f", x)
    end

    print(
      string.format(
        `%s %s %s %s{WALL} %s`,
        color.gray(round(d)),
        d_unit,
        color.gray(round(a)),
        a_unit,
        color.gray(name)
      )
    )
  end

  bench = nil
end

local function TITLE(title: string)
  print()
  print(color.white(title))
end

return {
  benchmark = function()
    return BENCH, START
  end,
  title = TITLE,
}
