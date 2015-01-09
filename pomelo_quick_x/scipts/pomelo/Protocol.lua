require("bit")

local Protocol = class("Protocol")

Protocol.strencode = function(str)
    do return {string.byte(str, 1, #str)} end
end

Protocol.strdecode = function(bytes)
    local array = {}
    local len = #bytes
    for i = 1, len do
        array[i] = string.char(bytes[i])
    end
    return table.concat(array)
end

return Protocol
