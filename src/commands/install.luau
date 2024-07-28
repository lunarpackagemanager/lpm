local Commander = require("../dependencies/commander")

local package_helper = require("../libs/package_helper")

local Command = Commander.Command

local command = Command.new("install")
  :description("Install a package")
  :aliases({ "add", "i" })
  :argument("[package-spec...]", "Package specification")
  :option("-D, --save-dev", "Package will apear in your devDependencies")
  :action(function(packages, opts)
    if #packages > 0 then
      for _, package in packages do
        package_helper.install_package(package, {
          add_dependency = opts.dev and "dev" or true,
        })
      end
    end
  end)

return command
