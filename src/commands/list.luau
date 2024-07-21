local output = require("../libs/output")
local package_helper = require("../libs/package_helper")
local repr = require("../libs/repr")

local Commander = require("../dependencies/commander")

local Command = Commander.Command

return Command.new("list")
  :description("List packages")
  :aliases({ "ls" })
  :option("-a, --all", "List all dependencies")
  :option("-j, --json", "JSON format")
  :action(function(opts)
    local packages = opts.all and package_helper.get_all_dependencies() or package_helper.get_root_dependencies()
    if not opts.json then
      package_helper.print_all_dependencies(packages)
    else
      output.write(repr(packages))
    end
  end)
