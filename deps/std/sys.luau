--!nocheck

local process = require("./process")
local stdio = require("@lune/stdio")

local sys = {}

local IS_WIN = process.os == "windows"

function sys.standardise_path(path: string): string
  return string.gsub(string.gsub(path, "\\", "/"), "/%./", "/")
end

function sys.remove_trailing_slash(str: string): string
  return string.gsub(str, "/$", "")
end

function sys.homedir(): string
  local home = sys.standardise_path(process.env[IS_WIN and "USERPROFILE" or "HOME"])

  if string.sub(home, -1) == "/" then
    home = string.sub(home, 1, #home - 1)
  end

  return sys.remove_trailing_slash(home)
end

function sys.user_info()
  local username = sys.standardise_path(process.env["USERNAME"] or process.env["USER"])
  local homedir = process.env[IS_WIN and "USERPROFILE" or "HOME"]

  return {
    username = username,
    homedir = homedir,
  }
end

function sys.normalize_path(str: string): string
  return string.gsub(string.gsub(str, "\\", "/"), "/%./", "/")
end

function sys.globtopattern(g: string)
  local p = "^" -- pattern being built
  local i = 0 -- index in g
  local c -- char at index i in g.

  -- unescape glob char
  local function unescape()
    if c == "\\" then
      i = i + 1
      c = g:sub(i, i)
      if c == "" then
        p = "[^]"
        return false
      end
    end
    return true
  end

  -- escape pattern char
  local function escape(c)
    return c:match("^%w$") and c or `%{c}`
  end

  -- Convert tokens at end of charset.
  local function charset_end()
    while 1 do
      if c == "" then
        p = "[^]"
        return false
      elseif c == "]" then
        p = p .. "]"
        break
      else
        if not unescape() then
          break
        end
        local c1 = c
        i = i + 1
        c = g:sub(i, i)
        if c == "" then
          p = "[^]"
          return false
        elseif c == "-" then
          i = i + 1
          c = g:sub(i, i)
          if c == "" then
            p = "[^]"
            return false
          elseif c == "]" then
            p = p .. escape(c1) .. "%-]"
            break
          else
            if not unescape() then
              break
            end
            p = p .. escape(c1) .. "-" .. escape(c)
          end
        elseif c == "]" then
          p = p .. escape(c1) .. "]"
          break
        else
          p = p .. escape(c1)
          i = i - 1 -- put back
        end
      end
      i = i + 1
      c = g:sub(i, i)
    end
    return true
  end

  -- Convert tokens in charset.
  local function charset()
    i = i + 1
    c = g:sub(i, i)
    if c == "" or c == "]" then
      p = "[^]"
      return false
    elseif c == "^" or c == "!" then
      i = i + 1
      c = g:sub(i, i)
      if c == "]" then
        -- ignored
      else
        p = p .. "[^"
        if not charset_end() then
          return false
        end
      end
    else
      p = p .. "["
      if not charset_end() then
        return false
      end
    end
    return true
  end

  -- Convert tokens.
  while 1 do
    i = i + 1
    c = g:sub(i, i)
    if c == "" then
      p = p .. "$"
      break
    elseif c == "?" then
      p = p .. "."
    elseif c == "*" then
      p = p .. ".*"
    elseif c == "[" then
      if not charset() then
        break
      end
    elseif c == "\\" then
      i = i + 1
      c = g:sub(i, i)
      if c == "" then
        p = p .. "\\$"
        break
      end
      p = p .. escape(c)
    else
      p = p .. escape(c)
    end
  end
  return p
end

do
  local split_cwd = sys.standardise_path(process.cwd):gsub("/$", ""):split("/")
  sys.cwd_name = split_cwd[#split_cwd]
end

return sys
