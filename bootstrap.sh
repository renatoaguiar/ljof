#!/usr/bin/env bash
set -e

git submodule init
git submodule update

(cd deps/turbo && make)
(cd deps/luajit-2.0 && make XCFLAGS+=" -DLUAJIT_ENABLE_LUA52COMPAT")
