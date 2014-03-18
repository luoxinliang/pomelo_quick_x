local func = {}

function func.copyArray(dest,doffset,src,soffset,length)
    if("table" ~= type(dest) or "table" ~= type(src) or length<=0 ) then
        return dest
    end
    for index=1,length do
        dest[doffset] = src[soffset]
        doffset = doffset + 1
        soffset = soffset + 1
    end
end

function func.printTable(t)
    for k,v in pairs(t) do
        echoInfo("k=%s,v=%s",k,v)
    end
end

return func