local Commander = require("../commander")

local uninstallPackage = require("../../pkg_manager/uninstall_package")

local Command = Commander.Command

local command = Command.new("uninstall")
  :description("Uninstall a package")
  :aliases({ "remove" })
  :argument("[package-spec...]", "Package specification")
  :action(function(packages)
    if #packages > 0 then
      for _, package in packages do
        uninstallPackage(package)
      end
    end
  end)

return command
