--!strict
--!native

-- zzlib.luau - zlib decompression in Luau

-- Copyright (c) 2016-2024 Francois Galea <fgalea at free.fr>
-- This program is free software. It comes without any warranty, to
-- the extent permitted by applicable law. You can redistribute it
-- and/or modify it under the terms of the Do What The **** You Want
-- To Public License, Version 2, as published by Sam Hocevar. See
-- the COPYING file for more details.

-- Above license have been modified to be compatible with Roblox's terms of service.

local inflate = {}

local band, bnot, bxor, lshift, rshift =
  bit32.band, bit32.bnot, bit32.bxor, bit32.lshift, bit32.rshift

type BitStreamImpl = {
  __index: BitStreamImpl,

  flushb: (self: BitStream, n: number) -> (),
  next_byte: (self: BitStream) -> number,
  peekb: (self: BitStream, n: number) -> number,
  getb: (self: BitStream, n: number) -> number,
  getv: (self: BitStream, hufftable: HuffTable, n: number) -> number,
}

type BitStreamProto = {
  buf: string,
  len: number,
  pos: number,
  b: number,
  n: number,
}

export type BitStream = typeof(setmetatable({} :: BitStreamProto, {} :: BitStreamImpl))
export type HuffTable = { [number]: number }

function inflate.bitstream_init(data: string): BitStream
  local bs = {} :: BitStreamImpl
  bs.__index = bs

  -- get rid of n first bits
  function bs.flushb(self: BitStream, n: number)
    self.n -= n
    self.b = rshift(self.b, n)
  end
  -- returns the next byte from the stream, excluding any half-read bytes
  function bs.next_byte(self: BitStream): number
    self.pos += 1
    return string.byte(self.buf, self.pos - 1)
  end
  -- peek a number of n bits from stream
  function bs.peekb(self: BitStream, n: number): number
    while self.n < n do
      self.b += lshift(self:next_byte(), self.n)
      self.n += 8
    end
    return band(self.b, lshift(1, n) - 1)
  end
  -- get a number of n bits from stream
  function bs.getb(self: BitStream, n: number): number
    local ret = self:peekb(n)
    self.n -= n
    self.b = rshift(self.b, n)
    return ret
  end
  -- get next variable-size of maximum size=n element from stream, according to Huffman table
  function bs.getv(self: BitStream, hufftable: HuffTable, n: number): number
    local e = hufftable[self:peekb(n)]
    local len = band(e, 15)
    local ret = rshift(e, 4)
    self.n -= len
    self.b = rshift(self.b, len)
    return ret
  end

  return setmetatable(
    {
      buf = data, -- character buffer
      len = #data, -- length of character buffer
      pos = 1, -- position in char buffer, next to be read
      b = 0, -- bit buffer
      n = 0, -- number of bits in buffer
    } :: BitStreamProto,
    bs :: BitStreamImpl
  )
end

local function hufftable_create(depths: { [number]: number }): (HuffTable, number)
  local nvalues = #depths
  local nbits = 1
  local bl_count = {}
  local next_code = {}
  for i = 1, nvalues do
    local d = depths[i]
    if d > nbits then
      nbits = d
    end
    bl_count[d] = (bl_count[d] or 0) + 1
  end
  local table = {}
  local code = 0
  bl_count[0] = 0
  for i = 1, nbits do
    code = (code + (bl_count[i - 1] or 0)) * 2
    next_code[i] = code
  end
  for i = 1, nvalues do
    local len = depths[i] or 0
    if len > 0 then
      local e = (i - 1) * 16 + len
      local code = next_code[len]
      local rcode = 0
      for j = 1, len do
        rcode += lshift(band(1, rshift(code, j - 1)), len - j)
      end
      for j = 0, 2 ^ nbits - 1, 2 ^ len do
        table[j + rcode] = e
      end
      next_code[len] += 1
    end
  end
  return table, nbits
end

