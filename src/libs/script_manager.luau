--!nocheck

local manifest_helper = require("./manifest_helper")
local output = require("./output")
local std = require("@pkg/std")

local fs = std.fs
local process = std.process
local sys = std.sys

local script_manager = {}

function script_manager.execute_file(file: string)
  local args = table.clone(process.args)
  table.remove(args, 1)
  table.freeze(args)

  local fake_process = {}
  for k, v in pairs(process) do
    fake_process[k] = v
  end

  fake_process.args = args

  table.freeze(fake_process)

  local o_req
  o_req = require

  local function req(path: string)
    local cwd = debug.info(3, "s"):match('%[string "(.-)"')
    if path:match("^@(.-)$") then
      return o_req(path)
    else
      local src = sys.normalisePath(cwd)
      src = src:split("/")
      table.remove(src, #src)
      src = table.concat(src, "/") .. "/"
      path = sys.normalisePath(src .. path)
    end

    return o_req(path)
  end

  require = function(request: string)
    if request == "@lune/process" then
      return fake_process
    else
      return req(request)
    end
  end

  assert = _G.LPM_OLD_ASSERT
  pcall(o_req, file) -- Consider converting to a lune run call. Issues with stdin however.
  assert = output.assert
end

function script_manager.get_scripts(include_hooks: boolean?): { string }
  local scripts = fs.readDir("./scripts/")
  local out = {}
  for i, v in scripts do
    local name = v:match("%./scripts/(.-)%.luau")
    if not name then
      continue
    end

    if name:sub(1, 2) == "__" and not include_hooks then
      continue
    end

    table.insert(out, name)
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
  local args = table.clone(process.args)
  local _, manifest = manifest_helper.read()

  if manifest.scripts[name] then
    local script = string.split(manifest.scripts[name], " ")
    local command = table.remove(script, 1)
    process.spawn(command :: string, script, { stdio = "forward" })
  elseif fs.isFile(`./scripts/__{name}.luau`) then
    script_manager.execute_file(process.cwd() .. "/scripts/__" .. name .. ".luau")
  end
end

return script_manager
