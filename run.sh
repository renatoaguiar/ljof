#!/bin/sh

export LUA_PATH="./?.lua;./deps/turbo/?.lua;./deps/middleclass/?.lua"
export LD_LIBRARY_PATH="./deps/turbo"

exec ./deps/luajit-2.0/src/luajit ./ljof/main.lua
