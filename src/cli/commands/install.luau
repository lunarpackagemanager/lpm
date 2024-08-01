local Commander = require("../commander")

local installPackage = require("../../pkg_manager/install_package")

local Command = Commander.Command

local command = Command.new("install")
  :description("Install a package")
  :aliases({ "add", "i" })
  :argument("[package-spec...]", "Package specification")
  :option("-D, --save-dev", "Package will apear in your devDependencies")
  :action(function(packages, opts)
    if #packages > 0 then
      for _, package in packages do
        installPackage(package, {
          add_dependency = opts.dev and "dev" or true,
        })
      end
    end
  end)

return command
