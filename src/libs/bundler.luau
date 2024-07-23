--!nocheck

local config = require("../config")
local fs = require("@lune/fs")
local output = require("./output")
local serde = require("@lune/serde")
local std = require("@pkg/std")
local Table = require("@pkg/libutil").table
local luaup = require("../dependencies/luaup")

local path = std.path
local sys = std.sys
local os = std.os

local GLOBAL_DIR = `{os.homedir()}/.{config.name.long:lower()}`
local bundler = {}

local WIDTH = 100

local BUNDLE_INDEX = [==[
--[=[
  LPM Bundler

  Index:%s
]=]

--!nocheck
--!nolint

]==]

local BUNDLE_HEADER = [[
local __LPM_REQUIRE_CACHE = {};
local __LPM_MODULES = {};

local function __LPM_REQUIRE(hash: string): any
  if not __LPM_REQUIRE_CACHE[hash] then
      __LPM_REQUIRE_CACHE[hash] = __LPM_MODULES[hash]();
  end

  return __LPM_REQUIRE_CACHE[hash];
end
]]

type CharPositions = {
  {
    start_line: number,
    start_col: number,
    end_line: number,
    end_col: number,
    start_byte: number,
    end_byte: number,
  }
}

local file_cache = {}

local function readFile(path: string)
  if not file_cache[path] then
    file_cache[path] = fs.readFile(path)
  end
  return file_cache[path]
end

