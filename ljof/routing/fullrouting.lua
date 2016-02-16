local lldp = require "ljof.lldp"
local hexstring = require "ljof.hexstring"

local topology = {}
local hosts = {}
local switches = {}

local OFPP_MAX = 0xff00

local function send_lldp(sw)
   for _,port in ipairs(sw.features.ports) do
      if type(port.port_no) == "number" then
         print("Sending LLDP for port " .. tostring(port.port_no) ..
                  " of switch " .. hexstring.tostring(sw.dpid))
         local f = lldp.pack(sw.dpid, port.port_no)
         sw:packet_out("local", f, port.port_no)
      end
   end
end

local function get_route(src, dst)
   if hosts[src] == nil then
      print(">> Unable to get route: unknown source " ..
               hexstring.tostring(src) .. ".")
      return nil
   elseif hosts[dst] == nil then
      print(">> Unable to get route: unknown destination '" ..
               hexstring.tostring(dst) .. "'.")
      return nil
   end

   local sw_src = hosts[src].dpid
   local sw_dst = hosts[dst].dpid

   print("Source switch: " .. hexstring.tostring(sw_src))
   print("Destination switch: " .. hexstring.tostring(sw_dst))

   local visited = {}
   local nodes = {}
   local parent = {}
   local flag = false

   -- BFS search
   local u = sw_src
   while u ~= nil do
      visited[u] = true
      for v,_ in pairs(topology[u]) do
         if not visited[v] then
            table.insert(nodes, v)
            parent[v] = u
         end
         if v == sw_dst then
            flag = true
            break
         end
      end
      if flag then
         break
      end
      u = table.remove(nodes, 1)
   end

   if not flag then
      return nil
   end

   -- Compute route
   local n = sw_dst
   local route = { [sw_dst] = hosts[dst].port }
   repeat
      local pn = parent[n]
      route[pn] = topology[pn][n]
      n = pn
   until n == sw_src

   return route
end

function switch_ready(sw)
   print(">> New switch connected: " .. hexstring.tostring(sw.dpid))
   switches[sw.dpid] = sw
   topology[sw.dpid] = {}

   send_lldp(sw)
end

function packet_in(sw, buffer_id, flow)
   print(">> New packet (" .. buffer_id .. ") received from " ..
            hexstring.tostring(sw.dpid))

   -- LLDP
   if flow.dl_type == 0x88cc then
      local dpid, port
      print("LLDP", hexstring.tostring(sw.dpid), flow.in_port)
      dpid, port = lldp.unpack(flow.data)
      print(">> " .. hexstring.tostring(dpid) .. ", " .. tostring(port))
      topology[sw.dpid][dpid] = flow.in_port
      topology[dpid][sw.dpid] = port
      return
   end

   if hosts[flow.dl_src] == nil then
      print("", "Learning " .. hexstring.tostring(flow.dl_src) .. " in port " ..
               tostring(flow.in_port) .. " of switch " ..
               hexstring.tostring(sw.dpid))
      hosts[flow.dl_src] = { dpid = sw.dpid, port = flow.in_port }
   end

   -- Ethernet broadcast.
   if flow.dl_dst == "\xff\xff\xff\xff\xff\xff" then
      sw:packet_out(flow.in_port, buffer_id, "all")
      return
   end

   local route = get_route(flow.dl_src, flow.dl_dst)

   if route == nil then
      print("", "Flooding")
      sw:packet_out(flow.in_port, buffer_id, "all")
   else
      local idle_timeout = 10
      print("", "Routing")
      for dpid,port in pairs(route) do
         local switch = switches[dpid]
         if switch == sw then
            print(hexstring.tostring(dpid), port, buffer_id)
            switch:add_simple_flow(flow, buffer_id, port, idle_timeout)
         else
            print(hexstring.tostring(dpid), port, nil)
            switch:add_simple_flow(flow, nil, port, idle_timeout)
         end
      end
   end
end
