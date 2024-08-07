--!nolint
--!nocheck

local serde = require("@lune/serde")
local std = require("@pkg/std")
local stdio = require("@lune/stdio")

local config = require("../config")

local process = std.process

local LEADER = "  "

local output = {}

function output.format(
  format: { stdio.Color | stdio.Style } | stdio.Color | stdio.Style,
  text: string
)
  if typeof(format) == "string" then
    format = { format }
  end

  local format_header = ""

  for _, fmt in pairs(format) do
    local is_colour, colour = pcall(stdio.color, fmt)
    if is_colour then
      format_header ..= colour
    else
      local is_style, style = pcall(stdio.style, fmt :: any)
      if is_style then
        format_header ..= style
      else
        error(`Format '{fmt}' does not exist.`, 2)
      end
    end
  end

  return format_header .. text .. stdio.color("reset")
end

local ERROR_HEADER = output.format(config.colour_theme.error :: any, "error: ")
local WARN_HEADER = output.format(config.colour_theme.warn :: any, "warn: ")

function output.write_removable(message: string): () -> ()
  if _G.LPM_OUTPUT_MODE == "CLI" then
    process.stdout.write(LEADER .. message)
  end

  return function()
    process.stdout.write(("\b"):rep(#(LEADER .. message)))
    process.stdout.write((" "):rep(#(LEADER .. message)))
    process.stdout.write(("\b"):rep(#(LEADER .. message)))
  end
end

function output.write(message: string | any)
  if _G.LPM_OUTPUT_MODE == "CLI" then
    if typeof(message) == "table" then
      message = serde.encode("json", message, true)
    end
    process.stdout.write(message .. "\n")
  end
end

function output.warn(message: string, secondary_message: string?)
  if _G.LPM_OUTPUT_MODE == "CLI" then
    process.stdout.write(LEADER .. WARN_HEADER .. message .. "\n")
    if secondary_message then
      process.stdout.write(LEADER .. secondary_message .. "\n")
    end
  else
    warn(message)
  end
end

function output.error(message: string, secondary_message: string?)
  if _G.LPM_OUTPUT_MODE == "CLI" then
    process.stderr.write(LEADER .. ERROR_HEADER .. message .. "\n")
    if secondary_message then
      process.stderr.write(LEADER .. secondary_message .. "\n")
    end
    process.exit(1)
    error(message, 2)
  else
    error(message, 2)
  end
end

function output.assert(condition: any?, message: string, secondary_message: string?)
  if not condition then
    output.error(message, secondary_message)
  end
end

function output.header()
  if _G.LPM_OUTPUT_MODE == "CLI" then
    process.stdout.write(
      `{output.format(config.colour_theme.author :: any, config.author)}/{output.format(
        config.colour_theme.primary :: any,
        config.name.long
      )} v{config.version}`
    )
  end
end

if _G.LPM_OUTPUT_MODE == "CLI" then
  _G.LPM_OLD_ASSERT = assert
  assert = output.assert
end

return output
