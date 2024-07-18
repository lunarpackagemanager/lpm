local types = require("./types")
local util = require("./builtin/util")

local String = require("@deps/string")
local Table = require("@pkg/table")

type Arg = types.Arg
type Opt = types.Opt
type Command = types.Command

local Helper = {}

function Helper.optionTerm(option: Opt): string
  return option.flags
end

function Helper.optionDescription(option: Opt): string
  local extraInfo = {}
  if option.defaultValue ~= nil then
    table.insert(extraInfo, `(default: {option.defaultValue})`)
  end

  if #extraInfo > 0 then
    return `{option.description} {table.concat(extraInfo, ", ")}`
  end

  return option.description :: string
end

function Helper.argumentTerm(arg: Arg): string
  return arg:name()
end

function Helper.argumentDescription(arg: Arg): string
  local extraInfo = {}
  if arg.defaultValue ~= nil then
    table.insert(extraInfo, `default: {arg.defaultValue}`)
  end

  if #extraInfo > 0 then
    local extraDescription = `({table.concat(extraInfo, ", ")})`
    if arg.description then
      return `{arg.description} {extraDescription}`
    end
  end

  return arg.description
end

function Helper.longestArgumentTermLength(cmd: Command): number
  return Table.reduce(Helper.visibleArguments(cmd), function(max, arg)
    return math.max(max, #Helper.argumentTerm(arg))
  end, 0)
end

function Helper.longestSubcommandTermLength(cmd: Command): number
  return Table.reduce(Helper.visibleCommands(cmd), function(max, cmd)
    return math.max(max, #Helper.subCommandTerm(cmd))
  end, 0)
end

function Helper.longestOptionTermLength(cmd: Command): number
  return Table.reduce(Helper.visibleOptions(cmd), function(max, opt)
    return math.max(max, #Helper.optionTerm(opt))
  end, 0)
end

function Helper.padWidth(cmd: Command): number
  return math.max(
    Helper.longestOptionTermLength(cmd),
    Helper.longestSubcommandTermLength(cmd),
    Helper.longestArgumentTermLength(cmd)
  )
end

function Helper.subCommandTerm(cmd: Command)
  local args = table.concat(
    Table.map(cmd.registeredArguments, function(arg)
      return util.humanReadableArgName(arg)
    end),
    " "
  )

  return cmd._name
    .. (cmd._aliases[1] and "|" .. cmd._aliases[1] or "")
    .. (args and " " .. args or "")
    .. (#cmd.options > 0 and " [options]" or "")
end

function Helper.subCommandTerm(cmd: Command): string
  local args = table.concat(
    Table.map(cmd.registeredArguments, function(arg)
      return util.humanReadableArgName(arg)
    end),
    " "
  )

  return cmd._name
    .. (cmd._aliases[1] and "|" .. cmd._aliases[1] or "")
    .. (args and " " .. args or "")
    .. (#cmd.options > 0 and " [options]" or "")
end

function Helper.subCommandDescription(cmd: Command)
  return cmd._description
end

function Helper.optionTerm(option: Opt)
  return option.flags
end

function Helper.argumentTerm(argument: Arg)
  return argument:name()
end

function Helper.optionDescription(option: Opt): string
  return option.description :: string
    .. (not (option.defaultValue == nil) and ' (default: "' .. tostring(option.defaultValue) .. '")' or "")
end

function Helper.commandDescription(cmd: Command)
  return cmd._description
end

function Helper.commandFlag(cmd: Command): string?
  if cmd._hidden then
    return
  end
  local usage = "Usage:"

  return usage
end

function Helper.commandTerm(commander: any, cmd: any): string?
  if cmd._hidden then
    return
  end

  local usage = " "
  return (usage .. (commander._name and commander._name .. " " or "") .. Helper.subCommandTerm(cmd))
end

function Helper.commandUsage(cmd: Command): string?
  local cmdName = cmd._name
  if cmd._aliases[1] then
    cmdName ..= "|" .. cmd._aliases[1]
  end
  local ancestorCmdNames = ""
  local ancestorCmd = cmd.parent
  while ancestorCmd do
    ancestorCmdNames = ancestorCmd._name .. " " .. ancestorCmdNames
    ancestorCmd = ancestorCmd.parent
  end

  return ancestorCmdNames .. cmdName .. " " .. cmd:usage()
end

function Helper.visibleOptions(cmd: Command): { Opt }
  local visibleOptions = Table.filter(cmd.options, function(opt: Opt)
    return not opt.hidden
  end)

  return visibleOptions :: { Opt }
end

function Helper.visibleArguments(cmd: Command)
  if Table.find(cmd.registeredArguments, function(argument)
    return argument.description ~= nil
  end) then
    return cmd.registeredArguments
  end

  return {}
end

function Helper.visibleCommands(cmd: Command)
  local visibleCommands = Table.filter(cmd.commands, function(cmd)
    return not cmd._hidden
  end)

  return visibleCommands
end

function Helper.formatHelp(cmd: Command)
  local termWidth = Helper.padWidth(cmd)
  local itemIndentWidth = 2
  local itemSeparatorWidth = 2

  local function formatItem(term: string, description: string?)
    if description then
      local fullText = `{String.padEnd(term, termWidth + itemSeparatorWidth)}{description}`

      return fullText
    end

    return term
  end

  local function addIndentation(textArray)
    local indent = string.rep(" ", itemIndentWidth)
    local result = {}
    for _, line in ipairs(textArray) do
      table.insert(result, indent .. line)
    end
    return table.concat(result, "\n")
  end

  local function formatList(textArray: { string })
    return addIndentation(textArray)
  end

  local output = {}

  if not cmd.parent then
    output = { cmd._name, "" }
    output = Table.concat(output, { `Usage: {Helper.commandUsage(cmd)}`, "" })
  else
    output = { `Usage: {Helper.commandUsage(cmd)}`, "" }
  end

  local commandDescription = Helper.commandDescription(cmd)
  if #commandDescription > 0 then
    output = Table.concat(output, {
      Helper.commandDescription(cmd),
      "",
    })
  end

  local argumentList = Table.map(Helper.visibleArguments(cmd), function(arg)
    return formatItem(Helper.argumentTerm(arg), Helper.argumentDescription(arg))
  end)

  if #argumentList > 0 then
    output = Table.concat(output, { `Arguments:`, formatList(argumentList), "" })
  end

  local optionList = Table.map(Helper.visibleOptions(cmd), function(opt)
    return formatItem(Helper.optionTerm(opt), Helper.optionDescription(opt))
  end)

  if #optionList > 0 then
    output = Table.concat(output, { "Options:", formatList(optionList), "" })
  end

  local commandList = Table.map(Helper.visibleCommands(cmd), function(cmd)
    return formatItem(Helper.subCommandTerm(cmd), Helper.subCommandDescription(cmd))
  end)

  if #commandList > 0 then
    output = Table.concat(output, { "Commands:", formatList(commandList), "" })
  end

  local result = table.concat(output, "\n")

  return result
end

return Helper
