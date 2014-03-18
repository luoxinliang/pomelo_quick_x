require("bit")

local Protocol = class("Protocol")

Protocol.strencode = function(str)
    local byteArray = {}
    local offset = 1
    for i=1,#str do
        local charCode = string.byte(str,i)
        local codes = nil
        if charCode <= 0x7f then
            codes = {charCode}
        elseif charCode <= 0x7ff then
            codes = {bit.bor(0xc0,bit.rshift(charCode,6)),bit.bor(0x80,bit.band(charCode,0x3f))}
        else 
            codes = {bit.bor(0xe0,bit.rshift(charCode,12)),bit.rshift(bit.band(charCode,0xfc0),6),bit.bor(0x80,bit.band(charCode,0x3f))}
        end
        for j=1,#codes do
            byteArray[offset] = codes[j] 
            offset = offset +1
        end
    end
    return clone(byteArray)
end

Protocol.strdecode = function(bytes)
    local array = {}
    local charCode = 0
    local offset = 1
    while offset<=#bytes do
        if bytes[offset] < 128 then
            charCode = bytes[offset]
            offset = offset + 1
        elseif bytes[offset] < 224 then
            charCode = bit.lshift(bit.band(bytes[offset],0x3f),6) + bit.band(bytes[offset+1],0x3f)
            offset = offset + 2
        else 
            charCode = bit.lshift(bit.band(bytes[offset],0x0f),12) + bit.lshift(bit.band(bytes[offset+1],0x3f),6) + bit.band(bytes[offset+2],0x3f)
            offset = offset + 3
        end
        table.insert(array,charCode)
    end
    return string.char(unpack(array))
end

return Protocol