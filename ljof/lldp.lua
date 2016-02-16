local bit = require "bit"
local NetBuf = require "ljof.netbuf"

local lldp = {}

function lldp.pack_tl(type, length)
    -- TODO: Check boundaries
    return bit.bor(bit.lshift(type, 9), length)
end

function lldp.pack(dpid, port)
    local mac_bytes = string.sub(dpid, 3)
    local buf = NetBuf:new(152)
    -- Ethernet
    buf:put_bytes("\x01\x80\xc2\x00\x00\x0e")
    buf:put_bytes(mac_bytes)
    buf:put(0x88cc, 2)
    -- Chassis
    buf:put(lldp.pack_tl(1, 9), 2)
    buf:put(7)
    buf:put_bytes(dpid)
    -- Port
    buf:put(lldp.pack_tl(2, 3), 2)
    buf:put(7)
    buf:put(port, 2)
    -- TTL
    buf:put(lldp.pack_tl(3, 2), 2)
    buf:put(120, 2)
    -- End
    buf:put(0, 2)
    return tostring(buf)
end

function lldp.unpack(payload)
    local buf = NetBuf:new(#payload, payload)
    -- Ethernet
    local dl_src = buf:get_bytes(6)
    local dl_dst = buf:get_bytes(6)
    local dl_type = buf:get(2)
    -- Chassis
    local chassis_tl = buf:get(2) -- TODO: Unpack and check TL
    local chassis_subtype = buf:get()
    local chassis_value = buf:get_bytes(8)
    -- Port
    local port_tl = buf:get(2) -- TODO: Unpack and check TL
    local port_subtype = buf:get()
    local port_value = buf:get(2)
    -- TTL
    local ttl_tl = buf:get(2) -- TODO: Unpack and check TL
    local ttl_value = buf:get(2)
    -- End
    local end_tl = buf:get(2) -- TODO: Unpack and check TL
    return chassis_value, port_value
end

return lldp
