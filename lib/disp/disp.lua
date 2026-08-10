-- lib/disp/disp.lua
local term = require("term")

local Display = {}

function Display:new(mgr)
    local disp = {
        mgr = mgr,
    }
    setmetatable(disp, {__index = Display})
    return disp
end

function Display:clear()
    term.clear()
end

function Display:draw(devices)
    
    term.clear()
    term.setCursor(1, 1)
    
    -- Группируем устройства по типам
    local grouped = self:group_devices(devices)
    
    -- Порядок вывода типов
    local type_order = {"react", "bat", "turb"}
    
    local row = 1
    local first_group = true
    
    for _, dev_type in ipairs(type_order) do
        local devs = grouped[dev_type]
        if devs and #devs > 0 then
            -- Отступ между группами
            if not first_group then
                row = row + 1
                term.setCursor(1, row)
                print("")
                row = row + 1
            end
            first_group = false
            
            -- Заголовок группы
            term.setCursor(1, row)
            print(self:get_group_header(dev_type))
            row = row + 1
            
            -- Заголовок колонок (берём у первого устройства этого типа)
            term.setCursor(1, row)
            print(devs[1]:get_header())
            row = row + 1
            
            -- Разделитель
            term.setCursor(1, row)
            print(string.rep("-", 50))
            row = row + 1
            
            -- Строки устройств
            for _, dev in ipairs(devs) do
                term.setCursor(1, row)
                print(dev:format_display(dev.data))
                row = row + 1
            end
        end
    end
    
    -- Свободная строка и подсказка
    row = row + 1
    term.setCursor(1, row)
    print("Press Q to exit")
end

function Display:group_devices(devices)
    local grouped = {}
    for _, dev in ipairs(devices) do
        local t = dev.type or "unknown"
        if not grouped[t] then
            grouped[t] = {}
        end
        table.insert(grouped[t], dev)
    end
    return grouped
end

function Display:get_group_header(dev_type)
    local headers = {
        react = "=== Reactors ===",
        bat = "=== Batteries ===",
        turb = "=== Turbines ===",
    }
    return headers[dev_type] or ("=== " .. dev_type .. " ===")
end

return Display