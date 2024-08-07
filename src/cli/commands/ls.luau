local renderJson = require("../../reviewing/render_json")
local renderTree = require("../../reviewing/render_tree")

local Commander = require("../commander")
local getPackageInfo = require("../../reviewing/get_package_info")

local Command = Commander.Command

return Command.new("ls")
  :description("List installed packages")
  :aliases({ "list" })
  :option("-d, --depth [amount]", "The depth to go when recursing packages")
  :option("-a, --all", "List all dependencies")
  :option("-j, --json", "Output in JSON format")
  :action(function(opts)
    local depth: number = if opts.all
      then math.huge
      elseif opts.depth then tonumber(opts.depth) :: number
      else 1

    local package = getPackageInfo(depth)

    if opts.json then
      return renderJson(package)
    end

    return renderTree(package, { max_depth = depth })
  end)
