local output = require("../libs/output")
local readManifest = require("../pkg_manifest/read_package_manifest")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process

return function(identifier: string)
  assert(fs.isDir(`{process.cwd()}/lune_modules`), "lune_modules not found")
  local read_ok, manifest, commit = readManifest(true)
  assert(read_ok and manifest and commit, "Package manifest not found")

  local is_dev_dep = manifest.dev_dependencies[identifier]
  local is_dep = manifest.dependencies[identifier]
  local is_exist = is_dev_dep ~= nil or is_dep ~= nil

  if is_exist then
    if fs.isDir(`{process.cwd()}/lune_modules/{identifier}`) then
      if is_dev_dep ~= nil then
        manifest.dev_dependencies[identifier] = nil
      else
        manifest.dependencies[identifier] = nil
      end
      fs.removeDir(`{process.cwd()}/lune_modules/{identifier}`)
    end
    if is_dev_dep ~= nil then
      manifest.dev_dependencies[identifier] = nil
    else
      manifest.dependencies[identifier] = nil
    end
  end

  output.write(`Uninstalling {identifier}`)
  commit()
end
