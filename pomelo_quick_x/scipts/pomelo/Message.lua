require("bit")

local func = require("pomelo.functions")
local Protocol = require("pomelo.Protocol")

local Message = class("Message")

local MSG_FLAG_BYTES = 1
local MSG_ROUTE_CODE_BYTES = 2
local MSG_ID_MAX_BYTES = 5
local MSG_ROUTE_LEN_BYTES = 1
    
local MSG_ROUTE_CODE_MAX = 0xffff
local MSG_COMPRESS_ROUTE_MASK = 0x1
local MSG_TYPE_MASK = 0x7

Message.TYPE_REQUEST = 0
Message.TYPE_NOTIFY = 1
Message.TYPE_RESPONSE = 2
Message.TYPE_PUSH = 3

Message.encode = function(id,_type,compressRoute,route,msg)
    local idBytes = 0
    if Message._msgHasId(_type) then
        idBytes = Message._caculateMsgIdBytes(id)
    end
    local msgLen = MSG_FLAG_BYTES + idBytes

    if Message._msgHasRoute(_type) then
        if compressRoute~=0 then
            if type(route) ~= 'number' then
                  echoError('error flag for number route!')
                  return
            end
            msgLen = msgLen + MSG_ROUTE_CODE_BYTES
        else 
            msgLen = msgLen + MSG_ROUTE_LEN_BYTES
            if route then
                route = Protocol.strencode(route)
                if #route > 255 then
                    echoError('route maxlength is overflow')
                    return
                end
                msgLen = msgLen + #route
            end
        end
    end

    if msg then
        msgLen = msgLen + #msg
    end

    local buffer = {}
    local offset = 1

    -- add flag
    offset = Message._encodeMsgFlag(_type,compressRoute,buffer,offset)

    -- add message id
    if Message._msgHasId(_type) then
        offset = Message._encodeMsgId(id,idBytes,buffer,offset)
    end

    -- add route
    if Message._msgHasRoute(_type) then
        offset = Message._encodeMsgRoute(compressRoute,route,buffer,offset)
    end

    -- add body
    if msg then
        offset = Message._encodeMsgBody(msg,buffer,offset)
    end

    return buffer
end

Message.decode = function(bytes)
--    echoInfo("Message.decode")
    local offset = 1
    local id = 0
    local route = nil

    -- parse flag
    local flag = bytes[offset]
    offset = offset + 1
    local compressRoute = bit.band(flag,MSG_COMPRESS_ROUTE_MASK)
    local _type = bit.band(bit.rshift(flag,1),MSG_TYPE_MASK)

    -- parse id
    if Message._msgHasId(_type) then
        local byte = bytes[offset]
        offset = offset + 1
        id = bit.band(byte,0x7f)
        while bit.band(byte,0x80)~=0 do
            id = bit.lshift(id,7)
            byte = bytes[offset]
            offset = offset + 1
            id = bit.bor(id,bit.band(byte,0x7f))
        end
    end

    -- parse route
    if Message._msgHasRoute(_type) then
        if compressRoute~=0 then
              local a = bit.lshift((bytes[offset]),8)
              offset = offset + 1
              route = bit.bor(a,bytes[offset])
              offset = offset + 1
        else 
            local routeLen = bytes[offset]
            offset = offset + 1
            if routeLen then
                route = {}
                func.copyArray(route,1,bytes,offset,routeLen)
                route = Protocol.strdecode(route)
            else 
                route = ''
            end
            offset = offset + routeLen
        end
    end

    -- parse body
    local bodyLen = #bytes - offset
    local body = {}

    func.copyArray(body,1,bytes,offset,bodyLen+1)
--    echoInfo("Protocol.strdecode(body)=%s",Protocol.strdecode(body))
    
    return {
        id=id,
        type=_type,
        compressRoute=compressRoute,
        route=route,
        body=body
    }
    
end

Message._msgHasId = function(_type)
    return _type == Message.TYPE_REQUEST or 
           _type == Message.TYPE_RESPONSE
end

Message._msgHasRoute = function(_type)
    return _type == Message.TYPE_REQUEST or 
           _type == Message.TYPE_NOTIFY or 
           _type == Message.TYPE_PUSH
end

Message._caculateMsgIdBytes = function(id)
    local len = 0
    repeat 
          len = len + 1
          id = bit.rshift(id,7)
    until id <= 0
    return len
end

Message._encodeMsgFlag = function(_type,compressRoute,buffer,offset)
    if _type ~= Message.TYPE_REQUEST and _type ~= Message.TYPE_NOTIFY and _type ~= Message.TYPE_RESPONSE and _type ~= Message.TYPE_PUSH then
        echoError('unkonw message _type: %s',_type)
    end

    local a = 0
    if compressRoute~=0 then
        a = 1
    end
    buffer[offset] = bit.bor(bit.lshift(_type,1),a)
  
    return offset + MSG_FLAG_BYTES
end

Message._encodeMsgId = function(id,idBytes,buffer,offset)
    local index = offset + idBytes - 1
    buffer[index] = bit.band(id,0x7f)
    index = index - 1
    while index >= offset do
        id = bit.rshift(id,7)
        buffer[index] = bit.bor(bit.band(id,0x7f),0x80)
        index = index - 1
    end
    return offset + idBytes
end

Message._encodeMsgRoute = function(compressRoute,route,buffer,offset)
    if compressRoute~=0 then
        if route > MSG_ROUTE_CODE_MAX then
            echoError('route number is overflow')
            return
        end
        buffer[offset] = bit.band(bit.rshift(route,8),0xff)
        offset = offset + 1
        buffer[offset] = bit.band(route,0xff)
        offset = offset + 1
    else 
        if route then
            buffer[offset] = bit.band(#route,0xff)
            offset = offset + 1
            func.copyArray(buffer,offset,route,1,#route)
            offset = offset + #route
        else 
            buffer[offset] = 0
            offset = offset + 1
        end
    end
    return offset
end

Message._encodeMsgBody = function(msg,buffer,offset)
    func.copyArray(buffer,offset,msg,1,#msg)
    return offset + #msg
end

return Message