local Commander = require("../commander")

local requireCleanWorkTree = require("../../libs/require_clean_work_tree")

local Command = Commander.Command

local command = Command.new("publish"):description("Publish package to git"):action(function()
  requireCleanWorkTree()
end)

return command
