local bit = require "bit"

local NetBuf = require "ljof.netbuf"

local ofp = {}

ofp.types = { [0] = "hello", "error", "echo_request", "echo_reply", "vendor",
              "features_request", "features_reply", "get_config_request",
              "get_config_reply", "set_config", "packet_in", "flow_removed",
              "port_status", "packet_out", "flow_mod", "port_mod",
              "stats_request", "stats_reply", "barrier_request",
              "barrier_reply", "queue_get_config_request",
              "queue_get_config_reply" }

local function port_tonumber(port)
   if     port == "in_port"    then return 0xfff8
   elseif port == "table"      then return 0xfff9
   elseif port == "normal"     then return 0xfffa
   elseif port == "flood"      then return 0xfffb
   elseif port == "all"        then return 0xfffc
   elseif port == "controller" then return 0xfffd
   elseif port == "local"      then return 0xfffe
   elseif port == "none"       then return 0xffff
   else return port end
end

local function port_tostring(port)
   if     port == 0xfff8 then return "in_port"
   elseif port == 0xfff9 then return "table"
   elseif port == 0xfffa then return "normal"
   elseif port == 0xfffb then return "flood"
   elseif port == 0xfffc then return "all"
   elseif port == 0xfffd then return "controller"
   elseif port == 0xfffe then return "local"
   elseif port == 0xffff then return "none"
   else return port end
end

function netbuf_put_header(buf, msg_type, xid, size)
   buf:put(0x01) -- version
   buf:put(msg_type)
   buf:put(size or buf.max_size, 2)
   buf:put(xid or 0, 4)
end

function netbuf_put_action_output(buf, port, max_len)
   buf:put(0, 2) -- OFPAT_OUTPUT
   buf:put(8, 2)
   buf:put(port_tonumber(port), 2)
   buf:put(max_len or 0, 2)
end

function netbuf_put_match(buf, match)
   local field_masks = { in_port = bit.lshift(1, 0), dl_vlan = bit.lshift(1, 1),
                         dl_src = bit.lshift(1, 2), dl_dst = bit.lshift(1, 3),
                         dl_type = bit.lshift(1, 4), nw_proto = bit.lshift(1, 5),
                         tp_src = bit.lshift(1, 6), tp_dst = bit.lshift(1, 7),
                         nw_src = bit.lshift(bit.rshift(0xff, 2), 8),
                         nw_dst = bit.lshift(bit.rshift(0xff, 2), 14),
                         dl_vlan_pcp = bit.lshift(1, 20), nw_tos = bit.lshift(1, 21) }
   local wildcards = 0xffffffff
   for field,_ in pairs(match) do
      wildcards = bit.band(wildcards, bit.bnot(field_masks[field]))
   end
   buf:put(wildcards, 4)
   buf:put(port_tonumber(match.in_port or "none"), 2)
   buf:put_bytes(match.dl_src or "\x00\x00\x00\x00\x00\x00")
   buf:put_bytes(match.dl_dst or "\x00\x00\x00\x00\x00\x00")
   buf:put(match.dl_vlan or 0, 2)
   buf:put(match.dl_vlan_pcp or 0)
   buf:skip() -- pad
   buf:put(match.dl_type or 0, 2)
   buf:put(match.nw_tos or 0)
   buf:put(match.nw_proto or 0)
   buf:skip(2) -- pad
   buf:put(match.nw_src or 0, 4)
   buf:put(match.nw_dst or 0, 4)
   buf:put(match.tp_src or 0, 2)
   buf:put(match.tp_dst or 0, 2)
end

function ofp.hello()
   local msg = NetBuf:new(8)
   netbuf_put_header(msg, 0)
   return tostring(msg)
end

function ofp.features_request()
   local msg = NetBuf:new(8)
   netbuf_put_header(msg, 5)
   return tostring(msg)
end

function ofp.echo_reply(payload)
   local payload_len = 0
   if payload ~= nil then
      payload_len = #payload
   end
   local msg = NetBuf:new(8 + payload_len)
   netbuf_put_header(msg, 3)
   if payload_len > 0 then
      msg:put_bytes(payload)
   end
   return tostring(msg)
end

function ofp.packet_out(packet, in_port, out_port)
   local data, buffer_id

   if type(packet) == "number" then
      buffer_id = packet
   else
      buffer_id = -1
      data = packet
   end

   local msg_size = 24 -- 16 + 8
   if data ~= nil then
      msg_size = msg_size + #data
   end
   local msg = NetBuf:new(msg_size)

   netbuf_put_header(msg, 13)

   msg:put(buffer_id, 4)
   msg:put(port_tonumber(in_port), 2)
   msg:put(8, 2)

   netbuf_put_action_output(msg, out_port)

   if data ~= nil then
      msg:put_bytes(data)
   end

   return tostring(msg)
end

