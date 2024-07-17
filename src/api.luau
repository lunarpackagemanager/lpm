local sys = require("./libs/sys")

sys.ensure_dir_exists(sys.global_dir)
sys.ensure_dir_exists(`{sys.global_dir}/bin`)

local api = {}

api.commands = {
  ["install"] = require("./commands/install"),
  ["uninstall"] = require("./commands/uninstall"),
  ["init"] = require("./commands/init"),
  ["build"] = require("./commands/build"),
}

return api