local function block_loop(
  out: { number },
  bs: BitStream,
  nlit: number,
  ndist: number,
  littable: HuffTable,
  disttable: HuffTable
)
  local lit
  repeat
    lit = bs:getv(littable, nlit)
    if lit < 256 then
      table.insert(out, lit)
    elseif lit > 256 then
      local nbits = 0
      local size = 3
      local dist = 1
      if lit < 265 then
        size += lit - 257
      elseif lit < 285 then
        nbits = rshift(lit - 261, 2)
        size += lshift(band(lit - 261, 3) + 4, nbits)
      else
        size = 258
      end
      if nbits > 0 then
        size += bs:getb(nbits)
      end
      local v = bs:getv(disttable, ndist)
      if v < 4 then
        dist += v
      else
        nbits = rshift(v - 2, 1)
        dist += lshift(band(v, 1) + 2, nbits)
        dist += bs:getb(nbits)
      end
      local p = #out - dist + 1
      while size > 0 do
        table.insert(out, out[p])
        p += 1
        size = size - 1
      end
    end
  until lit == 256
end

local function block_dynamic(out: { number }, bs: BitStream)
  local order = { 17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16 }
  local hlit = 257 + bs:getb(5)
  local hdist = 1 + bs:getb(5)
  local hclen = 4 + bs:getb(4)
  local depths = {}
  for i = 1, hclen do
    local v = bs:getb(3)
    depths[order[i]] = v
  end
  for i = hclen + 1, 19 do
    depths[order[i]] = 0
  end
  local lengthtable, nlen = hufftable_create(depths)
  local i = 1
  while i <= hlit + hdist do
    local v = bs:getv(lengthtable, nlen)
    if v < 16 then
      depths[i] = v
      i += 1
    elseif v < 19 then
      local nbt = { 2, 3, 7 }
      local nb = nbt[v - 15]
      local c = 0
      local n = 3 + bs:getb(nb)
      if v == 16 then
        c = depths[i - 1]
      elseif v == 18 then
        n += 8
      end
      for _ = 1, n do
        depths[i] = c
        i += 1
      end
    else
      error(`wrong entry in depth table for literal/length alphabet: {v}`)
    end
  end
  local litdepths = {}
  for i = 1, hlit do
    table.insert(litdepths, depths[i])
  end
  local littable, nlit = hufftable_create(litdepths)
  local distdepths = {}
  for i = hlit + 1, #depths do
    table.insert(distdepths, depths[i])
  end
  local disttable, ndist = hufftable_create(distdepths)
  block_loop(out, bs, nlit, ndist, littable, disttable)
end

local function block_static(out: { number }, bs: BitStream)
  local cnt = { 144, 112, 24, 8 }
  local dpt = { 8, 9, 7, 8 }
  local depths = {}
  for i = 1, 4 do
    local d = dpt[i]
    for _ = 1, cnt[i] do
      table.insert(depths, d)
    end
  end
  local littable, nlit = hufftable_create(depths)
  depths = {}
  for i = 1, 32 do
    depths[i] = 5
  end
  local disttable, ndist = hufftable_create(depths)
  block_loop(out, bs, nlit, ndist, littable, disttable)
end

local function block_uncompressed(out: { number }, bs: BitStream)
  bs:flushb(band(bs.n, 7))
  local len = bs:getb(16)
  if bs.n > 0 then
    error("Unexpected.. should be zero remaining bits in buffer.")
  end
  local nlen = bs:getb(16)
  if bxor(len, nlen) ~= 65535 then
    error("LEN and NLEN don't match")
  end
  for _ = 1, len do
    table.insert(out, bs:next_byte())
  end
end

function inflate.main(bs: BitStream): { number }
  local last, type
  local output = {}
  repeat
    last = bs:getb(1)
    type = bs:getb(2)
    if type == 0 then
      block_uncompressed(output, bs)
    elseif type == 1 then
      block_static(output, bs)
    elseif type == 2 then
      block_dynamic(output, bs)
    else
      error("unsupported block type")
    end
  until last == 1
  bs:flushb(band(bs.n, 7))
  return output
end

local crc32_table
function inflate.crc32(s: string, crc: number?): number
  if not crc32_table then
    crc32_table = {}
    for i = 0, 255 do
      local r = i
      for _ = 1, 8 do
        r = bxor(rshift(r, 1), band(0xedb88320, bnot(band(r, 1) - 1)))
      end
      crc32_table[i] = r
    end
  end
  local new_crc = bnot(crc or 0)
  for i = 1, #s do
    local c = string.byte(s, i)
    new_crc = bxor(crc32_table[bxor(c, band(new_crc, 0xff))], rshift(new_crc, 8))
  end
  new_crc = bnot(new_crc)
  if new_crc < 0 then
    -- in Lua < 5.2, sign extension was performed
    new_crc += 4294967296
  end
  return new_crc
end

return inflate
