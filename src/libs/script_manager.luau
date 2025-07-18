--!nocheck
local polyfill = require("@pkg/polyfill")
local std = require("@pkg/std")

local manifest_helper = require("./manifest_helper")
local output = require("./output")

local Table = polyfill.Table

local fs = std.fs
local process = std.process
local path = std.path

local script_manager = {}

function script_manager.execute_file(file: string)
  local args = table.clone(process.args)
  table.remove(args, 1)
  table.freeze(args)

  local fake_process = Table.copy(process, true)

  fake_process.args = args

  table.freeze(fake_process)

  local req = require

  assert = _G.LPM_OLD_ASSERT
  pcall(req, file) -- Consider converting to a lune run call. Issues with stdin however.
  assert = output.assert
end

function script_manager.get_scripts(
  include_hooks: boolean?
): { [string]: { hook: boolean, execute: string, script: boolean } }
  local out = {}
  if include_hooks then
    local _, manifest = manifest_helper.read()
    for name, script in manifest.scripts do
      if out[name] == nil then
        out[name] = { hook = true, execute = script, script = false }
      end
    end
  end
  local scripts = fs.readDir(`{process.cwd()}/scripts/`)
  for _, script in scripts do
    local script_path = `{process.cwd()}/scripts/{script}`
    local ext = path.extname(script)
    local basename = path.basename(script_path, ext)
    if fs.isFile(script_path) and ext == ".luau" then
      if out[basename] == nil then
        out[basename] = { hook = false, execute = script_path, script = true }
      end
    end
  end
  return out
end

function script_manager.run_script(name: string)
  if fs.isFile("./scripts/" .. name .. ".luau") then
    script_manager.execute_file(process.cwd() .. "/scripts/" .. name .. ".luau")
  else
    output.error(`Script '{name}.luau' could not be found`)
  end
end

function script_manager.run_hook(name: string)
  local _args = Table.copy(process.args, true)
  local scripts = script_manager.get_scripts(true)

  if scripts[name] then
    local script_data = scripts[name]
    if script_data.hook then
      local script = string.split(script_data.execute, " ")
      local command = table.remove(script, 1)
      process.spawn(command :: string, script, { stdio = "forward" })
    else
      script_manager.execute_file(script_data.execute)
    end
  end
end

return script_manager
