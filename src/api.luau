local config = require("./config")
local std = require("@pkg/std")
local fs = std.fs
local os = std.os

local GLOBAL_DIR = `{os.homedir()}/.{config.name.long:lower()}`

fs.ensureDirExists(GLOBAL_DIR)
fs.ensureDirExists(`{GLOBAL_DIR}/bin`)

local api = {}

api.commands = {
  ["install"] = require("./cli/commands/install"),
  ["uninstall"] = require("./cli/commands/uninstall"),
  ["init"] = require("./cli/commands/init"),
  ["build"] = require("./cli/commands/build"),
  ["ls"] = require("./cli/commands/ls"),
  ["help"] = require("./cli/commands/help"),
  ["self-update"] = require("./cli/commands/self_update"),
}

return api