function ofp.parse_header(payload)
   local msg = NetBuf:new(#payload, payload)
   return {
      version = msg:get(),
      type = ofp.types[msg:get()],
      length = msg:get(2),
      xid = msg:get(4)
   }
end

local function netbuf_get_phy_port(msg)
   local port = {}
   port.port_no = port_tostring(msg:get(2))
   port.hw_addr = msg:get_bytes(6)
   port.name = msg:get_bytes(16)
   port.config = msg:get(4)
   port.state = msg:get(4)
   port.curr = msg:get(4)
   port.advertised = msg:get(4)
   port.supported = msg:get(4)
   port.peer = msg:get(4)
   return port
end

local function parse_features_reply(header, payload)
   local features = { header = header }
   local msg = NetBuf:new(#payload, payload)
   features.datapath_id = msg:get_bytes(8)
   features.n_buffers = msg:get(4)
   features.n_tables = msg:get()
   msg:skip(3) -- pad
   features.capabilities = msg:get(4)
   features.actions = msg:get(4)
   features.ports = {}
   local no_ports = (features.header.length - 32) / 48
   for i=1,no_ports do
      features.ports[i] = netbuf_get_phy_port(msg)
   end
   return features
end

local function parse_packet_in(header, payload)
   local packetin = { header = header }
   local msg = NetBuf:new(#payload, payload)
   local buffer_id = msg:get(4)
   if buffer_id ~= -1 then
      packetin.buffer_id = buffer_id
   end
   packetin.total_len = msg:get(2)
   packetin.in_port = port_tostring(msg:get(2))
   local reason = msg:get()
   if     reason == 0 then packetin.reason = "no match"
   elseif reason == 1 then packetin.reason = "action"
   else                    packetin.reason = reason
   end
   msg:skip() -- pad
   packetin.data = msg:get_bytes(packetin.header.length - 18)
   return packetin
end

function ofp.parse(header, payload)
   if header.type == "packet_in" then
      return parse_packet_in(header, payload)
   elseif header.type == "features_reply" then
      return parse_features_reply(header, payload)
   end
   return { header = header }
end

function ofp.extract_flow(data, in_port)
   local buf = NetBuf:new(#data, data)
   local flow = {}
   flow.data = data
   flow.in_port = in_port
   flow.dl_dst = buf:get_bytes(6)
   flow.dl_src = buf:get_bytes(6)
   flow.dl_type = buf:get(2)
   if flow.dl_type == 0x8100 then
      local tci = buf:get(2)
      flow.dl_vlan_pcp = bit.rshift(13)
      flow.dl_vlan = bit.band(tci, 0x0fff)
      flow.dl_type = buf:get(2)
   end
   -- TODO: Multiple VLAN tagging
   if flow.dl_type == 0x0800 then
      local ihl = bit.band(buf:get(), 0x0f)
      buf:skip(8)
      flow.nw_proto = buf:get()
      buf:skip(2)
      flow.nw_src = buf:get(4)
      flow.nw_dst = buf:get(4)
      if ihl > 5 then
         buf:skip((ihl - 5) * 4)
      end
   elseif flow.dl_type == 0x0806 then
      buf:skip(7)
      flow.nw_proto = buf:get()
      buf:skip(6)
      flow.nw_src = buf:get(4)
      buf:skip(6)
      flow.nw_dst = buf:get(4)
      return flow
   else
      return flow
   end
   if flow.nw_proto == 6 or flow.nw_proto == 17 then
      flow.tp_src = buf:get(2)
      flow.tp_dst = buf:get(2)
   elseif flow.nw_proto == 1 then
      flow.tp_src = buf:get()
      flow.icmp_type = flow.tp_src
      flow.tp_dst = buf:get()
      flow.icmp_code = flow.tp_dst
   end
   return flow
end

function ofp.flow_mod(command, match, actions, options)
   local commands = { add = 0, modify = 1, ["modify strict"] = 2, delete = 3,
                      ["delete strict"] = 4}
   local actions_size = { output = 8 }
   local msg_size = 72
   for action,_ in pairs(actions) do
      msg_size = msg_size + actions_size[action]
   end

   local msg = NetBuf:new(msg_size)

   netbuf_put_header(msg, 14)
   netbuf_put_match(msg, match)

   -- TODO: cookie uint64_t
   msg:put(0, 4)
   msg:put(0, 4)

   msg:put(commands[command], 2)
   msg:put(options.idle_timeout or 0, 2)
   msg:put(options.hard_timeout or 0, 2)
   msg:put(options.priority or 0, 2)
   msg:put(options.buffer_id or -1, 4)
   msg:put(port_tonumber(options.out_port or "none"), 2)

   -- TODO: decode flags as string array
   msg:put(options.flags or 0, 2)

   for action,param in pairs(actions) do
      if action == "output" then
         netbuf_put_action_output(msg, param)
      else
         error("Unknown action")
      end
   end

   return tostring(msg)
end

return ofp
