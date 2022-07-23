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

function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(math.min(math.max(rotation.x, -30.0), 30.0))
    local abs = math.abs(math.cos(x))
    return vector3(-math.sin(z) * abs, math.cos(z) * abs, math.sin(x))
end
