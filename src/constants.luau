local config = require("./config")
local std = require("@pkg/std")
local process = std.process
local os = std.os

return {
  manifest_path = `{process.cwd()}/package.toml`,
  manifest_default = {
    owner = os.userInfo().username,
    files = { "*" },
    dependencies = {},
    description = "",
    keywords = {},
    repository = "",

    devDependencies = {},
    contributors = {},
    private = false,
    arch = {},
    os = {},
    runtimes = {},
    buildConfig = nil,
    documentation = "",
  },
  global_dir = `{os.homedir()}/.{config.name.long:lower()}`,
}
