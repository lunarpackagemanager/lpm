local std = require("@pkg/std")
local stdio = require("@lune/stdio")
local t = require("../types")

local path = std.path
local process = std.process
local os = std.os

local function getName()
  return path.basename(process.cwd())
end

return function(yes: boolean?): t.PackageManifest
  local exports: t.PackageManifest = {} :: t.PackageManifest

  local name = getName()
  exports.name = yes and name or stdio.prompt("text", "Package Name", name)
  exports.version = yes and "0.1.0" or stdio.prompt("text", "Package Version", "0.1.0")
  exports.main = "./src/init.luau"
  exports.owner = yes and "" or os.userInfo().username
  exports.files = { "*" }
  exports.dependencies = {}
  exports.dev_dependencies = {}
  exports.keywords = yes and {}
    or stdio.prompt("text", "Package Keywords (seperated by ';')"):split(";")
  exports.description = yes and "" or stdio.prompt("text", "Package Description", "")
  exports.repository = yes and "" or stdio.prompt("text", "Package Repository", "")

  return exports
end
