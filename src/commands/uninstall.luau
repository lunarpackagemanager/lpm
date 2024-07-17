local process = require("@deps/std/process")
local stdio = require("@lune/stdio")
local sys = require("@deps/std/sys")
local Command = require("@deps/commander").Command
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local t = require("../types")

local manifest_helper = require("../libs/manifest_helper")
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
