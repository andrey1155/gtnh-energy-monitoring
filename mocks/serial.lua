local serial_mock = {}

function serial_mock.serialize(data)
    local function stringify(val)
        if type(val) == "string" then
            return '"' .. val .. '"'
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return tostring(val)
        elseif type(val) == "table" then
            local items = {}
            for k, v in pairs(val) do
                if type(k) == "string" then
                    items[#items + 1] = stringify(k) .. ':' .. stringify(v)
                else
                    items[#items + 1] = '[' .. stringify(k) .. ']:' .. stringify(v)
                end
            end
            return '{' .. table.concat(items, ',') .. '}'
        else
            return 'nil'
        end
    end
    return stringify(data)
end

function serial_mock.unserialize(str)
    local fn, err = loadstring("return " .. str)
    if fn then
        local ok, result = pcall(fn)
        if ok then
            return result
        end
    end
    return nil, err or "Parse error"
end

return serial_mock