local Commander = require("../commander")
local constants = require("../../constants")
local fetchDocs = require("../../fetching/git_fetch_docs")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process
local path = std.path

local os = process.os

local Command = Commander.Command

local manNumberPattern = "%.([^%.]*)$"

local function htmlMan(man: string)
  local command_name = path.basename(man):gsub(manNumberPattern, "")

  return "file:///" .. path.resolve(constants.global_dir, `docs/html/{command_name}.html`)
end

local function viewMan(man: string, force: boolean?)
  if os ~= "windows" and not force then
    return process.spawn(
      "man",
      { man },
      { stdio = _G.DEBUG and "inherit" :: "inherit" or "forward" :: "forward", shell = true }
    )
  else
    local url = htmlMan(man)
    if os == "windows" then
      return process.spawn("start", { url }, { stdio = "none" })
    else
      return process.spawn("sensible-browser", { url }, { stdio = "none" })
    end
  end
end

return Command.new("help")
  :description("Help command")
  :argument("<command>", "Command name")
  :option("-f, --force", "Open with browser (for unix)")
  :action(function(command, opts)
    fetchDocs()
    local pattern = `^{constants.global_dir}/docs/man/man%.[1-9]+/lpm%-{command}%.[1-9]$`
    if os == "windows" then
      pattern = pattern:gsub("/", "\\")
    end
    local man = path.resolve(constants.global_dir, `docs/man/man.1/lpm-{command}.1`)
    assert(man:match(pattern) ~= nil, "No documentation")

    if fs.isFile(man) then
      return viewMan(man, opts.force)
    end
  end)
