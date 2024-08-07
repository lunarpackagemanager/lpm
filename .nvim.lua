require("luau-lsp").config({
  server = {
    settings = {
      ["luau-lsp"] = {
        require = {
          mode = "relativeToFile",
          directoryAliases = {
            ["@lune"] = "~/.lune/.typedefs/0.8.6/",
            ["@pkg/"] = "./lune_modules/",
          },
        },
        completion = {
          imports = {
            enabled = true,
          },
        },
      },
    },
  },
  platform = {
    type = "standard",
  },
})
