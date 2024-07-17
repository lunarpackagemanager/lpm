local process = require("@deps/std/process")
local stdio = require("@lune/stdio")
local sys = require("@deps/std/sys")
local Command = require("@deps/commander").Command
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local t = require("../types")

local manifest_helper = require("../libs/manifest_helper")
local package_helper = require("../libs/package_helper")

local command = Command.new("init")
  :aliases({ "create", "innit" })
  :description("Create a package json5 file")
  :argument("[package-spec]", "Package specification", "")
  :option("-p, --prompt", "Prompt questionnaire")
  :action(function(packageSpec, opts)
    local questionnaire = {}
    if opts.prompt then
      questionnaire = {
        name = stdio.prompt("text", "Package Name", sys.cwd_name),
        version = stdio.prompt("text", "Package Version", "0.1.0"),
        main = stdio.prompt("text", "Package Entrypoint", "./src/init.luau"),
        owner = stdio.prompt("text", "Package Owner", sys.user_info().username),
        description = stdio.prompt("text", "Package Description"),
        keywords = stdio.prompt("text", "Package Keywords (seperated by ';')"):split(";"),
        repository = stdio.prompt("text", "Package Repository"),
      }
    end

    manifest_helper.save(manifest_helper.new(questionnaire))

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

    if packageSpec ~= "" then
      package_helper.install_package(packageSpec, {
        add_dependency = true,
        warn_on_already_installed = false,
      })
    end
  end)

return command
