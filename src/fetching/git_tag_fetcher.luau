local serde = require("@lune/serde")
local std = require("@pkg/std")

local net = std.net

local GitTagFetcher = {}

function GitTagFetcher.get_latest_tag(package_name: string)
  local repo_url = `https://api.github.com/repos/lunar-package/{package_name}/tags`

  local res = net.fetch({ method = "GET", url = repo_url })
  local data = serde.decode("json", res.body)

  return data[1]
end

return GitTagFetcher
