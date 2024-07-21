local Arg = require("./arg")
local Helper = require("./helper")
local Opt = require("./opt")
local types = require("./types")

local Error = require("./builtin/error")
local libutil = require("@pkg/libutil")
local std = require("@pkg/std")
local util = require("./builtin/util")

local Table = libutil.table
local String = libutil.string
local class = libutil.class
local eventEmitter = libutil.eventEmitter

local process = std.process

type Opt = types.Opt
type Arg = types.Arg
type Command = types.Command

local Command = {}
Command.prototype = {}
Command.interface = {}

function Command.interface.new(name: string?): Command
  local command = {
    commands = {},
    options = {},
    parent = nil,
    registeredArguments = {},
    args = {},
    processedArgs = {},
    _name = name or "",
    _optionValues = {},
    _actionHandler = nil,
    _aliases = {},
    _combineFlagAndOptionalValue = true,
    _description = "",
    _summary = "",
    _hidden = false,
    _helpOption = nil,
    _helpCommand = nil,
    _showHelpAfterError = false,
    _showSuggestionAfterError = true,
    _outputConfiguration = {
      writeOut = function(str: string)
        return process.stdout.write(str)
      end,
      writeErr = function(str: string)
        return process.stderr.write(str)
      end,
      outputError = function(str: string, write: (string) -> ())
        return write(str)
      end,
    },
  }

  return class(command, Command.prototype):extend(eventEmitter.new()) :: Command
end

function Command.prototype.copyInheritedSettings(self: Command, sourceCommand: Command): Command
  self._helpOption = sourceCommand._helpOption
  self._helpCommand = sourceCommand._helpCommand
  self._combineFlagAndOptionalValue = sourceCommand._combineFlagAndOptionalValue
  self._showHelpAfterError = sourceCommand._showHelpAfterError
  self._showSuggestionAfterError = sourceCommand._showSuggestionAfterError

  return self
end

function Command.prototype._getCommandAndAncestors(self: Command): { Command }
  local result: { Command } = {}
  local command = self
  while command do
    table.insert(result, command)
    command = command.parent :: Command
  end

  return result
end

function Command.prototype.command(self: Command, nameAndArgs: string): Command
  local name, args = nameAndArgs:match("([^ ]+) *(.*)")
  local cmd = self:createCommand(name :: string)
  if args and args ~= "" then
    cmd:arguments(args)
  end
  self:_registerCommand(cmd)
  cmd.parent = self
  cmd:copyInheritedSettings(self)

  return cmd
end

function Command.prototype.createCommand(_: Command, name: string): Command
  return Command.interface.new(name)
end

function Command.prototype.showHelpAfterError(self: Command, displayHelp: boolean?): Command
  local actualDisplayHelp: boolean = displayHelp == nil and true or displayHelp :: boolean
  self._showHelpAfterError = not not actualDisplayHelp
  return self
end

function Command.prototype.showSuggestionAfterError(self: Command, displaySuggestion: boolean?): Command
  local actualDisplaySuggestion: boolean = displaySuggestion == nil and true or displaySuggestion :: boolean
  self._showSuggestionAfterError = not not actualDisplaySuggestion
  return self
end

function Command.prototype.addCommand(self: Command, cmd: Command, opts: { [string]: any }?): Command
  if not cmd._name then
    Error.new(
      `Command passed to .addCommand() must have a name - specifify the name in Command constructor or using :name()`
    )
      :throw()
  end

  local actualOpts: { [string]: any } = opts or {}

  if actualOpts.isDefault then
    self._defaultCommandName = cmd._name
  end

  if actualOpts.noHelp or actualOpts.hidden then
    cmd._hidden = true
  end

  self:_registerCommand(cmd)
  cmd.parent = self

  return self
end

function Command.prototype.createArgument(_: Command, name: string, description: string?): Arg
  return Arg.new(name, description)
end

function Command.prototype.argument(self: Command, name: string, description: string?, defaultValue: any?): Command
  local argument = self:createArgument(name, description)
  argument:default(defaultValue)
  self:addArgument(argument)

  return self
end

function Command.prototype.arguments(self: Command, names: string): Command
  local splitted = string.split(String.trim(names), " ")
  for _, detail in splitted do
    self:argument(detail)
  end

  return self
end

