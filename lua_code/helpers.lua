function lines(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("(.-)\n")
end

function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
