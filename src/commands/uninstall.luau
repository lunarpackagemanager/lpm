local Command = require("@deps/commander").Command

local package_helper = require("../libs/package_helper")

local command = Command.new("uninstall")
  :description("Uninstall a package")
  :aliases({ "remove" })
  :argument("[package-spec...]", "Package specification")
  :action(function(packages)
    if #packages > 0 then
      for _, package in packages do
        package_helper.uninstall_package(package)
      end
    end
  end)

return command