function Command.prototype.addArgument(self: Command, argument: Arg): Command
  local previousArgument = Table.slice(self.registeredArguments, -1)[1]
  if previousArgument and previousArgument.variadic then
    Error.new(`only the last argument can be variadic: '{previousArgument:name()}'`):throw()
  end

  if argument.required and argument.defaultValue ~= nil then
    Error.new(`a default value for a required argument is never used: '{argument:name()}'`):throw()
  end

  table.insert(self.registeredArguments, argument)

  return self
end

function Command.prototype.helpCommand(self: Command, nameAndArgs: string?, description: string?): Command
  local actualNameAndArgs = nameAndArgs or "help [command]"
  local helpName, helpArgs = actualNameAndArgs:match("([^ ]+) *(.*)")
  local helpDescription = description or "display help for command"

  local helpCommand = Command.interface.new(helpName)
  helpCommand:helpOption(false)

  if helpArgs then
    helpCommand:argument(helpArgs)
  end

  if helpDescription then
    helpCommand:description(helpDescription)
  end

  self._addImplicitHelpCommand = true
  self._helpCommand = helpCommand

  return self
end

function Command.prototype._getHelpCommand(self: Command): Command?
  if self._helpCommand == nil then
    self:helpCommand(nil, nil)
  end

  return self._helpCommand
end

function Command.prototype.action(self: Command, fn: (...any) -> ()): Command
  assert(fn, "fn <function> is required for " .. self._name .. " command")
  local function listener(args)
    local expectedArgsCount = #self.registeredArguments
    local actionArgs = Table.slice(args, 1, expectedArgsCount + 1)
    actionArgs[expectedArgsCount + 1] = self:opts()
    Table.push(actionArgs, self)

    fn(Table.spread(actionArgs))
  end
  self._actionHandler = listener

  return self
end

function Command.prototype.createOption(_: Command, flags: string, description: string?): Opt
  return Opt.new(flags, description)
end

function Command.prototype._callParseArg(
  self: Command,
  target: Opt | Arg,
  value: string,
  previous: any,
  invalidArgumentMessage: string
): ()
  local success, err = pcall(target.parseArg :: any, value, previous)
  if not success then
    local message = `{invalidArgumentMessage} {err}`
    self:error(message, 0)
  end
end

function Command.prototype._registerOption(self: Command, option: Opt): ()
  local matchingOption: Opt? = (
    option.short and self:_findOption(option.short) or (option.long and self:_findOption(option.long))
  )
  if matchingOption then
    local matchingFlag = option.long and self:_findOption(option.long) and option.long or option.short
    Error.new(
      `Cannot add option '{option.flags}'{self._name and ` to command '{self._name}'`} due to conflicting flag '{matchingFlag}' - already used by option '{matchingOption.flags}'`
    ):throw()
  end
  Table.push(self.options, option)
  table.sort(self.options, function(a, b)
    return a:name() < b:name()
  end)
end

function Command.prototype._registerCommand(self: Command, command: Command): ()
  local knownBy = function(cmd: Command)
    return Table.concat(cmd._name, cmd._aliases)
  end

  local alreadyUsed = Table.find(knownBy(command), function(name)
    return self:_findCommand(name) ~= nil
  end)

  if alreadyUsed then
    local existingCmd = table.concat(knownBy(self:_findCommand(alreadyUsed) :: Command), "|")
    local newCmd = table.concat(knownBy(command), "|")
    Error.new(`cannot add command '{newCmd}' as already have command '{existingCmd}'`):throw()
  end

  Table.push(self.commands, command)
  table.sort(self.commands, function(a, b)
    return a._name < b._name
  end)
end

function Command.prototype.addOption(self: Command, option: Opt): Command
  self:_registerOption(option)

  local oname = option:name()
  local name = option:attributeName()

  if option.defaultValue ~= nil then
    self:setOptionValue(name, option.defaultValue)
  end

  local function handleOptionValue(val: any, invalidValueMessage: string)
    local oldValue = self:getOptionValue(name)
    if val ~= nil and option.parseArg then
      val = self:_callParseArg(option, val, oldValue, invalidValueMessage)
    end
    if val == nil then
      if option:isFlag() then
        val = true
      else
        val = ""
      end
    end

    self:setOptionValue(name, val)
  end

  self:on("option:" .. oname, function(val)
    local invalidValueMessage = `error: option '{option.flags}' argument '{val}' is invalid.`
    handleOptionValue(val, invalidValueMessage)
  end)

  return self
end

