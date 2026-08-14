-- dev/base.lua
-- Базовый класс устройства

local component = require("component")
local os = require("os")
local sr = require("serialization")

local Device = {}

-- Создание нового экземпляра
function Device:extend()
    local dev = {}
    setmetatable(dev, {__index = self})
    dev.__index = dev
    return dev
end

-- Инициализация
function Device:init(config)
    self.name = config.name or "Unknown"
    self.id = config.id or self.name
    self.address = config.address
    self.config = config
    
    if self.address then
        self.proxy = component.proxy(self.address)
        if not self.proxy then
            error("Cannot create proxy for '" .. self.name .. "' at " .. self.address)
        end
    else
        self.proxy = nil
    end
    
    -- Состояние
    self.state = nil
    self.prev_state = nil
    self.data = {}
    self.pending_signals = {}
    self.errors = {}
    
    -- Подписки
    self.subscriptions = self:get_subscriptions()
end

-- Сбор данных (переопределяется)
function Device:get_data()
    return {
        timestamp = os.time()
    }
end

-- Генерация сигналов на основе данных (переопределяется)
function Device:get_signals(data)
    return {}
end

-- Подписки на сигналы других устройств (переопределяется)
function Device:get_subscriptions()
    return {}
end

-- Таблица переходов (переопределяется)
-- transitions = {
--     STATE1 = {
--         signal1 = "NEW_STATE1",
--         signal2 = "NEW_STATE2",
--     },
--     STATE2 = {}
-- }

-- Приоритет сигналов (переопределяется)
-- signal_priority = {"emergency", "high", "low"}

-- Обновление состояния
function Device:update(signals)

    if not self.state then
        return nil
    end

    local state = self.state
    local transitions = self.transitions or {}
    local state_transitions = transitions[state]
    
    if not state_transitions then
        return state
    end
    
    -- Проходим по сигналам в порядке приоритета
    local priority = self.signal_priority or {}
    for _, sig_name in ipairs(priority) do
        if signals[sig_name] and state_transitions[sig_name] then
            return state_transitions[sig_name]
        end
    end
    
    return state
end

-- Действия при смене состояния (переопределяется)
function Device:on_state_change(old_state, new_state)
    -- По умолчанию ничего не делаем
end

-- Применить новое состояние
function Device:set_state(new_state)
    if not new_state or new_state == self.state then
        return false
    end
    
    local old_state = self.state
    self.prev_state = old_state
    self.state = new_state
    
    self:on_state_change(old_state, new_state)
    
    return true
end

-- Обработать ошибку и запомнить
function Device:set_error(method_name, err)
    table.insert(self.errors, {
        time = os.time(),
        method = method_name,
        message = tostring(err)
    })
end

-- Очистить ошибки
function Device:clear_errors()
    self.errors = {}
end

-- Формат заголовка для дисплея (переопределяется)
function Device:get_header()
    return string.format("%-15s %12s", "NAME", "STATE")
end

-- Формат строки для дисплея (переопределяется)
function Device:format_display(data)
    return string.format("%-15s %12s", self.name, self.state or "unknown")
end

-- Получить данные для отправки по сети
function Device:get_payload()
    local payload = {}
    
    -- Базовые поля
    payload._type = self.type
    payload._state = self.state
    
    -- Данные если есть
    if self.data then
        for k, v in pairs(self.data) do
            payload[k] = v
        end
    end
    
    return payload
end

-- Генерация событий для других устройств
function Device:get_events()
    local events = {}
    local state = self.state or ""
    
    -- Формат: "тип.событие"
    local event = self.type .. "." .. state:lower()
    table.insert(events, event)
    
    -- Также добавляем событие с id: "тип.id.событие"
    if self.id then
        local specific_event = self.type .. "." .. self.id .. "." .. state:lower()
        table.insert(events, specific_event)
    end
    
    return events
end

function Device:safe_call(method_name, ...)
    if not self.proxy then return nil end
    
    local method = self.proxy[method_name]
    if not method or type(method) ~= "function" then return nil end
    
    local ok, result = pcall(method, ...)
    if not ok then
        self:set_error(method_name, result)
        return nil
    end
    
    return result
end

return Device