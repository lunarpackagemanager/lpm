local std = require("@pkg/std")

local config = require("../config")
local constants = require("../constants")

local bundler = require("./bundler")
local output = require("./output")
local readManifest = require("../pkg_manifest/read_package_manifest")
local zip = require("./zzlib")

local fs = std.fs
local process = std.process
local os = std.os
local luau = std.luau
local net = std.net

local userOs = process.os
local userArch = process.arch

local GLOBAL_DIR = constants.global_dir

local build = {}

local targets = {
  "linux-aarch64",
  "linux-x86_64",
}

export type BuildTarget = "all" | "linux-x86_64" | "linux-aarch64" | "windows-x86_64" | "macos-x86_64" | "macos-aarch64"
export type BuildMode = "dev" | "release"

export type BuildOverride = {
  target: string?,
  optimization_level: number?,
  coverage_level: number?,
  debug_level: number?,
  dev: boolean?,
  zip: boolean?,
  comment: boolean?,
}

local runtime = `{GLOBAL_DIR}/bin/lune`

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

function build.build_binary(loc: string, output: string, os: string, arch: string)
  return run(`{runtime} build {loc} -o {output} -t {os}-{arch}`)
end

function build.get_remote_runtime(version: string?)
  if not fs.isFile(runtime) then
    local url = string.format(
      "https://github.com/lune-org/lune/releases/download/v%s/lune-%s-%s-%s.zip",
      version or config.lune_version,
      version or config.lune_version,
      userOs,
      userArch
    )

    local container = net.request(url)

    local runtimeData = zip.unzip(container.body, `lune{if userOs == "windows" then ".exe" else ""}`)
    fs.writeFile(runtime, runtimeData)

    if userOs ~= "windows" then
      run(`chmod 755 {runtime}`)
    end
  end
end

local function compress(a: string, b: string)
  if process.os == "windows" then
    run(`powershell Compress-Archive {a} {b} -Force`)
  else
    run(`7z a {b}.zip {a}`)
  end
end

local function cleanFolders(path: string)
  if fs.isDir(path) then
    fs.removeDir(path)
  end
  fs.writeDir(path)
end

function build.build(mode: BuildMode, override: BuildOverride)
  build.get_remote_runtime()
  cleanFolders("./release")
  cleanFolders("./dist")

  local DEFAULT_OPT_LVL = if mode == "release" then 2 else 1
  local DEFAULT_DBG_LVL = if mode == "release" then 0 else 1
  local DEFAULT_CV_LVL = if mode == "release" then 0 else 0
  local DEFAULT_TARGET = if mode == "release" then "all" else `{process.os}-{process.arch}`
  local DEFAULT_ZIP = if mode == "release" then true else false

  local DEBUG = mode == "dev"

  local ok, manifest = readManifest(false)
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

  b_config.optimization_level = override.optimization_level or b_config.optimization_level or DEFAULT_OPT_LVL
  b_config.coverage_level = override.coverage_level or b_config.coverage_level or DEFAULT_CV_LVL
  b_config.debug_level = override.coverage_level or b_config.debug_level or DEFAULT_DBG_LVL
  b_config.target = override.target or b_config.target or DEFAULT_TARGET :: any
  b_config.zip = override.zip or b_config.zip or DEFAULT_ZIP
  b_config.lune_version = b_config.lune_version or config.lune_version
  b_config.name = b_config.name or manifest.name

  local out_name = b_config.name
  local target = b_config.target

  output.write("Bundling files...")
  local bundleRes = bundler.bundle((manifest.main :: any).bin or manifest.main, true)
  fs.writeFile(`./dist/{out_name}.luau`, bundleRes)

  output.write("Compiling files...")
  local bytecode = luau.compile(bundleRes, {
    optimizationLevel = b_config.optimization_level,
    debugLevel = b_config.debug_level,
    coverageLevel = b_config.coverage_level,
  })

  fs.writeFile(`./release/{out_name}.luauc`, bytecode)

  local function create_release(os: string, arch: string)
    local ext = if os == "windows" then ".exe" else ""
    local name = `./release/{out_name}-{os}-{arch}{ext}`

    -- output.write(`Getting remote runtime for {os}-{arch}.`)
    -- local runtime = build.get_remote_runtime(os, arch, b_config.lune_version)

    output.write(`Creating binary for {os}-{arch}`)
    build.build_binary(`./dist/{out_name}.luau`, name, os, arch)

    -- fs.writeFile(name .. "other", build.patch_binary(runtime, bytecode))

    if b_config.zip then
      output.write(`Creating .zip for {os}-{arch}`)
      compress(name, `./release/{out_name}-{os}-{arch}`)
    end

    if DEBUG and os == process.os and arch == process.arch then
      fs.copy(name, `./release/{out_name}`)
      if os ~= "windows" then
        run(`chmod 755 ./release/{out_name}`)
      end
    end

    output.write(`Created binary for {os}-{arch}.`)
  end

  if target ~= "all" and not table.find(targets, target :: string) then
    return output.write("Build failed.")
  end

  if target == "all" then
    for _, t in targets do
      local targetData = string.split(t :: string, "-")
      create_release(targetData[1], targetData[2])
    end
  else
    local targetData = string.split(target :: string, "-")
    create_release(targetData[1], targetData[2])
  end

  if b_config.zip then
    compress(`./release/{out_name}.luauc`, `./release/{out_name}-bytecode`)
  end

  return output.write("Building complete.")
end

return build
