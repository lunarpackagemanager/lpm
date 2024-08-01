local Commander = require("../commander")
local serde = require("@lune/serde")
local std = require("@pkg/std")

local newPackage = require("../../pkg_manager/new_package")
local saveManifest = require("../../pkg_manifest/save_package_manifest")

local os = std.os
local fs = std.fs

local Command = Commander.Command

local command = Command.new("init")
  :aliases({ "create" })
  :description("Create a package.toml file")
  :option("-y, --yes", 'Automatically answer "yes" to any prompts that lpm might print on the command line.')
  :action(function(opts)
    saveManifest(newPackage(opts.yes))

    if not fs.isFile("./.gitignore") then
      fs.writeFile("./.gitignore", "")
    end

    local git_ignore = fs.readFile("./.gitignore")
    if string.find(git_ignore, "# LPM") == nil then
      fs.writeFile("./.gitignore", "# LPM\n\n/dist\n/lune_modules\n\n" .. git_ignore)
    end

    if not fs.isFile("./.luaurc") then
      fs.writeFile("./.luaurc", "{}")
    end

    local luaurc = serde.decode("json", fs.readFile("./.luaurc"))
    luaurc.aliases = luaurc.aliases or {}
    luaurc.aliases["pkg"] = `./lune_modules`
    fs.writeFile("./.luaurc", serde.encode("json", luaurc, true))
  end)

return command
