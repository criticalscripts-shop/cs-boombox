function StartsWith(url, str)
    return string.sub(url, 1, string.len(str)) == str
end

function Contains(v, tbl)
    for k, vv in pairs(tbl) do
        if (v == vv) then
            return true
        end
    end

    return false
end

function Ternary(a, b, c)
    if (type(c) == 'nil') then
        if (type(a) == 'nil' or (type(a) == 'boolean' and (not a))) then
            return b
        else
            return a
        end
    else
        if (type(a) == 'nil' or (type(a) == 'boolean' and (not a))) then
            return c
        else
            return b
        end
    end
end
