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