function Command.prototype.option(self: Command, flags: string, description: string?, defaultValue: any?): Command
  local option = self:createOption(flags, description)

  if defaultValue then
    option:default(defaultValue)
  end

  return self:addOption(option)
end

function Command.prototype.combineFlagAndOptionalValue(self: Command, combine: boolean?): Command
  local actualCombine: boolean = combine == nil and true or combine :: boolean
  self._combineFlagAndOptionalValue = not not actualCombine
  return self
end

function Command.prototype.getOptionValue(self: Command, key: string): any
  return self._optionValues[key]
end

function Command.prototype.setOptionValue(self: Command, key: string, value: any): Command
  self._optionValues[key] = value

  return self
end

function Command.prototype._prepareUserArgs(self: Command, argv: { string }?): { string }
  if argv == nil then
    argv = table.clone(process.args)
  end

  local userArgs = Table.slice(argv :: { string }, 1)

  self._name = self._name or "program"

  return userArgs
end

function Command.prototype.parse(self: Command, argv: { string }?)
  local userArgs = self:_prepareUserArgs(argv)
  return self:_parseCommand({}, userArgs)
end

function Command.prototype._dispatchSubcommand(self: Command, commandName: string, operands: any, unknown: any): any?
  local subcommand = self:_findCommand(commandName)
  if not subcommand then
    self:help()
  end

  local promiseChain = self:_chainOrCall(function()
    return (subcommand :: Command):_parseCommand(operands, unknown)
  end)

  return promiseChain
end

function Command.prototype._dispatchHelpCommand(self: Command, subcommandName: string?): ()
  if not subcommandName then
    self:help()
  end
  local subCommand = self:_findCommand(subcommandName :: string)
  if subCommand then
    subCommand:help()
  end

  return self:_dispatchSubcommand(
    subcommandName :: string,
    {},
    self:_getHelpOption().long and self:_getHelpOption().short or "--help"
  )
end

function Command.prototype._checkNumberOfArguments(self: Command): ()
  for i, arg in self.registeredArguments do
    if arg.required and self.args[i] == nil then
      self:missingArgument(arg:name())
    end
  end

  if #self.registeredArguments > 0 and self.registeredArguments[#self.registeredArguments].variadic then
    return
  end

  if #self.args > #self.registeredArguments then
    self:_excessArguments(self.args)
  end
end

function Command.prototype._processArguments(self: Command): ()
  local function myParseArg(argument: Arg, value: string?, previous: any)
    local parsedValue = value
    if value ~= nil and argument.parseArg then
      local invalidValueMessage =
        `error: command-argument value '${value}' is invalid for argument '${argument:name()}'.`
      parsedValue = self:_callParseArg(argument, value, previous, invalidValueMessage)
    end

    return parsedValue
  end
  self:_checkNumberOfArguments()
  local processedArgs: { string } = {}
  for index, declaredArg in self.registeredArguments do
    local value = declaredArg.defaultValue :: any
    if declaredArg.variadic then
      if index <= #self.args then
        value = Table.slice(self.args, index) :: any
        if declaredArg.parseArg then
          value = Table.reduce(value :: any, function(processed, v)
            return myParseArg(declaredArg, v, processed)
          end)
        end
      elseif value == nil then
        value = {}
      end
    elseif index <= #self.args then
      value = self.args[index]
      if declaredArg.parseArg then
        value = myParseArg(declaredArg, value, declaredArg.defaultValue)
      end
    end
    processedArgs[index] = value
  end

  self.processedArgs = processedArgs
end

function Command.prototype._chainOrCall(_: Command, fn: () -> ()): any?
  return fn()
end

function Command.prototype._parseCommand(self: Command, operands: any, unknown: any): ()
  local parsed = self:parseOptions(unknown)
  operands = Table.concat(operands, parsed.operands)
  unknown = parsed.unknown
  self.args = Table.concat(operands, unknown)

  if operands and self:_findCommand(operands[1]) then
    return self:_dispatchSubcommand(operands[1], Table.slice(operands, 2), unknown)
  end

  if self:_getHelpCommand() then
    local helpCommand: Command = self:_getHelpCommand() :: Command
    if operands[1] == helpCommand._name then
      return self:_dispatchHelpCommand(operands[2])
    end
  end

  if #self.commands > 0 and #self.args == 0 and not self._actionHandler then
    self:help()
  end

  self:_outputHelpIfRequested(parsed.unknown)
  self:_checkForMissingMandatoryOptions()

  local function checkForUnknownOptions()
    if #parsed.unknown > 0 then
      self:unknownOption(parsed.unknown[1])
    end
  end

  local commandEvent = `command:{self._name}`

  if self._actionHandler then
    checkForUnknownOptions()
    self:_processArguments()

    local promiseChain = self:_chainOrCall(function()
      self._actionHandler(self.processedArgs)
    end)

    if self.parent then
      promiseChain = self:_chainOrCall(function()
        self.parent:emit(commandEvent, operands, unknown)
      end)
      return promiseChain
    end
  end

  if #operands > 0 then
    if #self.commands > 0 then
      self:unknownCommand()
    end
  end