local function header(text: string): string
  local v_ln = string.rep("-", WIDTH)

  local out = ""
  for _, v in string.split(text, "\n") do
    local t = "--  " .. v
    local ws = string.rep(" ", WIDTH - 2 - #t)
    out ..= t .. ws .. "--\n"
  end

  return `{v_ln}\n{out}{v_ln}`
end

local function is_require(call): (boolean, string?)
  local path

  if not (call.lhs and call.lhs.kind == "name" and call.lhs.tok.value == "require") then -- No
    return false
  end

  if #call.args.exprs ~= 1 then
    return false
  end

  local first_exp = call.args.exprs[1].item

  if first_exp.kind == "string" then
    path = first_exp.tok.value

    local literal_syntax = first_exp.tok.value:sub(1, 1)
    if literal_syntax == "[" then
      return false
    end

    path = path:sub(2, #path - 1)
  elseif first_exp.kind == "istring" and first_exp.istring.kind == "simple" then
    path = first_exp.istring.tok.value
  else
    return false
  end

  local start = call.lhs.tok.span.start
  local finish = call.args.parens.close.span.finish

  return true, path, { start = start, finish = finish }, call
end

local function fix_path(path: string, aliases: { [string]: string }, source_dir: string): string
  if path:sub(1, 1) == "@" then
    return string.gsub(path, "^(@.-)/", function(alias)
      local new_path = aliases[string.sub(alias, 2, #alias)]

      if new_path:sub(#new_path, #new_path) ~= "/" then
        new_path ..= "/"
      end

      return new_path
    end)
  end

  return source_dir .. path
end

local function folderOf(file: string): string
  file = sys.normalisePath(file)
  local parts = string.split(file, "/")
  table.remove(parts, #parts)

  return table.concat(parts, "/") .. "/"
end

local function get_lines(str: string): number
  return #str:split("\n")
end

local function delete_substring_by_bytes(str: string, start_byte: number, end_byte: number)
  -- Ensure start_byte and end_byte are within the bounds of the string
  start_byte = math.max(start_byte, 1)
  end_byte = math.min(end_byte, #str)

  -- Return the modified string with the specified byte range removed
  return string.sub(str, 0, start_byte - 1) .. string.sub(str, end_byte + 1)
end

local function normalize_line_endings(str)
  return string.gsub(string.gsub(str, "\r\n", "\n"), "\r", "\n")
end

local function remove_empty_lines(str)
  local lines = {}
  for line in string.gmatch(str, "([^\n]*\n?)") do
    if #line > 1 then -- Keeps line if it's not just a newline character
      table.insert(lines, line)
    end
  end
  return table.concat(lines)
end

local function delete_comments(str: string, positions: CharPositions)
  -- Process ranges in reverse order to avoid changing indices of remaining ranges
  local ranges = {}

  for _, position in positions do
    table.insert(ranges, { position.start_byte, position.end_byte })
  end
  table.sort(ranges, function(a, b)
    return a[1] > b[1]
  end)

  for _, range in ipairs(ranges) do
    local start_byte, end_byte = table.unpack(range)
    str = delete_substring_by_bytes(str, start_byte, end_byte)
  end

  str = normalize_line_endings(str)

  local lines = {}
  for line in string.gmatch(str, "([^\n]*\n?)") do
    if #line > 1 then -- Keeps line if it's not just a newline character
      table.insert(lines, line)
    end
  end

  return table.concat(lines)
end

function bundler.bundle(entrypoint_path: string, keep_comment: boolean?, extra_headers: { string }?): string
  local luaurc = sys.luaurc() :: any
  local aliases = luaurc.aliases or {}
  local files = {}
  local extensions = { "", ".lua", ".luau", "/init.lua", "/init.luau" }

  local function process_file(file_path: string)
    local source = fs.readFile(file_path)

    local source_dir = folderOf(file_path)
    local original_src_hash = serde.hash("sha256", source)
    local write_offset = 0

    local obj = {
      original_src = source,
      src = source,
      hash = original_src_hash,
      path = file_path,
      metadata = fs.metadata(file_path),
    }

    if files[original_src_hash] then
      return files[original_src_hash]
    end

    local function handle_require(path: string, span: luaup.Span)
      if string.sub(path, 1, 6) ~= "@lune/" then
        path = fix_path(path, aliases, source_dir)

        for _, ext in extensions do
          local final_path = path .. ext
          if fs.isFile(final_path) then
            local processed = process_file(final_path)

            local hash = processed.hash
            local new_require = ` __LPM_REQUIRE("{hash}")`

            local start_byte = span.start.byte
            local stop_byte = span.finish.byte

            local original_size = stop_byte - start_byte
            local new_size = #new_require
            local offset = new_size - original_size

            local pre = string.sub(obj.src, 1, start_byte - 1 + write_offset)
            local suf = string.sub(obj.src, stop_byte + 1 + write_offset, #obj.src)
            obj.src = pre .. new_require .. suf

            write_offset += offset - 1

            break
          end
        end
      end
    end

    local function recurse(tbl)
      if tbl.kind == "call" then
        local ok, path, span = is_require(tbl.call)

        if ok then
          handle_require(path, span)
        else
          if tbl.call.lhs then
            recurse(tbl.call.lhs)
          end
        end
      else
        for _, v in tbl do
          if typeof(v) == "table" then
            recurse(v)
          end
        end
      end
    end

    local function recurseComment(tbl: any, data: CharPositions?)
      data = data or {} :: CharPositions
      if tbl.kind == "comment" then
        local span = tbl.span
        table.insert(data, {
          start_line = span.start.line,
          start_col = span.start.char,
          end_line = span.finish.line,
          end_col = span.finish.char,
          start_byte = span.start.byte,
          end_byte = span.finish.byte,
        })
      else
        for _, v in tbl do
          if typeof(v) == "table" then
            recurseComment(v, data)
          end
        end
      end

      return data
    end

    files[original_src_hash] = obj

    local parsed = luaup.ast.parse(source)
    recurse(parsed.ast)

    if not keep_comment then
      local originalParsed = luaup.ast.parse(obj.src)
      local DeletedCommentPositions = recurseComment(originalParsed.ast)
      if #DeletedCommentPositions > 0 then
        obj.src = delete_comments(obj.src, DeletedCommentPositions)
      end
    end
    return obj
  end

  local index = {}

  local entrypoint = process_file(entrypoint_path)

  local bundled = BUNDLE_HEADER

  local function write_header(file)
    local path = sys.normalisePath(file.path)
    local name = string.split(path, "/")
    bundled ..= header(
      `\n{name[#name]}\n\nPath: {path}\nHash: {file.hash}\nCreated: {file.metadata.createdAt:toIsoDate()}\nModified: {file.metadata.modifiedAt:toIsoDate()}\n`
    )
  end

  for hash, file in files do
    if keep_comment then
      table.insert(index, {
        ln = get_lines(bundled),
        file = file,
      })
      write_header(file)
    end
    bundled ..= `\n__LPM_MODULES["{hash}"] = function()\n\n{file.src}\n\nend\n\n`
  end

  bundled ..= entrypoint.src

  if not keep_comment then
    local INDEX = `--!nocheck\n--!nolint\n`
    return INDEX .. bundled
  end

  local index_str = ""

  local offset = get_lines(BUNDLE_INDEX) + #index - 1

  for _, entry in index do
    index_str ..= `\n  * Line {entry.ln + offset} = {sys.normalisePath(entry.file.path)} ({entry.file.hash})`
  end

  return string.format(BUNDLE_INDEX, index_str) .. bundled
end

return bundler
