local func = require("pomelo.functions")

local Package = {}

local PKG_HEAD_BYTES = 4

Package.TYPE_HANDSHAKE = 1
Package.TYPE_HANDSHAKE_ACK = 2
Package.TYPE_HEARTBEAT = 3
Package.TYPE_DATA = 4
Package.TYPE_KICK = 5

Package.encode = function(_type,body)
    local length = 0
    if body then
        length = #body
    end
    local buffer = {}
    local index = 1
    buffer[index] = bit.band(_type,0xff)
    index = index + 1
    buffer[index] = bit.band(bit.rshift(length,16),0xff)
    index = index + 1
    buffer[index] = bit.band(bit.rshift(length,8),0xff)
    index = index + 1
    buffer[index] = bit.band(length,0xff)
    index = index + 1
    if body then
        func.copyArray(buffer,index,body,1,length)
    end
    return buffer
end

Package.decode = function(bytes)
--    echoInfo("Package.decode")
    local _type = bytes[1]
    local index = 2
    local a = bit.lshift(bytes[index],16)
    index = index + 1
    local b = bit.lshift(bytes[index],8)
    index = index + 1
    local c = bit.bor(a,b,bytes[index])
    index = index + 1
    local length = bit.arshift(c,0)
    local body = {}
    func.copyArray(body,1,bytes,PKG_HEAD_BYTES+1,length)
    return {type=_type,body=body}
end

return Package