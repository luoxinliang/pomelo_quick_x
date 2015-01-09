require("bit")

local Protocol = class("Protocol")

Protocol.strencode = function(str)

    do return {string.byte(str, 1, #str)} end

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
    local len = #bytes
    for i = 1, len do
        -- table.insert(array, string.char(bytes[i]))
        array[i] = string.char(bytes[i]) -- 更快一些
    end
    return table.concat(array)

    -- local offset = 1
    -- local charCode = 0
    -- while offset<=#bytes do
        -- charCode = bytes[offset]
        -- table.insert(array, string.char(charCode))
        -- offset = offset + 1
        -- table.insert(array,charCode)
    -- end
    -- local str = table.concat(bytes)
    -- console.log(str)
    -- return str

    -- return string.char(unpack(bytes))
end

return Protocol
