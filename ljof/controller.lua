local Switch = require "ljof.switch"
local log = require "ljof.log"
local turbo = require "turbo"

local Controller = class("Controller", turbo.tcpserver.TCPServer)

log.verbose = true

function Controller:handle_stream(stream, address)
    log.info("New client: " .. address)
    Switch:new(stream)
end

return Controller
