local progress = {}
local FILE = "progress.lua"

local function serialize(v, out)
    local ty = type(v)
    if ty == "number" or ty == "boolean" then out[#out + 1] = tostring(v)
    elseif ty == "string" then out[#out + 1] = ("%q"):format(v)
    elseif ty == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            out[#out + 1] = "["
            serialize(k, out)
            out[#out + 1] = "]="
            serialize(val, out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    end
end

function progress.save(p)
    local out = { "return " }
    serialize(p, out)
    love.filesystem.write(FILE, table.concat(out))
end

function progress.load(file)
    file = file or FILE
    local data = love.filesystem.read(file)
    if data then
        local chunk = loadstring(data)
        if chunk then
            local ok, p = pcall(chunk)
            if ok and type(p) == "table" then
                p.cleared = p.cleared or {}
                p.items = p.items or {}
                p.codes = p.codes or {}
                return p
            end
        end
    end
    return { cleared = {}, items = {}, codes = {} }
end

return progress
