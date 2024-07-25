local output = require("./output")
local t = require("../types")

local resolver = {}

type DownloadFunc = (path: string) -> (boolean, string?)

function resolver.parse_identifier(identifier: string): t.PackageData?
  output.assert(identifier, "An invalid package identifier was provided")

  local CORE = "[%w%-_%.]+"
  local REF = "[%w%-%._/]+"

  local valid = (string.match(identifier, `^{CORE}$`) or string.match(identifier, `^{CORE}@{REF}$`)) ~= nil

  if valid then
    return {
      kind = "github",
      valid = true,
      identifier = identifier,
      owner = "lune-package",
      name = string.match(identifier, "^([%w%-_%.]+).*$") :: string,
      ref = string.match(identifier, "^[%w%-_%.]+@([%w%-%._/]+).*$") or "latest",
    }
  else
    return {
      kind = "github",
      valid = false,
    }
  end
end

function resolver.parse_semver(semver: string): t.Semver
  local version_data = {}

  local VERSION_CORE = "%d+%.%d+%.%d+"
  local DOT_SEPERATED_IDENTIFIERS = "[%w.]+"

  version_data.valid = (
    string.match(semver, `^{VERSION_CORE}$`)
    or string.match(semver, `^{VERSION_CORE}%-{DOT_SEPERATED_IDENTIFIERS}$`)
    or string.match(semver, `^{VERSION_CORE}%+{DOT_SEPERATED_IDENTIFIERS}$`)
    or string.match(semver, `^{VERSION_CORE}%-{DOT_SEPERATED_IDENTIFIERS}+{DOT_SEPERATED_IDENTIFIERS}$`)
  ) ~= nil

  if version_data.valid then
    version_data.major = tonumber(string.match(semver, "^(%d+).*"))
    version_data.minor = tonumber(string.match(semver, "^%d%.(%d+).*"))
    version_data.patch = tonumber(string.match(semver, "^%d%.%d%.(%d+).*"))
    version_data.prerelease_identifiers = (string.match(semver, "^.*%-([%w.]+).*") or ""):split(".")
    version_data.build_identifiers = (string.match(semver, "^.*%+([%w.]+).*") or ""):split(".")

    if version_data.prerelease_identifiers[1] == "" then
      version_data.prerelease_identifiers = nil :: any
    end

    if version_data.build_identifiers[1] == "" then
      version_data.build_identifiers = nil :: any
    end
  end

  return version_data
end

function resolver.pack_semver(parsed: t.Semver): string
  local semver = ""

  semver ..= tostring(parsed.major) .. "."
  semver ..= tostring(parsed.minor) .. "."
  semver ..= tostring(parsed.patch)

  if parsed.prerelease_identifiers then
    semver ..= "-" .. table.concat(parsed.prerelease_identifiers, ".")
  end

  if parsed.build_identifiers then
    semver ..= "+" .. table.concat(parsed.build_identifiers, ".")
  end

  return semver
end

return resolver
