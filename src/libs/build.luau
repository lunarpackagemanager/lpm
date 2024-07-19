local bundler = require("./bundler")
local config = require("../config")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local manifest_helper = require("./manifest_helper")
local net = require("@lune/net")
local output = require("./output")
local process = require("@lune/process")
local std = require("@pkg/std")
local zip = require("@pkg/zzlib")

local os = std.os

local GLOBAL_DIR = `{os.homedir()}/.{config.name.long:lower()}`

local build = {}

local targets = {
  "windows-x86_64",
  "linux-aarch64",
  "macos-aarch64",
  "linux-x86_64",
  "macos-x86_64",
  "all",
}

local MAGIC = "cr3sc3nt"

function build.patch_binary(runtime: string, bytecode: string): string
  return runtime .. bytecode .. string.pack(">I8", #bytecode) .. MAGIC
end

local function run(cmd: string)
  local arguments = string.split(cmd, " ")
  local command = table.remove(arguments, 1) :: string
  -- table.insert(arguments, ">")
  -- table.insert(arguments, "nul")
  process.spawn(command, arguments, { stdio = "forward" })
end

function build.get_remote_runtime(os: string, arch: string, version: string?): string
  local cache_name = `{GLOBAL_DIR}/bin/lune-{os}-{arch}`

  if fs.isFile(cache_name) then
    return fs.readFile(cache_name)
  end

  local url = string.format(
    "https://github.com/lune-org/lune/releases/download/v%s/lune-%s-%s-%s.zip",
    version or config.lune_version,
    version or config.lune_version,
    os,
    arch
  )

  local container = net.request(url)

  local runtime = zip.unzip(container.body, `lune{if os == "windows" then ".exe" else ""}`)
  fs.writeFile(cache_name, runtime)

  return runtime
end

local function compress(a: string, b: string)
  if process.os == "windows" then
    run(`powershell Compress-Archive {a} {b} -Force`)
  else
    run(`zip {b} {a}`)
  end
end

function build.build(mode: "dev" | "release"?)
  if fs.isDir("./dist/") then
    fs.removeDir("./dist/")
  end
  fs.writeDir("./dist/")

  local DEFAULT_OPT_LVL = if mode == "release" then 2 else 1
  local DEFAULT_DBG_LVL = if mode == "release" then 0 else 1
  local DEFAULT_CV_LVL = if mode == "release" then 0 else 0
  local DEFAULT_TARGET = if mode == "release" then "all" else "dev"
  local DEFAULT_ZIP = if mode == "release" then true else false

  local ok, manifest = manifest_helper.read(false)
  assert(ok and manifest, "No manifest")

  local b_config = {}

  if manifest.build_config and manifest.build_config.release and mode == "release" then
    b_config = manifest.build_config.release
    setmetatable(b_config, { __index = manifest.build_config })
  elseif manifest.build_config and manifest.build_config.dev and mode == "dev" then
    b_config = manifest.build_config.dev
    setmetatable(b_config, { __index = manifest.build_config })
  else
    b_config = manifest.build_config or b_config
  end

  b_config.optimization_level = b_config.optimization_level or DEFAULT_OPT_LVL
  b_config.coverage_level = b_config.coverage_level or DEFAULT_CV_LVL
  b_config.debug_level = b_config.debug_level or DEFAULT_DBG_LVL
  b_config.target = b_config.target or DEFAULT_TARGET :: any
  b_config.zip = b_config.zip or DEFAULT_ZIP
  b_config.lune_version = b_config.lune_version or config.lune_version
  b_config.name = b_config.name or manifest.name

  print("Bundling files...")
  local bundled = bundler.bundle((manifest.main :: any).bin or manifest.main)
  print("Compiling files...")
  local bytecode = luau.compile(bundled, {
    optimizationLevel = b_config.optimization_level,
    debugLevel = b_config.debug_level,
    coverageLevel = b_config.coverage_level,
  })

  local out_name = b_config.name
  local target = b_config.target

  if table.find(targets, target :: string) then
    local function create_release(bytecode: string, os: string, arch: string)
      local ext = if os == "windows" then ".exe" else ""
      local name = if target == "all" then `./dist/{out_name}-{os}-{arch}{ext}` else `./dist/{out_name}{ext}`

      output.write(`Getting remote runtime for {os}-{arch}.`)
      local runtime = build.get_remote_runtime(os, arch, b_config.lune_version)

      output.write(`Creating binary for {os}-{arch}`)

      fs.writeFile(name, build.patch_binary(runtime, bytecode))

      if b_config.zip then
        output.write(`Creating .zip for {os}-{arch}`)
        compress(name, `./dist/{out_name}-{os}-{arch}`)
      end

      output.write(`Created binary for {os}-{arch}.`)
    end

    if target == "all" then
      fs.writeFile(`./dist/{out_name}.luau`, bundled)
      fs.writeFile(`./dist/{out_name}.luauc`, bytecode)

      create_release(bytecode, "windows", "x86_64")
      create_release(bytecode, "linux", "x86_64")
    else
      create_release(bytecode, unpack(string.split(target :: string, "-")))
    end

    output.write("Building complete.")
  end
end

return build
