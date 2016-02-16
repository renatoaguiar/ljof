local hexstring = require "ljof.hexstring"

function switch_ready(sw)
   sw.l2_map = {}
end

function packet_in(sw, buffer_id, flow)
    sw.l2_map[hexstring.tonumber(flow.dl_src)] = flow.in_port
    local out_port = sw.l2_map[hexstring.tonumber(flow.dl_dst)]
    if out_port == nil then
        sw:packet_out(flow.in_port, buffer_id, "all")
    else
        sw:add_simple_flow(flow, nil, out_port, 10)
        sw:packet_out(flow.in_port, buffer_id, out_port)
    end
end
