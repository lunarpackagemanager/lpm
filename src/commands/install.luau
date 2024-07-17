local Command = require("@deps/commander").Command

local manifest_helper = require("../libs/manifest_helper")
local package_helper = require("../libs/package_helper")

local command = Command.new("install")
  :description("Install a package")
  :aliases({ "add" })
  :argument("[package-spec...]", "Package specification")
  :option("-D, --dev", "Install to devDependencies")
  :action(function(packages, opts)
    if #packages > 0 then
      local _, data = manifest_helper.read()
      for _, package in packages do
        local packageData = string.split(package, "@")
        local packageName, packageVersion = packageData[1], packageData[2] or "latest"

        package_helper.install_package(package, {
          add_dependency = opts.dev and "dev" or true,
        })
      end
    end
  end)

return command