end

function Command.prototype._findCommand(self: Command, name: string): Command?
  if not name then
    return
  end

  return Table.find(self.commands, function(cmd)
    return cmd._name == name or table.find(cmd._aliases, name) ~= nil
  end)
end

function Command.prototype._findOption(self: Command, arg: string): Opt?
  return Table.find(self.options, function(option)
    return option:is(arg)
  end)
end

function Command.prototype._checkForMissingMandatoryOptions(self: Command): Opt?
  for _, cmd in self:_getCommandAndAncestors() :: { Command } do
    for _, anOption in cmd.options do
      if anOption.mandatory and (cmd :: Command):getOptionValue(anOption:attributeName()) == nil then
        self:missingMandatoryOptionValue(anOption)
      end
    end
  end
  return
end

function Command.prototype.parseOptions(self: Command, argv: { string }): { operands: { string }, unknown: { string } }
  local operands = {}
  local unknown = {}
  local dest = operands
  local args = Table.slice(argv, 1)

  local function maybeOption(arg: string)
    return #arg > 1 and string.sub(arg, 1, 1) == "-"
  end

  while #args > 0 do
    local arg = table.remove(args, 1) :: string
    if arg == "--" then
      if dest == unknown then
        table.insert(dest, arg)
      end
      Table.push(dest, Table.spread(args))
      break
    end

    if maybeOption(arg) then
      local option = self:_findOption(arg)
      if option then
        if option.required then
          local value = table.remove(args, 1)
          if value == nil then
            self:optionMissingArgument(option)
          end
          self:emit(`option:{option:name()}`, value)
        elseif option.optional then
          local value = nil
          if #args > 0 and not maybeOption(args[1]) then
            value = table.remove(args, 1)
          end
          self:emit(`option:{option:name()}`, value)
        else
          self:emit(`option:{option:name()}`)
        end
        continue
      end
    end

    if #arg > 2 and string.sub(arg, 1, 1) == "-" and string.sub(arg, 2, 2) ~= "-" then
      local option = self:_findOption(`-{string.sub(arg, 2, 2)}`)
      if option then
        if option.required or (option.optional and self._combineFlagAndOptionalValue) then
          self:emit(`option:{option:name()}`, String.slice(arg, 3))
        else
          self:emit(`option:{option:name()}`)
          table.insert(args, 1, "-" .. arg:sub(3))
          -- Table.unshift(args, `-{String.slice(arg, 3)}`)
        end
        continue
      end
    end

    if string.find(arg, "^--[^=]+=") then
      local index = String.indexOf(arg, "=")
      local option = self:_findOption(String.slice(arg, 1, index))
      if option and (option.required or option.optional) then
        self:emit(`option:{option:name()}`, String.slice(arg, index + 1))
        continue
      end
    end

    if maybeOption(arg) then
      dest = unknown
    end

    table.insert(dest, arg)
  end

  return { operands = operands, unknown = unknown }
end

function Command.prototype.opts(self: Command): { [string]: any }
  return self._optionValues
end

function Command.prototype.error(self: Command, message: string, exitCode: number): ()
  self._outputConfiguration.outputError(`{message}\n`, self._outputConfiguration.writeErr)

  if self._showHelpAfterError then
    self._outputConfiguration.writeErr("\n")
    self:outputHelp()
  end

  process.exit(exitCode)
end

function Command.prototype.missingArgument(self: Command, name: string): ()
  local message = `error: missing required argument '{name}'`
  self:error(message, 0)
end

function Command.prototype.optionMissingArgument(self: Command, option: Opt): ()
  local message = `error: option '{option.flags}' argument missing`
  self:error(message, 0)
end

function Command.prototype.missingMandatoryOptionValue(self: Command, option: Opt): ()
  local message = `error: required option '{option.flags}' not specified`

  self:error(message, 0)
