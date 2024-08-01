local Commander = require("../commander")
local fetchDocs = require("../../fetching/git_fetch_docs")

local Command = Commander.Command

local command = Command.new("self-update"):description("Update lpm"):action(function()
  fetchDocs(true)
end)

return command
