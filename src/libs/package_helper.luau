local config = require("../config")
local manifest_helper = require("./manifest_helper")
local net = require("@lune/net")
local output = require("./output")
local resolver = require("./resolver")
local serde = require("@lune/serde")
local std = require("@pkg/std")
local t = require("../types")

local fs = std.fs
local process = std.process

local package_handler = {}

type InstallPackageOptions = {
  add_dependency: boolean | string?,
  warn_on_already_installed: boolean?,
  dont_reinstall: boolean?,
}

type Dependency = {
  version: DependencyVersion,
  dependencies: { [string]: Dependency }?,
}

type DependencyVersion = {
  major: number,
  minor: number,
  patch: number,
}

function package_handler.is_package_installed(name: string): boolean
  return fs.isDir(`lune_modules/{name:split("/")[1]}`) and fs.isDir(`lune_modules/{name}`)
end

function package_handler.get_root_dependencies()
  local read_ok, manifest, commit = manifest_helper.read(true)
  assert(read_ok and manifest and commit, "Package manifest not found")

  local version = resolver.parse_semver(manifest.version)

  local data = {}
  if version.valid then
    data = {
      [manifest.name] = {
        version = { major = version.major, minor = version.minor, patch = version.patch },
        dependencies = {},
      },
    }
  end

  for dependencyName, depencyVersion in manifest.dependencies do
    local depVersion = resolver.parse_semver(depencyVersion)

    if depVersion.valid then
      data[manifest.name].dependencies[dependencyName] = {
        version = { major = depVersion.major, minor = depVersion.minor, patch = depVersion.patch },
      }
    end
  end

  return data
end

function package_handler.get_all_dependencies(path: string?, total_deps: any?)
  local read_ok, manifest, commit = manifest_helper.read(true, path)
  assert(read_ok and manifest and commit, "Package manifest not found")

  local total_deps = total_deps or {}

  if total_deps[manifest.name] == nil then
    local version = resolver.parse_semver(manifest.version)
    if version.valid then
      total_deps[manifest.name] =
        { version = { major = version.major, minor = version.minor, patch = version.patch }, dependencies = {} }
    end
  end

  for dependencyName, dependencyVersion in manifest.dependencies do
    local package_manifest_path = `lune_modules/{dependencyName}/package.toml`
    if fs.isFile(package_manifest_path) then
      package_handler.get_all_dependencies(package_manifest_path, total_deps[manifest.name].dependencies)
    end
  end

  return total_deps
end

local connectors = {
  tee = "├",
  elbow = "└",
  hLine = "─",
  space = " ",
  vLine = "│",
}

function package_handler.print_dependencies(deps: { [string]: Dependency }, prefix: string?, recursive: boolean?)
  local actualPrefix = prefix or ""

  local keys = {}
  for k in pairs(deps) do
    table.insert(keys, k)
  end
  table.sort(keys)

  for i, packageName in ipairs(keys) do
    local packageData = deps[packageName]
    local is_current_last = (i == #keys)

    local connector = is_current_last and (connectors.elbow .. connectors.hLine .. connectors.hLine)
      or (connectors.tee .. connectors.hLine .. connectors.hLine)
    local sub_prefix = is_current_last
        and (connectors.space .. connectors.space .. connectors.space .. connectors.space)
      or (connectors.vLine .. connectors.space .. connectors.space .. connectors.space)

    local has_sub_dependencies = packageData.dependencies and next(packageData.dependencies) ~= nil

    -- If node has sub-dependencies, use the special connector
    if has_sub_dependencies then
      connector = is_current_last and (connectors.elbow .. connectors.hLine .. connectors.hLine .. connectors.hLine)
        or (connectors.tee .. connectors.hLine .. connectors.hLine .. connectors.hLine)
    end

    output.write(
      actualPrefix
        .. connector
        .. packageName
        .. "@"
        .. `{packageData.version.major}.{packageData.version.minor}.{packageData.version.patch}`
    )

    if has_sub_dependencies then
      -- Recursive call to print sub-dependencies
      package_handler.print_dependencies(packageData.dependencies :: any, actualPrefix .. sub_prefix, true)
    end
  end
end

-- Function to start printing from the root node
function package_handler.print_all_dependencies(deps: { [string]: Dependency })
  local root_package_name = next(deps)
  if root_package_name then
    local root_package_data = deps[root_package_name]
    output.write(
      `{root_package_name}@{root_package_data.version.major}.{root_package_data.version.minor}.{root_package_data.version.patch}`
    )
    package_handler.print_dependencies(root_package_data.dependencies :: any, nil, true)
  end
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
    if not valid_dependencies[name] then
      fs.removeDir(path)
      output.write(`Removed {name}`)
    end
  end)
end

function package_handler.get_latest_tag(package_name: string): string
  local repo_url = `https://api.github.com/repos/lune-package/{package_name}/tags`

  local res = net.request({ method = "GET", url = repo_url })
  local data = serde.decode("json", res.body)

  return data[1].name
end

function package_handler.install_package(identifier: string, options: InstallPackageOptions?, previous: string?)
  local options = options or {} :: InstallPackageOptions

  -- Parse package identifier
  local package_data = resolver.parse_identifier(identifier)
  assert(package_data and package_data.valid, "Invalid package identifier")

  local read_ok, manifest, commit = manifest_helper.read(true)

  assert(read_ok and manifest and commit, "Package manifest not found")

  assert(package_data.valid, "Invalid package identifier provided")

  if package_data.ref == "latest" then
    print("latest")
    package_data.ref = package_handler.get_latest_tag(package_data.name)
  end

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
  fs.ensureDirExists(install_path)

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

  local package_has_manifest = fs.isFile(`{install_path}/package.toml`)

  if package_has_manifest then
    local ok, package_manifest = manifest_helper.read(false, `{install_path}/package.toml`)
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
    local raw_files = fs.readDirFlat(install_path, true)
    local files_to_keep = {}

    for _, glob in file_globs :: { string } do
      local mid = ""
      if glob:sub(1, 1) ~= "/" then
        mid = "/"
      end
      glob = install_path .. mid .. glob
      local files = fs.filterFiles(raw_files, glob)

      for _, file in files do
        if not table.find(files_to_keep, file) then
          table.insert(files_to_keep, file)
        end
      end
    end

    for _, file in raw_files do
      if not table.find(files_to_keep, file) then
        fs.remove(file)
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
