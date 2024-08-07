local constants = require("../constants")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process
local GLOBAL_DIR = constants.global_dir

local URL = "https://gitlab.com/lunarpackagemanager/docs.git"
local DOCS_PATH = `{GLOBAL_DIR}/docs`

return function(force: boolean?)
  if force then
    if fs.isDir(DOCS_PATH) then
      fs.removeDir(DOCS_PATH)
    end
    fs.ensureDirExists(DOCS_PATH)
    local fetchResult = process.spawn(
      "git",
      { "clone", "--depth", "1", URL, "--branch", "main", DOCS_PATH },
      { stdio = "forward" }
    )
    assert(fetchResult.ok, "Can't fetch docs")
    fs.removeDir(`{DOCS_PATH}/.git`)
  else
    if not fs.isDir(DOCS_PATH) then
      fs.writeDir(DOCS_PATH)
      local fetchResult = process.spawn(
        "git",
        { "clone", "--depth", "1", URL, "--branch", "main", DOCS_PATH },
        { stdio = "forward" }
      )
      assert(fetchResult.ok, "Can't fetch docs")
      fs.removeDir(`{DOCS_PATH}/.git`)
    end
  end
end
