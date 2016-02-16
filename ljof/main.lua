local ioloop = require "turbo.ioloop"
local Controller = require "ljof.controller"

-- TODO: Turn it into a parameter
dofile("ljof/routing/l2learning.lua")
-- dofile("ljof/routing/fullrouting.lua")

local controller = Controller:new(nil, nil, 1024*1024)
controller:listen(6633)
ioloop.instance():start()
