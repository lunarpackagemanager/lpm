local polyfill = require("@pkg/polyfill")
local readManifest = require("../pkg_manifest/read_package_manifest")
local std = require("@pkg/std")
local t = require("../types")

local fs = std.fs
local Table = polyfill.Table

type Dependencies = t.Dependencies

local function get_dependency_info(path: string, dependencies: Dependencies, maxDepth: number, currentDepth: number)
  local read_ok, manifest = readManifest(false, path .. "/package.toml")
  assert(read_ok and manifest, "Package manifest not found")

  if dependencies[manifest.name] == nil then
    dependencies[manifest.name] = {
      version = manifest.version,
    }
  end

  if currentDepth <= maxDepth then
    if manifest.dependencies and Table.size(manifest.dependencies) > 0 then
      dependencies[manifest.name].dependencies = {}
      for dependencyName in manifest.dependencies do
        local package_path = `{path}/lune_modules/{dependencyName}`
        if fs.isFile(package_path .. "/package.toml") then
          get_dependency_info(package_path, dependencies[manifest.name].dependencies :: any, maxDepth, currentDepth + 1)
        end
      end
    end
  end
end

return get_dependency_info
