local ffi = require "ffi"

local class = require "middleclass"

local NetBuf = class("NetBuf")

function NetBuf:initialize(max_size, data)
   if data == nil then
      self.data = ffi.new("uint8_t[?]", max_size)
   else
      self.data = ffi.cast("uint8_t *", data)
   end
   self.pos = 0
   self.max_size = max_size
end

function NetBuf:__len()
    return self.pos
end

function NetBuf:__tostring()
   return ffi.string(self.data, #self)
end

function NetBuf:put(value, length)
    local lastpos = (length or 1) - 1
    for i=0,lastpos do
        self.data[self.pos+i] = bit.band(0xff, bit.rshift(value, 8*(lastpos-i)))
    end
    self.pos = self.pos + lastpos + 1
end

function NetBuf:get(length)
    local lastpos = (length or 1) - 1
    local value = 0
    for i=0,lastpos do
        value = bit.bor(bit.lshift(value, 8), self.data[self.pos+i])
    end
    self.pos = self.pos + lastpos + 1
    return value
end

function NetBuf:put_bytes(bytes)
    ffi.copy(self.data + self.pos, bytes, #bytes)
    self.pos = self.pos + #bytes
end

function NetBuf:get_bytes(length)
    local bytes = ffi.new("uint8_t[?]", length)
    ffi.copy(bytes, self.data + self.pos, length)
    self.pos = self.pos + length
    return ffi.string(bytes, length)
end

function NetBuf:skip(length)
    self.pos = self.pos + (length or 1)
end

return NetBuf
