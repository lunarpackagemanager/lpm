local std = require("@pkg/std")

local fs = std.fs
local process = std.process

local function git(command: string, options: string)
  local args = { command }
  local opts = string.split(options, " ")
  for _, opt in opts do
    table.insert(args, opt)
  end
  return process.spawn("git", args)
end

return function(): ()
  if fs.isDir(`{process.cwd()}/.git`) then
    local rev_parse = git("rev-parse", "--verify HEAD")

    if not rev_parse.ok then
      process.exit(1)
    end
    git("update-index", "-q --ignore-submodules --refresh")
    local err = 0

    -- Disallow unstaged changes in the working tree
    if not git("diff-files", "--quiet --ignore-submodules").ok then
      print("Cannot publish: you have unstaged changes.")
      err = 1
    end

    if not git("diff-index", "--cached --quiet --ignore-submodules HEAD --").ok then
      if err == 0 then
        print("Cannot publish: Your index contains uncommited changes")
      else
        print("Additionally, your index contains uncommited changes.")
      end
      err = 1
    end

    if err == 1 then
      print("Please commit or stash them")
      process.exit(1)
    end
  end
end
