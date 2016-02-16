local log = {}

function log.error(msg)
    io.stderr:write("[E|" .. os.date() .. "] ")
    io.stderr:write(msg)
    io.stderr:write("\n")
end

function log.warn(msg)
    io.write("[W|" .. os.date() .. "] ")
    io.write(msg)
    io.write("\n")
end

function log.info(msg)
    io.write("[I|" .. os.date() .. "] ")
    io.write(msg)
    io.write("\n")
end

function log.debug(msg)
    if log.verbose then
        io.stderr:write("[D|" .. os.date() .. "] ")
        io.stderr:write(msg)
        io.stderr:write("\n")
    end
end

return log
