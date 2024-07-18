local config = require("./config")
local std = require("@pkg/std")
local fs = std.fs
local os = std.os

local GLOBAL_DIR = `{os.homedir()}/.{config.name.long:lower()}`

fs.ensureDirExists(GLOBAL_DIR)
fs.ensureDirExists(`{GLOBAL_DIR}/bin`)

local api = {}

api.commands = {
  ["install"] = require("./commands/install"),
  ["uninstall"] = require("./commands/uninstall"),
  ["init"] = require("./commands/init"),
  ["build"] = require("./commands/build"),
  ["run"] = require("./commands/run"),
}

return api
