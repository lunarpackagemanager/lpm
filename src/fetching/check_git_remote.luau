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

return function(): { ahead: number, behind: number }?
  if fs.isDir(".git") then
    git("remote", "update")
    local branch = git("rev-parse", "--abbrev-ref HEAD")

    if branch.ok then
      local branchName = branch.stdout:gsub("\n", "")
      local ahead = tonumber(git("rev-list", `--count origin/{branchName}..{branchName}`).stdout)
      local behind = tonumber(git("rev-list", `--count {branchName}..origin/{branchName}`).stdout)

      if ahead > 0 or behind > 0 then
        print(`{ahead} commits ahead, {behind} commits behind`)
        return process.exit(1)
      end
    end
  end

  return nil
end
