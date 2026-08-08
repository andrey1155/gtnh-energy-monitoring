local serialization = {}

function serialization.serialize(data)
    local function stringify(val)
        if type(val) == "string" then
            return '"' .. val:gsub('"', '\\"') .. '"'
        elseif type(val) == "number" then
            return tostring(val)
        elseif type(val) == "boolean" then
            return tostring(val)
        elseif type(val) == "nil" then
            return "nil"
        elseif type(val) == "table" then
            local items = {}
            local isArray = true
            for k, _ in pairs(val) do
                if type(k) ~= "number" then
                    isArray = false
                    break
                end
            end
            
            if isArray then
                for i, v in ipairs(val) do
                    items[#items + 1] = stringify(v)
                end
                return "{" .. table.concat(items, ",") .. "}"
            else
                for k, v in pairs(val) do
                    local key = type(k) == "string" and ('"' .. k .. '"') or tostring(k)
                    items[#items + 1] = key .. ":" .. stringify(v)
                end
                return "{" .. table.concat(items, ",") .. "}"
            end
        else
            return "nil"
        end
    end
    return stringify(data)
end

function serialization.unserialize(str)
    -- Вместо load используем безопасный парсер
    local function parseString(s)
        if s:match('^".*"$') then
            return s:sub(2, -2)
        end
        return nil
    end
    
    local function parseNumber(s)
        local num = tonumber(s)
        if num then
            return num
        end
        return nil
    end
    
    local function parseTable(s)
        if s:sub(1,1) ~= '{' then return nil end
        local result = {}
        local content = s:sub(2, -2)
        if content == "" then return result end
        
        local parts = {}
        local depth = 0
        local current = ""
        
        for i = 1, #content do
            local ch = content:sub(i, i)
            if ch == '{' or ch == '[' then
                depth = depth + 1
            elseif ch == '}' or ch == ']' then
                depth = depth - 1
            elseif ch == ',' and depth == 0 then
                parts[#parts + 1] = current
                current = ""
            else
                current = current .. ch
            end
        end
        if current ~= "" then
            parts[#parts + 1] = current
        end
        
        for _, part in ipairs(parts) do
            local key, value = part:match('"([^"]+)":(.+)')
            if key then
                local val = serialization.unserialize(value)
                if val ~= nil then
                    result[key] = val
                else
                    result[key] = value
                end
            else
                local val = serialization.unserialize(part)
                if val ~= nil then
                    result[#result + 1] = val
                end
            end
        end
        
        return result
    end
    
    -- Основной парсер
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    
    if str:sub(1,1) == '"' then
        return parseString(str)
    end
    
    if str:sub(1,1) == '{' then
        return parseTable(str)
    end
    
    if str == "true" then return true end
    if str == "false" then return false end
    if str == "nil" then return nil end
    
    local num = tonumber(str)
    if num then return num end
    
    return nil
end

return serialization