end

function Command.prototype.unknownOption(self: Command, flag: string): ()
  local message = `error: unknown option '{flag}'`

  self:error(message, 0)
end

function Command.prototype._excessArguments(self: Command, receivedArgs: { string }): ()
  local expected = #self.registeredArguments
  local s = expected == 1 and "" or "s"
  local forSubcommand = self.parent and ` for '{self._name}'` or ""
  local message = `error: too many arguments{forSubcommand}. Expected {expected} argument{s} but got {#receivedArgs}.`
  self:error(message, 0)
end

function Command.prototype.unknownCommand(self: Command): ()
  local unknownName = self.args[1]

  local suggestion = ""

  if self._showSuggestionAfterError then
    local candidateNames = {}
    local commands = Helper.visibleCommands(self)
    for _, command in commands do
      table.insert(candidateNames, command._name)

      if command._aliases[1] then
        table.insert(candidateNames, command._aliases[1])
      end
    end

    suggestion = util.suggestSimilar(unknownName, candidateNames)
  end

  local message = `error: unknown command '{unknownName}'{suggestion}`
  self:error(message, 0)
end

function Command.prototype.version(self: Command, str: string?, flags: string?, description: string?): Command
  self._version = str or self._version
  flags = flags or "-V, --version"
  description = description or "output the version number"
  local versionOption = self:createOption(flags :: string, description :: string)
  versionOption:hide(true)
  self:_registerOption(versionOption)

  self:on("option:version", function()
    print(self._version)
  end)

  return self
end

function Command.prototype.description(self: Command, description: string): Command
  self._description = description

  return self
end

function Command.prototype.summary(self: Command, summary: string): Command
  self._summary = summary

  return self
end

function Command.prototype.alias(self: Command, alias: string): Command
  local command = self

  if alias == command._name then
    Error.new("Command alias can't be the same as its name"):throw()
  end
  if self.parent then
    local matchingCommand = self.parent:_findCommand(alias)
    if matchingCommand then
      local existingCommand = table.concat(Table.concat({ matchingCommand._name }, matchingCommand._aliases), "|")
      Error.new(`cannot add alias '{alias}' to command '{self._name}' as already have command '{existingCommand}'`)
        :throw()
    end
  end

  table.insert(self._aliases, alias)

  return self
end

function Command.prototype.aliases(self: Command, aliases: { string }): Command
  for _, alias in aliases do
    self:alias(alias)
  end
  return self
end

function Command.prototype.usage(self: Command): string
  local args = Table.map(self.registeredArguments, function(arg)
    return util.humanReadableArgName(arg)
  end)

  local fixedTable = Table.concat(
    {},
    #self.commands > 0 and "[command]" or {},
    #self.registeredArguments > 0 and args or {},
    #self.options > 0 and "[options]" or {}
  )

  return table.concat(fixedTable, " ")
end

function Command.prototype.name(self: Command, name: string): Command
  self._name = name

  return self
end

function Command.prototype.helpInformation(self: Command): string
  return Helper.formatHelp(self)
end

function Command.prototype.help(self: Command): ()
  self:outputHelp()
  process.exit(0)
end

function Command.prototype.outputHelp(self: Command): ()
  local helpInformation = self:helpInformation()
  print(helpInformation)
end

function Command.prototype._outputHelpIfRequested(self: Command, args: { string }): ()
  local helpOption = self:_getHelpOption()
  local helpRequested = helpOption ~= nil
      and Table.find(args, function(arg)
        return helpOption:is(arg)
      end) ~= nil
    or false
  if helpRequested then
    self:outputHelp()
    process.exit(0)
  end
end

function Command.prototype.helpOption(self: Command, flags: (string | boolean)?, description: string?): Command
  if typeof(flags) == "boolean" then
    if flags == true then
      self._helpOption = self._helpOption or nil
    else
      self._helpOption = nil
    end
  end
  local actualFlags = (flags :: string) or "-h, --help"
  local actualDescription = description or "display help for command"

  local helpopt = self:createOption(actualFlags, actualDescription)
  helpopt:hide(true)
  self._helpOption = helpopt
  self:_registerOption(helpopt)

  return self
end

function Command.prototype._getHelpOption(self: Command): Opt
  if self._helpOption == nil then
    self:helpOption(nil, nil)
  end

  return self._helpOption :: Opt
end

return Command.interface
