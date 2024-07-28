local package_helper = require("../libs/package_helper")

local Commander = require("../dependencies/commander")

local Command = Commander.Command

return Command.new("ls")
  :description("List installed packages")
  :aliases({ "list" })
  :option("-d, --depth [amount]", "The depth to go when recursing packages", 1)
  :option("-a, --all", "List all dependencies")
  :option("-j, --json", "Output in JSON format")
  :action(function(opts)
    local depth: number = if opts.all then math.huge else tonumber(opts.depth) :: number

    package_helper.print_package_info(depth, opts.json)
  end)
