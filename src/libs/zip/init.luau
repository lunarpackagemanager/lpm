--!native
--!nocheck
--
-- zzlib.luau - zlib decompression in Luau

-- Copyright (c) 2016-2024 Francois Galea <fgalea at free.fr>
-- Copyright (c) 2024 xhayper
-- Copyright (c) 2024 lune-package
-- This program is free software. It comes without any warranty, to
-- the extent permitted by applicable law. You can redistribute it
-- and/or modify it under the terms of the Do What The **** You Want
-- To Public License, Version 2, as published by Sam Hocevar. See
-- the COPYING file for more details.

-- Above license have been modified to be compatible with Roblox's terms of service.

local infl = require("./inflate")

local band, rshift = bit32.band, bit32.rshift

local zzlib = {}

local function arraytostr(array: { number }): string
  local tmp = {}
  local size = #array
  local pos = 1
  local imax = 1
  while size > 0 do
    local bsize = size >= 2048 and 2048 or size
    local s = string.char(table.unpack(array, pos, pos + bsize - 1))
    pos += bsize
    size -= bsize
    local i = 1
    while tmp[i] do
      s = tmp[i] .. s
      tmp[i] = nil
      i += 1
    end
    if i > imax then
      imax = i
    end
    tmp[i] = s
  end
  local str = ""
  for i = 1, imax do
    if tmp[i] then
      str = tmp[i] .. str
    end
  end
  return str
end

local function inflate_gzip(bs: infl.BitStream): string
  local id1, id2, cm, flg = bs.buf:byte(1, 4)
  if id1 ~= 31 or id2 ~= 139 then
    error("invalid gzip header")
  end
  if cm ~= 8 then
    error("only deflate format is supported")
  end
  bs.pos = 11
  if band(flg, 4) ~= 0 then
    local xl1, xl2 = bs.buf.byte(tostring(bs.pos), bs.pos + 1)
    local xlen = xl2 * 256 + xl1
    bs.pos = bs.pos + xlen + 2
  end
  if band(flg, 8) ~= 0 then
    local pos = bs.buf:find("\0", bs.pos) or bs.pos
    bs.pos = pos + 1
  end
  if band(flg, 16) ~= 0 then
    local pos = bs.buf:find("\0", bs.pos) or bs.pos
    bs.pos = pos + 1
  end
  if band(flg, 2) ~= 0 then
    -- TODO: check header CRC16
    bs.pos += 2
  end
  local result = arraytostr(infl.main(bs))
  local crc = bs:getb(8) + 256 * (bs:getb(8) + 256 * (bs:getb(8) + 256 * bs:getb(8)))
  if crc ~= infl.crc32(result) then
    error("checksum verification failed")
  end
  return result
end

-- compute Adler-32 checksum
local function adler32(s: string): number
  local s1 = 1
  local s2 = 0
  for i = 1, #s do
    local c = s:byte(i)
    s1 = (s1 + c) % 65521
    s2 = (s2 + s1) % 65521
  end
  return s2 * 65536 + s1
end

local function inflate_zlib(bs: infl.BitStream): string
  local cmf = bs.buf:byte(1)
  local flg = bs.buf:byte(2)
  if (cmf * 256 + flg) % 31 ~= 0 then
    error("zlib header check bits are incorrect")
  end
  if band(cmf, 15) ~= 8 then
    error("only deflate format is supported")
  end
  if rshift(cmf, 4) ~= 7 then
    error("unsupported window size")
  end
  if band(flg, 32) ~= 0 then
    error("preset dictionary not implemented")
  end
  bs.pos = 3
  local result = arraytostr(infl.main(bs))
  local adler = ((bs:getb(8) * 256 + bs:getb(8)) * 256 + bs:getb(8)) * 256 + bs:getb(8)
  if adler ~= adler32(result) then
    error("checksum verification failed")
  end
  return result
end

local function inflate_raw(buf: string, offset: number?, crc: number?): string
  local bs = infl.bitstream_init(buf)
  bs.pos = offset or 1
  local result = arraytostr(infl.main(bs))
  if crc and crc ~= infl.crc32(result) then
    error("checksum verification failed")
  end
  return result
end

local function readIntLittleEndian2(str: string, pos: number)
  local a, b = str:byte(pos, pos + 1)
  return b * 256 + a
end

local function readIntLittleEndian4(str: string, pos: number)
  local a, b, c, d = str:byte(pos, pos + 3)
  return ((d * 256 + c) * 256 + b) * 256 + a
end

local function nextfile(buf: string, p: number): (number, string, number, number, number, number)
  if readIntLittleEndian4(buf, p) ~= 0x02014b50 then
    -- end of central directory list
    return
  end
  -- local flag = readIntLittleEndian2(buf,p+8)
  local packed = readIntLittleEndian2(buf, p + 10) ~= 0
  local crc = readIntLittleEndian4(buf, p + 16)
  local namelen = readIntLittleEndian2(buf, p + 28)
  local name = buf:sub(p + 46, p + 45 + namelen)
  local offset = readIntLittleEndian4(buf, p + 42) + 1
  p = p + 46 + namelen + readIntLittleEndian2(buf, p + 30) + readIntLittleEndian2(buf, p + 32)
  if readIntLittleEndian4(buf, offset) ~= 0x04034b50 then
    error("invalid local header signature")
  end
  local size = readIntLittleEndian4(buf, offset + 18)
  local extlen = readIntLittleEndian2(buf, offset + 28)
  offset = offset + 30 + namelen + extlen
  return p, name, offset, size, packed, crc
end

function zzlib.files(buf: string)
  local p = #buf - 21
  if readIntLittleEndian4(buf, p) ~= 0x06054b50 then
    return nextfile, nil, nil
  end
  local cdoffset = readIntLittleEndian4(buf, p + 16) + 1
  return nextfile, buf, cdoffset
end

function zzlib.gunzip(str: string): string
  return inflate_gzip(infl.bitstream_init(str))
end

function zzlib.inflate(str: string): string
  return inflate_zlib(infl.bitstream_init(str))
end

function zzlib.unzip(input: string, offset: string | number?, crc: number?)
  if type(offset) == "number" then
    -- mode 1: unpack data from specified position in zip file
    return inflate_raw(input, offset, crc)
  end
  -- mode 2: search and unpack file from zip file
  local start = string.find(input, "PK\5\6")
  if start then
    input = string.sub(input, 1, start + 19) .. "\0\0"
  end
  local filename = offset
  for _, name, offset, size, packed, crc in zzlib.files(input) do
    if name == filename then
      local result
      if not packed then
        -- no compression
        result = string.sub(input, offset, offset + size - 1)
      else
        -- DEFLATE compression
        result = inflate_raw(input, offset, crc)
      end
      return result
    end
  end

  error("file '" .. filename .. "' not found in ZIP archive")
end

zzlib.inflate_raw = inflate_raw

return zzlib
