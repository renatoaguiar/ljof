local class = require "middleclass"
local log = require "ljof.log"
local ofp = require "ljof.ofp"

local Switch = class("Switch")

local function read_msg(switch, bytes)
    if switch.stream:closed() then
        return
    end
    if switch.msg_header == nil then
        local header = ofp.parse_header(bytes)
        log.debug("New message: " .. header.type)
        if header.length == 8 then
            switch:read_message(ofp.parse(header, nil))
            switch.stream:read_bytes(8, read_msg, switch)
        else
            switch.msg_header = header
            switch.stream:read_bytes(header.length - 8, read_msg, switch)
        end
    else
        local msg = ofp.parse(switch.msg_header, bytes)
        log.debug("Parsing payload: " .. switch.msg_header.type)
        switch:read_message(msg)
        switch.msg_header = nil
        switch.stream:read_bytes(8, read_msg, switch)
    end
end

function Switch:initialize(stream)
    self.stream = stream
    log.debug("Sending hello...")
    self.stream:write(ofp.hello())
    self.stream:read_bytes(8, read_msg, self)
end

function Switch:read_message(msg)
    if msg.header.type == "echo_request" then
        self.stream:write(ofp.echo_reply(msg.payload))
    elseif msg.header.type == "packet_in" then
        log.debug("Got packet_in.")
        local flow = ofp.extract_flow(msg.data, msg.in_port)
        status, errormsg = pcall(packet_in, self, msg.buffer_id, flow)
        if status == false then
            log.error("packetin error: " .. errormsg)
        end
    elseif msg.header.type == "features_reply" then
        log.debug("Got features_reply.")
        self.dpid = msg.datapath_id
        self.features = msg
        switch_ready(self)
    elseif msg.header.type == "hello" then
        log.debug("Got hello. Sending features request...")
        self.stream:write(ofp.features_request())
    end
end

function Switch:add_simple_flow(flow, buffer_id, out_port, idle_timeout)
      local match = { dl_src = flow.dl_src, dl_dst = flow.dl_dst,
                      in_port = flow.in_port }
      local msg = ofp.flow_mod("modify", match, { output = out_port },
                               { idle_timeout = idle_timeout,
                                 buffer_id = buffer_id })
      self.stream:write(ofp.flow_mod("modify", match, { output = out_port },
                                     { idle_timeout = idle_timeout,
                                       buffer_id = buffer_id }))
end

function Switch:packet_out(in_port, buffer_id, out_port)
    self.stream:write(ofp.packet_out(buffer_id, in_port, out_port))
end

return Switch
