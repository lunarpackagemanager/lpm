local config = require("../config")
local fs = require("@lune/fs")
local manifest_helper = require("./manifest_helper")
local output = require("./output")
local process = require("@lune/process")
local resolver = require("./resolver")
local serde = require("@lune/serde")
local sys = require("./sys")
local t = require("../types")

local package_handler = {}

type InstallPackageOptions = {
  add_dependency: boolean | string?,
  warn_on_already_installed: boolean?,
  dont_reinstall: boolean?,
}

function package_handler.is_package_installed(name: string): boolean
  return fs.isDir(`lune_modules/{name:split("/")[1]}`) and fs.isDir(`{sys.local_dir}/{name}`)
end

function package_handler.get_root_dependencies()
  local read_ok, manifest, commit = manifest_helper.read(true)
  assert(read_ok and manifest and commit, "Package manifest not found")

  return manifest.dependencies or {}
end

function package_handler.get_all_dependencies()
  local read_ok, manifest, commit = manifest_helper.read(true)
  assert(read_ok and manifest and commit, "Package manifest not found")

  local total_deps = {}

  for packageName in manifest.dependencies do
    table.insert(total_deps, packageName)
  end

  return total_deps
end

function package_handler.for_each_installed_package(func: (name: string, path: string) -> ())
  if not fs.isDir("lune_modules") then
    return
  end

  for _, pkg_path in fs.readDir("lune_modules") do
    local complete_path = `lune_modules/{pkg_path}`
    if fs.isDir(complete_path) then
      func(pkg_path, complete_path)
    end
  end
end

function package_handler.treeshake()
  local valid_dependencies = package_handler.get_all_dependencies()

  package_handler.for_each_installed_package(function(name, path)
    if not table.find(valid_dependencies, name) then
      fs.removeDir(path)
      output.write(`Removed {name}`)
    end
  end)
end

function package_handler.install_package(identifier: string, options: InstallPackageOptions?, previous: string?)
  local options = options or {} :: InstallPackageOptions

  -- Parse package identifier
  local package_data = resolver.parse_identifier(identifier)
  assert(package_data and package_data.valid, "Invalid package identifier")

  local read_ok, manifest, commit = manifest_helper.read(true)

  assert(read_ok and manifest and commit, "Package manifest not found")

  assert(package_data.valid, "Invalid package identifier provided")

  if options.add_dependency then
    local is_dev_dep = manifest.dev_dependencies[package_data.name]
    local is_std_dep = manifest.dependencies[package_data.name]

    if options.add_dependency == "dev" then
      if is_std_dep then
        manifest.dependencies[package_data.name] = nil
      end
      manifest.dev_dependencies[package_data.name] = package_data.ref :: string
    else
      if is_dev_dep then
        manifest.dev_dependencies[package_data.name] = nil
      end
      manifest.dependencies[package_data.name] = package_data.ref :: string
    end
  end

  commit()

  output.write(`Installing {identifier}`)

  local install_path = `{previous or "."}/lune_modules/{package_data.name}`
  if fs.isDir(install_path) then
    fs.removeDir(install_path)
  end
  sys.ensure_dir_exists(install_path)

  local repo_url = `https://github.com/lune-package/{package_data.name}.git`

  output.write(`Downloading package lune-package/{package_data.name} from GitHub`)

  local git_clone_result
  if package_data.ref then
    git_clone_result =
      process.spawn("git", { "clone", "--depth", "1", repo_url, "--branch", package_data.ref, install_path })
    if not git_clone_result.ok then
      -- Maybe they use `v1.0.0` instead of `1.0.0` for tags?
      git_clone_result =
        process.spawn("git", { "clone", "--depth", "1", repo_url, "--branch", "v" .. package_data.ref, install_path })
    end
  end

  output.assert(git_clone_result.ok, `Failed to download {identifier} from GitHub:`, git_clone_result.stderr)

  fs.removeDir(`{install_path}/.git`)

  local package_has_manifest = fs.isFile(`{install_path}/{sys.manifest_name}`)

  if package_has_manifest then
    local ok, package_manifest = manifest_helper.read(false, `{install_path}/{sys.manifest_name}`)
    if not ok then
      output.warn("Installed package has an invalid manifest file, use with caution")
      return
    end
    assert(package_manifest)

    -- OS / ARCH warnings --
    if package_manifest.arch and not table.find(package_manifest.arch, process.arch) then
      output.warn("Installed package may not be compatible with this system architecture")
    end

    if package_manifest.os and not table.find(package_manifest.os, process.os) then
      output.warn("Installed package may not be compatible with this operating system")
    end

    -- Include files only --
    local file_globs = package_manifest.files or { "*" }
    local raw_files = sys.read_dir_flat(install_path, true)
    local files_to_keep = {}

    for _, glob in file_globs :: { string } do
      local mid = ""
      if glob:sub(1, 1) ~= "/" then
        mid = "/"
      end
      glob = install_path .. mid .. glob
      local files = sys.filter_files(raw_files, glob)

      for _, file in files do
        if not table.find(files_to_keep, file) then
          table.insert(files_to_keep, file)
        end
      end
    end

    for _, file in raw_files do
      if not table.find(files_to_keep, file) then
        sys.remove(file)
      end
    end

    -- Add init --
    local has_init = fs.isFile(`{install_path}/init.luau`) or fs.isFile(`{install_path}/init.lua`)
    if not has_init and package_manifest.main then
      local entrypoint
      if typeof(package_manifest.main) == "table" then
        entrypoint = package_manifest.main.lib
      else
        entrypoint = package_manifest.main
      end

      fs.writeFile(`{install_path}/init.luau`, `return require("{entrypoint}")`)
    end

    -- Install Dependencies --2
    for _, dependency in package_manifest.dependencies :: any or {} do
      package_handler.install_package(dependency, {
        add_dependency = false,
      }, install_path)
    end
  else
    output.warn(
      `Installed package is not managed by {config.name}, you may need to navigate to the entrypoint manually`
    )
  end
end

function package_handler.uninstall_package(identifier: string)
  local read_ok, manifest, commit = manifest_helper.read(true)
  assert(read_ok and manifest and commit, "Package manifest not found")

  local is_dev_dep = manifest.dev_dependencies[identifier]
  local is_dep = manifest.dependencies[identifier]
  local is_exist = is_dev_dep ~= nil or is_dep ~= nil

  if is_exist then
    if is_dev_dep ~= nil then
      manifest.dev_dependencies[identifier] = nil
    else
      manifest.dependencies[identifier] = nil
    end
  end

  output.write(`Uninstalling {identifier}`)
  commit()

  package_handler.treeshake()
end

return package_handler
