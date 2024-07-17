local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Process = {}
Process.stdout = {}
Process.stderr = {}

function Process.stdout.write(str: string): ()
  return stdio.write(str)
end

function Process.stderr.write(str: string): ()
  return stdio.ewrite(str)
end

export type process = typeof(setmetatable(Process, {
  __index = process,
}))

return setmetatable(Process, {
  __index = require("@lune/process"),
}) :: process
