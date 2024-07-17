local config = require("../config")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local sys = require("@deps/std/sys")

local Sys = {}
Sys.dir_name = string.lower(config.name.long)
Sys.local_dir = `./.{Sys.dir_name}`
Sys.global_dir = `{sys.homedir()}/.{Sys.dir_name}`
Sys.manifest_name = `package.toml`

function Sys.ensure_dir_exists(path: string)
  if not fs.isDir(path) then
    fs.writeDir(path)
  end
end

function Sys.ensure_file_exists(path: string, content: string?)
  Sys.ensure_dir_exists(Sys.folder_of(path))

  if not fs.isFile(path) then
    fs.writeFile(path, content or "")
  end
end

function Sys.folder_of(file: string): string
  file = sys.normalize_path(file)
  local parts = file:split("/")
  table.remove(parts, #parts)

  return table.concat(parts, "/") .. "/"
end

function Sys.read_dir_flat(dir: string, include_directories: boolean?)
  local flat_files = {}

  local function search_dir(next_dir: string)
    local files = fs.readDir(next_dir)
    for _, v in files do
      local name = next_dir .. "/" .. v
      local md = fs.metadata(name)

      if md.kind == "dir" then
        if include_directories then
          table.insert(flat_files, name)
        end
        search_dir(name)
      elseif md.kind == "file" then
        table.insert(flat_files, name)
      end
    end
  end

  search_dir(dir)

  return flat_files
end

function Sys.filter_files(files: { string }, filter: string): { string }
  local pattern = if filter then sys.globtopattern(filter) else nil
  local new_files = {}

  for _, file in files do
    if file:match(pattern) then
      table.insert(new_files, file)
    end
  end

  return new_files
end

function Sys.remove(path: string)
  if fs.isDir(path) then
    fs.readDir(path)
  elseif fs.isFile(path) then
    fs.removeFile(path)
  end
end

function Sys.luaurc(): {}
  return (fs.isFile("./.luaurc") and serde.decode("json", fs.readFile("./.luaurc"))) or {}
end

function Sys.line_count(str: string): number
  return #str:split("\n")
end

return setmetatable(Sys, {
  __index = sys,
})
