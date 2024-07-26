local libutil = require("@pkg/libutil")
local t = require("../types")

local Table = libutil.table

local SYMBOLS_ANSI = {
  LAST_BRANCH = "└── ",
  BRANCH = "├── ",
  INDENT = "    ",
  VERTICAL = "│   ",
  EMPTY = "",
}

local SYMBOLS_ASCII = {
  LAST_BRANCH = "-- ",
  BRANCH = "|-- ",
  INDENT = "    ",
  VERTICAL = "|   ",
  EMPTY = "",
}

export type TreeOptions = {
  max_depth: number?,
  ascii: boolean?,
}

local DEFAULT_SETTINGS = {
  max_depth = math.huge,
  ascii = false,
}

local function pprint(
  name: string,
  data: t.Dependency,
  currentDepth: number,
  precedingSymbols: string,
  options: TreeOptions,
  isLast: boolean?
)
  local lines = {}
  local SYMBOLS = options.ascii and SYMBOLS_ASCII or SYMBOLS_ANSI

  if currentDepth > options.max_depth :: number then
    return lines
  end

  local line = precedingSymbols
  if currentDepth >= 1 then
    line ..= isLast and SYMBOLS.LAST_BRANCH or SYMBOLS.BRANCH
  end
  line ..= `{name}@{data.version}`
  table.insert(lines, line)

  if data.dependencies then
    local keys = {}

    for key in data.dependencies do
      table.insert(keys, key)
    end

    table.sort(keys)

    if #keys > 0 then
      for i, dependencyName in keys do
        local isCurrentLast = i == #keys
        local subData = data.dependencies[dependencyName]

        local linesForFile = pprint(
          dependencyName,
          subData,
          currentDepth + 1,
          precedingSymbols .. (currentDepth >= 1 and isLast and SYMBOLS.INDENT or SYMBOLS.VERTICAL or SYMBOLS.EMPTY),
          options,
          isCurrentLast
        )
        Table.push(lines, Table.spread(linesForFile))
      end
    end
  end

  return lines
end

local function tree(root: t.Package, options: TreeOptions?)
  local fixedOptions: TreeOptions = options or {}
  fixedOptions = Table.reconcile(fixedOptions, DEFAULT_SETTINGS)
  fixedOptions.max_depth = fixedOptions.max_depth :: number + 1

  local lines = { `{root.name}@{root.version}` }
  local keys = {}

  for key in root.dependencies do
    table.insert(keys, key)
  end

  table.sort(keys)

  for i, dependencyName in keys do
    local isCurrentLast = i == #keys
    local subData = root.dependencies[dependencyName]

    local linesForFile = pprint(dependencyName, subData, 1, "", fixedOptions, isCurrentLast)

    Table.push(lines, Table.spread(linesForFile))
  end

  return table.concat(lines, "\n")
end

return tree
