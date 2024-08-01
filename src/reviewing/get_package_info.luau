local getDependencyInfo = require("./get_dependency_info")
local readManifest = require("../pkg_manifest/read_package_manifest")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process

return function(depth: number)
  local read_ok, manifest = readManifest()
  assert(read_ok and manifest, "Package manifest not found")
  local data = {
    name = manifest.name,
    version = manifest.version,
    dependencies = {},
    path = process.cwd(),
  }

  for dependencyName, _ in manifest.dependencies do
    local package_path = `lune_modules/{dependencyName}`
    if fs.isFile(package_path .. "/package.toml") then
      getDependencyInfo(package_path, data.dependencies, depth, 1)
    end
  end

  return data
end
