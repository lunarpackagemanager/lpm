local Commander = require("../commander")

local checkRemote = require("../../fetching/check_git_remote")
local process = require("@lune/process")
local requireCleanWorkTree = require("../../libs/require_clean_work_tree")

local Command = Commander.Command

local command = Command.new("publish"):description("Publish package to git"):action(function()
  checkRemote()
  requireCleanWorkTree()

  return process.spawn("git", { "push" })
end)

return command
