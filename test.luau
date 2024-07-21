local fs = require("@lune/fs")
local luaup = require("./src/dependencies/luaup")

type Parse = { ast: luaup.Ast, success: boolean }

local parsed: Parse = luaup.ast.parse(fs.readFile("./src/libs/bundler.luau")) :: any

local tokens = luaup.ast.tokens(parsed.ast)

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
local DeletedCommentPositions: CharPositions = {}

local function recurse(tbl: any)
  if tbl.kind == "comment" then
    local span = tbl.span
    table.insert(DeletedCommentPositions, {
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
        recurse(v)
      end
    end
  end
end

local str = fs.readFile("./src/libs/bundler.luau")

local function split_string_by_lines(str: string)
  local lines = {}
  for line in string.gmatch(str, "[^\r\n]*[\r\n]?") do
    if #line > 0 then
      table.insert(lines, line)
    end
  end
  return lines
end

local function delete_substring_by_bytes(str: string, start_byte: number, end_byte: number)
  -- Ensure start_byte and end_byte are within the bounds of the string
  start_byte = math.max(start_byte, 1)
  end_byte = math.min(end_byte, #str)

  -- Return the modified string with the specified byte range removed
  return str:sub(0, start_byte - 1) .. str:sub(end_byte + 1)
end

local function normalize_line_endings(str)
  -- Replace \r\n or \r with \n
  return str:gsub("\r\n", "\n"):gsub("\r", "\n")
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

local function delete_multiple_substrings_by_bytes(str: string, positions: CharPositions)
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

  str = str:gsub("\r\n", "\n"):gsub("\r", "\n")

  local lines = {}
  for line in string.gmatch(str, "([^\n]*\n?)") do
    if #line > 1 then -- Keeps line if it's not just a newline character
      table.insert(lines, line)
    end
  end

  return table.concat(lines)
end

recurse(parsed.ast)

print(delete_multiple_substrings_by_bytes(str, DeletedCommentPositions))
