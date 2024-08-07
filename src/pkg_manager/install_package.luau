local GitTagFetcher = require("../fetching/git_tag_fetcher")
local config = require("../config")
local output = require("../libs/output")
local readManifest = require("../pkg_manifest/read_package_manifest")
local resolver = require("../libs/resolver")
local std = require("@pkg/std")
local t = require("../types")

local fs = std.fs
local process = std.process

type InstallPackageOptions = t.InstallPackageOptions

local function install_package(
  identifier: string,
  options: InstallPackageOptions?,
  previous: string?
)
  local options = options or {} :: InstallPackageOptions

  -- Parse package identifier
  local package_data = resolver.parse_identifier(identifier)
  assert(package_data and package_data.valid, "Invalid package identifier")

  local read_ok, manifest, commit = readManifest(true)

  assert(read_ok and manifest and commit, "Package manifest not found")

  assert(package_data.valid, "Invalid package identifier provided")

  if package_data.ref == "latest" then
    package_data.ref = GitTagFetcher.get_latest_tag(package_data.name).name
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
    git_clone_result = process.spawn(
      "git",
      { "clone", "--depth", "1", repo_url, "--branch", package_data.ref, install_path }
    )
    if not git_clone_result.ok then
      git_clone_result = process.spawn(
        "git",
        { "clone", "--depth", "1", repo_url, "--branch", "v" .. package_data.ref, install_path }
      )
    end
  end

  output.assert(
    git_clone_result.ok,
    `Failed to download {identifier} from GitHub:`,
    git_clone_result.stderr
  )

  fs.removeDir(`{install_path}/.git`)

  local package_has_manifest = fs.isFile(`{install_path}/package.toml`)

  if package_has_manifest then
    local ok, package_manifest = readManifest(false, `{install_path}/package.toml`)
    if not ok then
      output.warn("Installed package has an invalid manifest file, use with caution")
      return
    end
    assert(package_manifest, "Package manifest is not found")

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
      install_package(dependency, {
        add_dependency = false,
      }, install_path)
    end
  else
    output.warn(
      `Installed package is not managed by {config.name}, you may need to navigate to the entrypoint manually`
    )
  end
end

return install_package
