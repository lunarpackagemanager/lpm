local output = require("../libs/output")
local serde = require("@lune/serde")
local t = require("../types")

return function(package: t.Package)
  package.path = nil :: any
  output.write(serde.encode("json", package, true))
end
