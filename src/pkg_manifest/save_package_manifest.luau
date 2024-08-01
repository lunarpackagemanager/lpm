local constants = require("../constants")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local t = require("../types")

type PackageManifest = t.PackageManifest

return function(manifest: PackageManifest, path: string?)
  local manifest_path = path or constants.manifest_path
  local serialised = serde.encode("toml", manifest, true)
  fs.writeFile(manifest_path, serialised)
end
