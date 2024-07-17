--[[
    Bundled with Luau Package Manager v0.1.0 (https://github.com/lune-package/LPM) in 10.549ms

    Index:
    - line 24 = ./deps/commander/builtin/util.luau
    - line 160 = ./deps/commander/command.luau
    - line 958 = ./deps/table.luau
    - line 1266 = ./deps/commander/builtin/class.luau
    - line 1488 = ./deps/commander/init.luau
    - line 1515 = ./deps/commander/arg.luau
    - line 1589 = ./deps/commander/builtin/error.luau
    - line 1685 = ./deps/string.luau
    - line 1871 = ./deps/commander/builtin/event.luau
    - line 2032 = ./deps/commander/helper.luau
    - line 2302 = ./deps/commander/opt.luau
    - line 2451 = ./deps/std/process.luau
    - line 2485 = ./deps/commander/types.luau
    - line 2666 = [ENTRYPOINT] ./src/init.luau
]]

local __LPM_REQUIRE_CACHE = {};
local __LPM_MODULES = {};

local function __LPM_REQUIRE(hash: string): any
    if not __LPM_REQUIRE_CACHE[hash] then
        __LPM_REQUIRE_CACHE[hash] = __LPM_MODULES[hash]();
    end

    return __LPM_REQUIRE_CACHE[hash];
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/builtin/util.luau                                                       --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["041f3684ac4d345c4a7cb24ecf34491e"] = function()

-- v Original File Start v --
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")

local function assertEq(l: any, r: any, msg: string?)
  assert(l == r, msg or `[__CLAP] expected {l} == {r}`)
end

local function assertHandler(tbl: any)
  -- FIXME: Need to type sub as Opt | Command, without circular requires
  -- or separating types into its own module
  for _, sub in tbl do
    if not sub.isParent then
      assertEq(typeof(sub.handler), "function", `[__CLAP] field \`handler\` is mandatory for \`{sub.name}\``)
    end
  end
end

local function humanReadableArgName(arg: types.Arg): string
  local nameOutput = arg:name() .. (arg.variadic == true and "..." or "")
  return arg.required and "<" .. nameOutput .. ">" or "[" .. nameOutput .. "]"
end

local function compareTwoStrings(first: string, second: string): number
  first = string.gsub(first, "%s+", "")
  second = string.gsub(second, "%s+", "")

  if first == second then
    return 1
  end -- identical or empty
  if #first < 2 or #second < 2 then
    return 0
  end -- if either is a 0-letter or 1-letter string

  local firstBigrams = {}
  for i = 1, #first - 1 do
    local bigram = first:sub(i, i + 1)
    firstBigrams[bigram] = (firstBigrams[bigram] or 0) + 1
  end

  local intersectionSize = 0
  for i = 1, #second - 1 do
    local bigram = second:sub(i, i + 1)
    if firstBigrams[bigram] and firstBigrams[bigram] > 0 then
      firstBigrams[bigram] = firstBigrams[bigram] - 1
      intersectionSize = intersectionSize + 1
    end
  end

  return (2.0 * intersectionSize) / (#first + #second - 2)
end

local function areArgsValid(mainString, targetStrings)
  if type(mainString) ~= "string" then
    return false
  end
  if type(targetStrings) ~= "table" then
    return false
  end
  if #targetStrings == 0 then
    return false
  end
  for _, s in targetStrings do
    if type(s) ~= "string" then
      return false
    end
  end
  return true
end

local function findBestMatch(mainString: string, targetStrings: { string })
  if not areArgsValid(mainString, targetStrings) then
    error("Bad arguments: First argument should be a string, second should be an array of strings")
  end

  local ratings = {}
  local bestMatchIndex = 1

  for i, currentTargetString in targetStrings do
    local currentRating = compareTwoStrings(mainString, currentTargetString)
    table.insert(ratings, { target = currentTargetString, rating = currentRating })
    if currentRating > ratings[bestMatchIndex].rating then
      bestMatchIndex = i
    end
  end

  local bestMatch = ratings[bestMatchIndex]

  return { ratings = ratings, bestMatch = bestMatch, bestMatchIndex = bestMatchIndex }
end

local function suggestSimilar(word: string, candidates: { string }): string
  if not candidates or #candidates == 0 then
    return ""
  end

  local minDistance = 0.5
  local bestMatches = findBestMatch(word, candidates)
  local ratings = bestMatches.ratings

  local results = {}

  for _, rating in ratings do
    if rating.rating >= minDistance then
      table.insert(results, rating.target)
    end
  end

  if #results > 1 then
    return "\n(Did you mean one of " .. table.concat(results, ", ") .. "?)"
  end
  if #results == 1 then
    return "\n(Did you mean " .. results[1] .. "?)"
  end

  return ""
end

return table.freeze({
  assertEq = assertEq,
  assertHandler = assertHandler,
  humanReadableArgName = humanReadableArgName,
  compareTwoStrings = compareTwoStrings,
  findBestMatch = findBestMatch,
  suggestSimilar = suggestSimilar,
})

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/command.luau                                                            --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["064058fd1d87789a9949d5f0150c2725"] = function()

-- v Original File Start v --
local Arg = __LPM_REQUIRE("cf481a64cb1cb37c39fe02423fc73a87")
local Error = __LPM_REQUIRE("2d715f1408e67d6ffd3ac17fae9be70d")
local Helper = __LPM_REQUIRE("bd99292be7c09ab417f9753e5e23ffbc")
local Opt = __LPM_REQUIRE("27ec70801173dc0659cf8bdff95468bd")
local class = __LPM_REQUIRE("7caa72b6ba2e1bc92bda14bf7cb12ff4")
local eventEmitter = __LPM_REQUIRE("6358b777888b4e3458ac19af70415b7a")
local process = __LPM_REQUIRE("80da61a8e81179ed5127123b14633cef")
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")

local String = __LPM_REQUIRE("d5b32ce7138b17987b2b3e540a96f4df")
local Table = __LPM_REQUIRE("fa06fc2e36caff0ad0cb2f1367682670")
local util = __LPM_REQUIRE("041f3684ac4d345c4a7cb24ecf34491e")

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

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/table.luau                                                                        --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["fa06fc2e36caff0ad0cb2f1367682670"] = function()

-- v Original File Start v --
local Table = {}

export type Table<T> = { T }
export type Object<K, V> = { [K]: V }
type callbackFn<T> = (value: T, index: number, array: Table<T>) -> boolean
type reduceFn<T, U> = (previousValue: U, currentValue: T, currentIndex: number, array: Table<T>) -> U
type predicateFunction<K, V> = (value: V, index: K, array: Object<K, V>) -> boolean
type mapCallbackFn<T, U> = (value: T, index: number, Table<T>) -> U

function Table.isArray<T>(t: T)
  if typeof(t) ~= "table" then
    return false
  end

  for key in t :: any do
    if typeof(key) ~= "number" then
      return false
    end
  end

  return true
end

function Table.find<K, V>(t: Object<K, V>, predicate: predicateFunction<K, V>, start: number?): V?
  if typeof(t) ~= "table" then
    error(string.format("Table.spread called on non-table %s", typeof(t)))
  end
  if start then
    if not Table.isArray(t) then
      error(string.format("Table.spread called on non-array %s", "object"))
    end
    local length = #t
    for i = start, length do
      local value = t[i :: any]
      if predicate(value, i :: any, t) then
        return value
      end
    end
  else
    for index, value in t do
      if predicate(value, index, t) then
        return value
      end
    end
  end

  return nil
end

function Table.spread<T>(array: Table<T>, i: number?, j: number?): ...T
  if not Table.isArray(array) then
    error(string.format("Table.spread called on non-array %s", typeof(array)))
  end
  local startIndex = i or 1
  local endIndex = j or #array
  if startIndex > endIndex then
    return -- Return nothing if start index exceeds end index
  end

  local results = {}
  local count = 0
  for i = startIndex, endIndex do
    count += 1
    results[count] = array[i]
  end

  local function spread_helper(t, i)
    if i > count then
      return
    else
      return t[i], spread_helper(t, i + 1)
    end
  end

  return spread_helper(results, 1)
end

function Table.reverse(t: Table<any>): Table<any>
  local n = #t
  local i = 1
  while i < n do
    t[i], t[n] = t[n], t[i]
    i = i + 1
    n = n - 1
  end
  return t
end

function Table.reduce<T, U>(array: Table<T>, callback: reduceFn<T, U>, initialValue: U?): U
  if not Table.isArray(array) then
    error(string.format("Table.reduce called on non-table %s", typeof(array)))
  end
  if typeof(callback) ~= "function" then
    error("callback is not a function")
  end

  local length = #array

  local value: T | U
  local initial = 1

  if initialValue ~= nil then
    value = initialValue
  else
    initial = 2
    if length == 0 then
      error("reduce of empty array with no initial value")
    end
    value = array[1]
  end

  for i = initial, length do
    value = callback(value :: U, array[i], i, array)
  end

  return value :: U
end

function Table.filter<T, U>(array: Table<T>, callback: callbackFn<T>): Table<T>
  if typeof(array) ~= "table" then
    error(string.format("Array.filter called on %s", typeof(array)))
  end

  if typeof(callback) ~= "function" then
    error("callback is not a function")
  end

  local result: Table<T> = {}

  for i, element in array do
    if callback(element, i, array) then
      table.insert(result, element)
    end
  end

  return result
end

function Table.map<T, U, V>(array: Table<T>, callback: mapCallbackFn<T, U>): Table<U>
  if not Table.isArray(array) then
    error(string.format("Array.map called on non-array %s", typeof(array)))
  end
  if typeof(callback) ~= "function" then
    error("callback is not a function")
  end

  local new = {}

  for i, value in array do
    local mappedValue: U = callback(value, i, array)

    if mappedValue ~= nil then
      table.insert(new, mappedValue)
    end
  end

  return new
end

function Table.copy<K, V>(t: Object<K, V>, deep: boolean?): Object<K, V>
  if not deep then
    return table.clone(t)
  end
  local clone = table.clone(t)
  for index, value in clone do
    if typeof(value) == "table" then
      clone[index] = Table.copy(value, deep) :: any
    end
  end
  return clone
end

function Table.concat<T, S>(source: Table<T> | T, ...: Table<S> | S): Table<T> & Table<S>
  local array
  local elementCount = 0

  if Table.isArray(source) then
    array = table.clone(source :: Table<T>)
    elementCount = #(source :: Table<T>)
  else
    elementCount += 1
    array = {}
    array[elementCount] = source :: T
  end

  for i = 1, select("#", ...) do
    local value = select(i, ...)
    local valueType = typeof(value)
    if value ~= nil then
      if valueType == "table" then
        for k = 1, #value do
          elementCount += 1
          array[elementCount] = value[k]
        end
      else
        elementCount += 1
        array[elementCount] = value
      end
    end
  end

  return (array :: any) :: Table<T> & Table<S>
end

function Table.reconcile<S, T>(src: S, template: T): S & T
  assert(type(src) == "table", "First argument must be a table")
  assert(type(template) == "table", "Second argument must be a table")

  local tbl = table.clone(src)

  for key, value in template :: Object<any, any> do
    if tbl[key] == nil then
      if typeof(value) == "table" then
        tbl[key] = Table.copy(value :: any, true)
      else
        tbl[key] = value
      end
    elseif typeof((template :: {})[key]) == "table" then
      if typeof(value) == "table" then
        tbl[key] = Table.reconcile(value :: any, (template :: {})[key])
      else
        tbl[key] = Table.copy((template :: {})[key], true)
      end
    end
  end

  return (tbl :: any) :: S & T
end

function Table.shift<T>(value: Table<T>): T?
  if #value > 0 then
    return table.remove(value, 1)
  else
    return nil
  end
end

function Table.slice<T>(t: Table<T>, start_idx: number?, end_idx: number?): Table<T>
  if typeof(t) ~= "table" then
    error(string.format("Array.slice called on %s", typeof(t)))
  end
  local length = #t

  local start_idx_ = start_idx or 1
  local end_idx_
  if end_idx == nil or end_idx > length + 1 then
    end_idx_ = length + 1
  else
    end_idx_ = end_idx
  end

  if start_idx_ > length + 1 then
    return {}
  end

  local slice = {}

  if start_idx_ < 1 then
    start_idx_ = math.max(length - math.abs(start_idx_), 1)
  end
  if end_idx_ < 1 then
    end_idx_ = math.max(length - math.abs(end_idx_), 1)
  end

  local idx = start_idx_
  local i = 1
  while idx < end_idx_ do
    slice[i] = t[idx]
    idx = idx + 1
    i = i + 1
  end

  return slice
end

function Table.unshift<T>(array: Table<T>, ...: T): number
  local numberOfItems = select("#", ...)
  if numberOfItems > 0 then
    for i = numberOfItems, 1, -1 do
      local toInsert = select(i, ...)
      table.insert(array, 1, toInsert)
    end
  end

  return #array
end

function Table.push<T>(arr: Table<T>, ...: T)
  local varArgs = select("#", ...)
  for i = 1, varArgs do
    local arg = select(i, ...)
    table.insert(arr, arg)
  end
end

return Table

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/builtin/class.luau                                                      --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["7caa72b6ba2e1bc92bda14bf7cb12ff4"] = function()

-- v Original File Start v --
--!nocheck
--[[
	Construct utility method for centralising all hacky metatable stuff.

	Every 'Class' discord-luau uses should rely on this function to generate/instantiate that class object.
]]

local function failCall(self: any, callType: string)
  error(`Invoked unsupported metamethod '{callType}' on object '{tostring(self)}'`, 3)
end

local function size<T>(t: T)
  local count = 0
  for _ in t do
    count += 1
  end

  return count
end

local Class = {}

function Class.construct<S, P>(
  source: S,
  prototype: P
): S & P & {
  extend: <E>(self: S & P, other: E) -> S & P & E & { super: E },
}
  local object

  object = setmetatable({}, {
    __index = function(_, key)
      if key ~= "extend" then
        return prototype[key]
      end
    end,

    __call = function(self)
      return failCall(self, "Call")
    end,

    __concat = function(self)
      return failCall(self, "Concat")
    end,
    __iter = function(self)
      local keys = {}
      for key, _ in pairs(self) do
        if not (key:sub(1, 2) == "__" or key == "extend" or key == "super") then
          table.insert(keys, key)
        end
      end
      local i = 0
      return function()
        i = i + 1
        local key = keys[i]
        if key ~= nil then
          return key, self[key]
        end
      end
    end,

    __unm = function(self)
      return failCall(self, "-.")
    end,
    __add = function(self)
      return failCall(self, "+")
    end,
    __sub = function(self)
      return failCall(self, "-")
    end,
    __mul = function(self)
      return failCall(self, "*")
    end,
    __div = function(self)
      return failCall(self, "/")
    end,
    __idiv = function(self)
      return failCall(self, "//")
    end,
    __mod = function(self)
      return failCall(self, "%")
    end,
    __pow = function(self)
      return failCall(self, "^")
    end,
    __lt = function(self)
      return failCall(self, "<")
    end,
    __le = function(self)
      return failCall(self, "<=")
    end,
    __len = function(self)
      return failCall(self, "#")
    end,

    __mode = "",
    __type = prototype.__type or "GenericClass",

    -- __eq = ...
    -- __gc = ...

    __tostring = function()
      return `DiscordLuau<'{prototype.__type or "GenericClass"}'>`
    end,
  })

  object.extend = function<E>(self, otherPrototype: E): P & E & { super: E }
    self.super = otherPrototype
    return setmetatable({}, {
      __index = function(_, index)
        return self[index] or self.super[index]
      end,

      __newindex = function(t, index, value)
        if self.super[index] then
          self.super[index] = value
        else
          rawset(t, index, value)
        end
      end,

      __call = function(self)
        return failCall(self, "Call")
      end,
      __concat = function(self)
        return failCall(self, "Concat")
      end,
      __iter = function(self)
        local keys = {}
        for key, _ in pairs(self) do
          if not (key:sub(1, 2) == "__" or key == "extend" or key == "super") then
            table.insert(keys, key)
          end
        end
        local i = 0
        return function()
          i = i + 1
          local key = keys[i]
          if key ~= nil then
            return key, self[key]
          end
        end
      end,

      __unm = function(self)
        return failCall(self, "-.")
      end,
      __add = function(self)
        return failCall(self, "+")
      end,
      __sub = function(self)
        return failCall(self, "-")
      end,
      __mul = function(self)
        return failCall(self, "*")
      end,
      __div = function(self)
        return failCall(self, "/")
      end,
      __idiv = function(self)
        return failCall(self, "//")
      end,
      __mod = function(self)
        return failCall(self, "%")
      end,
      __pow = function(self)
        return failCall(self, "^")
      end,
      __lt = function(self)
        return failCall(self, "<")
      end,
      __le = function(self)
        return failCall(self, "<=")
      end,
      __len = function(self)
        return failCall(self, "#")
      end,

      __mode = "",
      __type = self.__type or "GenericClass",

      __tostring = function()
        local name = self["_name"] or self["name"] or self.__type
        return `Commander<'{name or "GenericClass"}'>`
      end,
    })
  end

  if size(source) > 0 then
    for key, value in source do
      object[key] = value
    end
  end

  return object
end

setmetatable(Class, {
  __call = function<P>(
    _,
    source: S,
    prototype: P
  ): S & P & {
    extend: <E>(self: S & P, other: E) -> S & P & E & { super: E },
  }
    return Class.construct(source, prototype)
  end,
})

return Class

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/init.luau                                                               --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["b952e07fc59305dc45439dac9b7d3d60"] = function()

-- v Original File Start v --
local Arg = __LPM_REQUIRE("cf481a64cb1cb37c39fe02423fc73a87")
local Command = __LPM_REQUIRE("064058fd1d87789a9949d5f0150c2725")
local Opt = __LPM_REQUIRE("27ec70801173dc0659cf8bdff95468bd")
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")

export type Command = types.Command
export type Option = types.Opt
export type Argument = types.Arg

return {
  Command = Command,
  Opt = Opt,
  Arg = Arg,
  program = Command.new(),
}

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/arg.luau                                                                --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["cf481a64cb1cb37c39fe02423fc73a87"] = function()

-- v Original File Start v --
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")

local String = __LPM_REQUIRE("d5b32ce7138b17987b2b3e540a96f4df")
local Table = __LPM_REQUIRE("fa06fc2e36caff0ad0cb2f1367682670")

type Arg = types.Arg

local Arg = {}

Arg.prototype = {}
Arg.interface = {}

Arg.prototype.__type = "Arg"

function Arg.interface.new(name: string, description: string?): Arg
  local argument = {
    variadic = false,
    description = description or "",
    defaultValue = nil,
    defaultValueDescription = nil,
    argChoices = nil,
    parseArg = nil,
  }

  local arg = (setmetatable(argument, {
    __index = Arg.prototype,
  }) :: any) :: Arg

  local firstChar = string.sub(name, 1, 1)

  if firstChar == "<" then
    arg.required = true
    arg._name = String.slice(name, 2, -1)
  elseif firstChar == "[" then
    arg.required = false
    arg._name = String.slice(name, 2, -1)
  end

  if #arg._name > 3 and String.slice(arg._name, -3) == "..." then
    arg.variadic = true
    arg._name = String.slice(arg._name, 1, -3)
  end

  return arg :: Arg
end

function Arg.prototype.name(self: Arg): string
  return self._name
end

function Arg.prototype.default(self: Arg, value: any, description: string?): Arg
  self.defaultValue = value
  self.defaultValueDescription = description
  return self
end

function Arg.prototype.argParser(self: Arg, fn: (value: string, previous: any) -> any): Arg
  self.parseArg = fn
  return self
end

return Arg.interface

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/builtin/error.luau                                                      --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["2d715f1408e67d6ffd3ac17fae9be70d"] = function()

-- v Original File Start v --
type Function = (...any) -> ...any

export type Error = { name: string, message: string, stack: string?, throw: (self: Error) -> never }
type Error_private = Error & { __stack: string? }

local Error = {}

local DEFAULT_NAME = "Error"
Error.__index = Error
Error.__tostring = function(self)
  return getmetatable(Error :: any).__tostring(self)
end

-- ROBLOX NOTE: extracted __createError function so that both Error.new() and Error() can capture the stack trace at the same depth
local function __createError(message: string?): Error
  local self = (setmetatable({
    name = DEFAULT_NAME,
    message = message or "",
  }, Error) :: any) :: Error
  Error.__captureStackTrace(self, 4)
  return self
end

function Error.new(message: string?): Error
  return __createError(message)
end

function Error.captureStackTrace(err: Error, options: Function?)
  Error.__captureStackTrace(err, 3, options)
end

function Error.__captureStackTrace(err_: Error, level: number, options: Function?)
  local err = err_ :: Error_private
  if typeof(options) == "function" then
    local stack = debug.traceback(nil, level)
    local functionName: string = debug.info(options, "n")
    local sourceFilePath: string = debug.info(options, "s")

    local espacedSourceFilePath = string.gsub(sourceFilePath, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    local stacktraceLinePattern = espacedSourceFilePath .. ":%d* function " .. functionName
    local beg = string.find(stack, stacktraceLinePattern)
    local end_ = nil
    if beg ~= nil then
      beg, end_ = string.find(stack, "\n", beg + 1)
    end
    if end_ ~= nil then
      stack = string.sub(stack, end_ + 1)
    end
    err.__stack = stack
  else
    err.__stack = debug.traceback(nil, level)
  end
  Error.__recalculateStacktrace(err)
end

function Error.__recalculateStacktrace(err_: Error)
  local err = err_ :: Error_private
  local message = err.message
  local name = err.name or DEFAULT_NAME

  local errName = name .. (if message ~= nil and message ~= "" then (": " .. message) else "")
  local stack = if err.__stack then err.__stack else ""

  err.stack = errName .. "\n" .. stack
end

function Error.throw(self: Error)
  error(self)
end

return setmetatable(Error, {
  __call = function(_, ...)
    return __createError(...)
  end,
  __tostring = function(self)
    if self.name ~= nil then
      if self.message and self.message ~= "" then
        return string.format("%s: %s", tostring(self.name), tostring(self.message))
      end
      return tostring(self.name)
    end
    return tostring(DEFAULT_NAME)
  end,
})

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/string.luau                                                                       --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["d5b32ce7138b17987b2b3e540a96f4df"] = function()

-- v Original File Start v --
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

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/builtin/event.luau                                                      --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["6358b777888b4e3458ac19af70415b7a"] = function()

-- v Original File Start v --
local class = __LPM_REQUIRE("7caa72b6ba2e1bc92bda14bf7cb12ff4")
local table = __LPM_REQUIRE("fa06fc2e36caff0ad0cb2f1367682670")
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")

type EventEmitter = types.EventEmitter
local EventEmitter = {
  defaultMaxListeners = 10,
}

EventEmitter.prototype = {}
EventEmitter.interface = {}

EventEmitter.prototype.__type = "EventEmitter"

function EventEmitter.prototype._ev(self: EventEmitter, type: string)
  if not self.connections[type] then
    self.connections[type] = {}
  end

  return self.connections[type]
end

function EventEmitter.prototype._getEv(self: EventEmitter, type: string)
  return self.connections[type]
end

function EventEmitter.prototype.addListener<T...>(self: EventEmitter, type: string, listener: (T...) -> ())
  local events
  local existing

  events = self.connections
  if events then
    existing = events[type]
  end

  if not existing then
    events[type] = { listener }
  else
    table.push(existing, listener)
  end

  return self
end

EventEmitter.prototype.on = EventEmitter.prototype.addListener

function EventEmitter.prototype.once<T...>(self: EventEmitter, type: string, listener: (T...) -> ())
  local done = false
  type = type .. ":once"
  local listenerOnce: (...any) -> ()
  listenerOnce = function(...)
    if done then
      return
    end
    done = true
    self:removeListener(type, listenerOnce)
    listener(...)
  end
  self:on(type, listenerOnce)
end

function EventEmitter.prototype.emit<T...>(self: EventEmitter, type: string, ...: T...)
  local evTbl = self:_getEv(type)
  if evTbl ~= nil then
    if next(evTbl) then
      for _, lsn in evTbl do
        local status = pcall(lsn, ...)
        if not status then
          print("emit error: ", type)
        end
      end
    end
  end

  type = type .. ":once"
  evTbl = self:_getEv(type)

  if evTbl ~= nil then
    if next(evTbl) then
      for _, lsn in evTbl do
        local status = pcall(lsn, ...)
        if not status then
          print("emit error: ", type)
        end
      end
    end
  end

  return self
end

function EventEmitter.prototype.removeListener<T...>(self: EventEmitter, type: string, listener: (T...) -> ()?)
  local events = self.connections
  local list = events[type]

  local position = 0
  for i = #list, 1, -1 do
    if list[i] == listener then
      position = i
      break
    end
  end

  if position < 1 then
    return self
  end

  if position == 1 then
    table.shift(list)
  else
    print()
  end

  if #list == 1 then
    events[type] = { list[1] }
  end

  if #list == 0 then
    events[type] = nil
  end

  return self
end

function EventEmitter.prototype.listenerCount(self: EventEmitter, type: string)
  local totalCount = 0
  local evTbl = self:_getEv(type)

  if evTbl ~= nil then
    totalCount += #evTbl
  end

  evTbl = self:_getEv(type .. ":once")
  if evTbl ~= nil then
    totalCount += #evTbl
  end

  return totalCount
end

function EventEmitter.interface.new(): EventEmitter
  local event = {
    connections = {},
  }

  return class(event, EventEmitter.prototype) :: EventEmitter
end

return EventEmitter.interface

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/helper.luau                                                             --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["bd99292be7c09ab417f9753e5e23ffbc"] = function()

-- v Original File Start v --
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")
local util = __LPM_REQUIRE("041f3684ac4d345c4a7cb24ecf34491e")

local String = __LPM_REQUIRE("d5b32ce7138b17987b2b3e540a96f4df")
local Table = __LPM_REQUIRE("fa06fc2e36caff0ad0cb2f1367682670")

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

  local function formatList(textArray: Table.Table<string>)
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

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/opt.luau                                                                --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["27ec70801173dc0659cf8bdff95468bd"] = function()

-- v Original File Start v --
local types = __LPM_REQUIRE("9945304816d716fca767ffd25ee6c097")

local String = __LPM_REQUIRE("d5b32ce7138b17987b2b3e540a96f4df")
local Table = __LPM_REQUIRE("fa06fc2e36caff0ad0cb2f1367682670")

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

  return Table.reduce(splittedString, function(str: string, word)
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
    optional = String.includes(flags, "%["),
    mandatory = false,
    defaultValue = nil,
    defaultValueDescription = nil,
    hidden = false,
    parseArg = nil,
  }

  local self = (
    setmetatable(option, {
      __index = Opt.prototype,
      __tostring = function(self: Opt)
        return String.format("Opt<>")
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

function Opt.prototype.hide(self: Opt, value: any, hide: boolean?): Opt
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

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/std/process.luau                                                                  --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["80da61a8e81179ed5127123b14633cef"] = function()

-- v Original File Start v --
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Process = {}
Process.stdout = {}
Process.stderr = {}

function Process.stdout.write(str: string): ()
  return stdio.write(str)
end

function Process.stderr.write(str: string): ()
  return stdio.ewrite(str)
end

export type process = typeof(setmetatable(Process, {
  __index = process,
}))

return setmetatable(Process, {
  __index = require("@lune/process"),
}) :: process

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: ./deps/commander/types.luau                                                              --
----------------------------------------------------------------------------------------------------

__LPM_MODULES["9945304816d716fca767ffd25ee6c097"] = function()

-- v Original File Start v --
export type ArgPrototype = {
  description: string,
  variadic: boolean,
  parseArg: ((value: string, previous: any) -> any)?,
  defaultValue: any?,
  defaultValueDescription: string?,
  required: boolean,
  _name: string,
}

export type ArgImpl = {
  name: (Arg) -> string,
  default: (Arg, any, string?) -> Arg,
  argParser: (Arg, (value: string, previous: any) -> any) -> Arg,
}

export type Arg = ArgPrototype & ArgImpl

export type OptType = "string" | "number" | "bool" | "any"
export type OptList = { [string]: (string | number | boolean)? }

export type OptPrototype = {
  flags: string,
  long: string?,
  short: string?,
  required: boolean,
  optional: boolean,
  description: string?,
  defaultValue: any?,
  defaultValueDescription: string?,
  hidden: boolean,
  mandatory: boolean,
  parseArg: ((string, any) -> any)?,
}

export type OptImpl = {
  default: (Opt, any, string?) -> Opt,
  hide: (Opt, boolean?) -> Opt,
  name: (Opt) -> string,
  attributeName: (Opt) -> string,
  is: (Opt, string) -> boolean,
  isFlag: (Opt) -> boolean,
  argParser: (Opt, (string, any) -> any) -> Opt,
  makeOptionMandatory: (Opt, boolean?) -> Opt,
}

export type Opt = OptPrototype & OptImpl

export type CommandPrototype = {
  _debug: boolean,
  commands: { Command },
  options: { Opt },
  parent: Command?,
  registeredArguments: { Arg },
  args: { string },
  processedArgs: { string },
  _name: string,
  _defaultCommandName: string?,
  _optionValues: { [string]: any },
  _optionValueSources: { [string]: any },
  _actionHandler: (...any) -> (),
  _aliases: { string },
  _combineFlagAndOptionalValue: boolean,
  _description: string,
  _summary: string,
  _showHelpAfterError: boolean,
  _showSuggestionAfterError: boolean,
  _hidden: boolean,
  _helpOption: Opt?,
  _helpCommand: Command?,
  _addImplicitHelpCommand: any?,
  _version: string,
  _outputConfiguration: {
    writeOut: (string) -> (),
    writeErr: (string) -> (),
    outputError: (string, (string) -> ()) -> (),
  },
}

export type CommandImpl = {
  --- PUBLIC
  copyInheritedSettings: (Command, Command) -> Command,
  _getCommandAndAncestors: (Command) -> { Command },
  command: (Command, string) -> Command,
  createCommand: (Command, string?) -> Command,
  showHelpAfterError: (Command, boolean?) -> Command,
  showSuggestionAfterError: (Command, boolean?) -> Command,
  addCommand: (Command, Command, { [string]: any }?) -> Command,
  createArgument: (Command, string, string?) -> Arg,
  argument: (Command, string, string?, any?) -> Command,
  arguments: (Command, string) -> Command,
  addArgument: (Command, Arg) -> Command,
  helpCommand: (Command, string?, string?) -> Command,
  action: (Command, (...any) -> ()) -> Command,
  createOption: (Command, string, string?) -> Opt,
  addOption: (Command, Opt) -> Command,
  combineFlagAndOptionalValue: (Command, boolean?) -> Command,
  getOptionValue: (Command, string) -> any,
  setOptionValue: (Command, string, any) -> Command,
  getOptionValue: (Command, string) -> any,
  option: (Command, flags: string, description: string?, defaultValue: any?) -> Command,
  parse: (Command, { string }?) -> Command,
  parseOptions: (Command, { string }) -> { operands: { string }, unknown: { string } },
  opts: (Command) -> { [string]: any },
  error: (Command, string, number) -> (),
  version: (Command, string?, string?, string?) -> Command,
  description: (Command, string) -> Command,
  summary: (Command, string) -> Command,
  alias: (Command, string) -> Command,
  aliases: (Command, { string }) -> Command,
  usage: (Command) -> string,
  name: (Command, string) -> Command,
  helpInformation: (Command) -> string,
  help: (Command) -> (),
  outputHelp: (Command) -> (),
  helpOption: (Command, (string | boolean)?, string?) -> Command,
  _getHelpOption: (Command) -> Opt,
  --- PRIVATE
  _getHelpCommand: (Command) -> Command?,
  _callParseArg: (Command, Opt | Arg, string, any, string) -> (),
  _registerOption: (Command, Opt) -> (),
  _registerCommand: (Command, Command) -> (),
  _optionEx: (Command, string, string?, any?) -> Command,
  _optionEx: (Command, string, string?, any?) -> Command,
  _prepareUserArgs: (Command, { string }?) -> { string },
  _dispatchSubcommand: (Command, string, any, any) -> (),
  _dispatchHelpCommand: (Command, string?) -> (),
  _checkNumberOfArguments: (Command) -> (),
  _processArguments: (Command) -> (),
  _chainOrCall: (Command, () -> ()) -> any?,
  _chainOrCallHooks: (Command, any?, string) -> any?,
  _chainOrCallSubCommandHook: (Command, any?, Command, string) -> any?,
  _parseCommand: (Command, any, any) -> (),
  _findCommand: (Command, string) -> Command?,
  _findOption: (Command, string) -> Opt?,
  _checkForMissingMandatoryOptions: (Command) -> Opt?,
  missingArgument: (Command, string) -> (),
  optionMissingArgument: (Command, Opt) -> (),
  missingMandatoryOptionValue: (Command, Opt) -> (),
  unknownOption: (Command, string) -> (),
  _excessArguments: (Command, { string }) -> (),
  unknownCommand: (Command) -> (),
  _outputHelpIfRequested: (Command, { string }) -> (),
}

export type Command = CommandPrototype & CommandImpl & EventEmitter

--[[
  Extra Types
]]

export type EventEmitterListener = (...any) -> ()

export type EventEmitterPrototype = { connections: { [string]: { EventEmitterListener } } }

export type EventEmitterImpl = {
  _ev: (EventEmitter, string) -> { EventEmitterListener },
  _getEv: (EventEmitter, string) -> { EventEmitterListener },
  addListener: <T...>(EventEmitter, string, (T...) -> ()) -> EventEmitter,
  on: <T...>(EventEmitter, string, (T...) -> ()) -> EventEmitter,
  once: <T...>(EventEmitter, string, (T...) -> ()) -> (),
  emit: <T...>(EventEmitter, string, T...) -> EventEmitter,
  removeListener: <T...>(EventEmitter, string, ((T...) -> ())?) -> EventEmitter,
  listenerCount: <T...>(EventEmitter, string) -> number,
}

export type EventEmitter = EventEmitterPrototype & EventEmitterImpl

return "<types>"

-- ^  Original File End  ^ --
end


----------------------------------------------------------------------------------------------------
-- File: [ENTRYPOINT] ./src/init.luau                                                             --
----------------------------------------------------------------------------------------------------

_G.LPM_OUTPUT_MODE = "CLI"
_G.VERSION = "0.1.0"
local fs = require("@lune/fs")
local process = __LPM_REQUIRE("80da61a8e81179ed5127123b14633cef")
local stdio = require("@lune/stdio")
local program = __LPM_REQUIRE("b952e07fc59305dc45439dac9b7d3d60").program

local function main()
  program:name("lpm"):version("0.1.0"):description("Luau Package Manager")

  for _, command in fs.readDir("./src/commands") do
    local commandPath = `@lpm/commands/{command}`
    local req = require :: any
    local commandInstance = req(commandPath)

    program:addCommand(commandInstance)
  end

  program:parse()

  process.exit(0)
end

main()
