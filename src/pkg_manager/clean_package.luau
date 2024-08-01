local output = require("../libs/output")
local readManifest = require("../pkg_manifest/read_package_manifest")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process

return function()
  assert(fs.isDir(`{process.cwd()}/lune_modules`), "lune_modules not found")
  local read_ok, manifest = readManifest()
  assert(read_ok and manifest, "Package manifest not found")

  for _, item in fs.readDir("lune_modules") do
    if not manifest.dependencies[item] then
      local itemPath = `lune_modules/{item}`
      fs.removeDir(itemPath)
      output.write(`Removed {item}`)
    end
  end
end
