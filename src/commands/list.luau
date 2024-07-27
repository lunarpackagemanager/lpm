local package_helper = require("../libs/package_helper")

local Commander = require("../dependencies/commander")

local Command = Commander.Command

return Command.new("list")
  :description("List packages")
  :aliases({ "ls" })
  :option("-d, --depth [amount]", "Depth")
  :option("-a, --all", "List all dependencies")
  :option("-j, --json", "JSON format")
  :action(function(opts)
    local depth: number = if opts.all then math.huge elseif opts.depth then tonumber(opts.depth) :: number else 1

    package_helper.print_package_info(depth, opts.json)
  end)
