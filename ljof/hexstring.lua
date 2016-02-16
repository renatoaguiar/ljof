local bit = require "bit"
local hexstring = {}

function hexstring.tostring(bytes)
   if string.len(bytes) == 0 then return "" end
   local str = string.format("%02x", string.byte(bytes, 1))
   for i=2,string.len(bytes) do
      str = string.format("%s:%02x", str, string.byte(bytes, i))
   end
   return str
end

function hexstring.tonumber(bytes)
   local n = string.byte(bytes)
   n = bit.bor(bit.lshift(n, 8), string.byte(bytes, 2))
   n = bit.bor(bit.lshift(n, 8), string.byte(bytes, 3))
   n = bit.bor(bit.lshift(n, 8), string.byte(bytes, 4))
   n = bit.bor(bit.lshift(n, 8), string.byte(bytes, 5))
   n = bit.bor(bit.lshift(n, 8), string.byte(bytes, 6))
   return n
end

return hexstring
