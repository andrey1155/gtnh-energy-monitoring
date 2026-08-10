-- lib/util.lua
-- Безопасный вызов метода компонента
function safe_call(fn, ...)
    if not fn then return nil end
    
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    else
        return nil
    end
end

-- Группировка устройств по типу
function group_by_type(devices)
    local grouped = {}
    for _, dev in ipairs(devices) do
        local t = dev.type or "unknown"
        grouped[t] = grouped[t] or {}
        table.insert(grouped[t], dev)
    end
    return grouped
end

-- Сортировка по имени
function sort_by_name(devices)
    table.sort(devices, function(a, b)
        return a.name < b.name
    end)
end