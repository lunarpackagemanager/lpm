local constants = require("../constants")
local fs = require("@lune/fs")
local output = require("../libs/output")
local save = require("./save_package_manifest")
local serde = require("@lune/serde")
local t = require("../types")

return function(modifiable: boolean?, path: string?): (boolean, t.PackageManifest?, () -> ()?)
  local manifest_path = path or constants.manifest_path
  if not fs.isFile(manifest_path) then
    return false
  end

  local read_ok, raw_manifest = pcall(fs.readFile, manifest_path)
  output.assert(read_ok, "Failed to read package manifest", raw_manifest)

  local parse_ok, parsed_manifest = pcall(serde.decode, "toml" :: "toml", raw_manifest)
  output.assert(parse_ok, "Failed to parse package manifest", parsed_manifest)

  local function commit()
    save(parsed_manifest)
  end

  return true, setmetatable(parsed_manifest, constants.manifest_default), if modifiable then commit else nil
end
