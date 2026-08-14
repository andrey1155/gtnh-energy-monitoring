-- dev/bat.lua
local base = dofile("./dev/base.lua")
local component = require("component")
local os = require("os")
local sr = require("serialization")

local bat = base:extend()

bat.type = "bat"

-- Приоритет сигналов (порядок важен)
bat.signal_priority = {
    "bat_full",
    "not_full",
    "empty",
    "not_empty",
    "high",
    "low",
}

-- Таблица переходов
bat.transitions = {
    CHARGING = {
        bat_full = "FULL",
        low = "LOW_CHARGE",
    },
    FULL = {
        not_full = "CHARGING",
        low = "LOW_CHARGE",
    },
    LOW_CHARGE = {
        bat_full = "FULL",
        not_empty = "CHARGING",
    },
}

-- Инициализация
function bat:init(config)
    base.init(self, config)
    
    -- Создаём прокси для одного или нескольких буферов
    self.proxies = {}
    self.battery_count = config.battery_count or 4
    
    if config.address then
        -- Одиночный буфер
        local proxy = component.proxy(config.address)
        if proxy then
            table.insert(self.proxies, proxy)
        end
    elseif config.addresses then
        -- Группа буферов
        for _, addr in ipairs(config.addresses) do
            local proxy = component.proxy(addr)
            if proxy then
                table.insert(self.proxies, proxy)
            else
                print("WARNING: Cannot proxy battery at " .. addr)
            end
        end
    end
    
    if #self.proxies == 0 then
        error("No battery proxies created for " .. self.name)
    end
    
    -- Пороги
    self.thresholds = {
        full = config.thresholds and config.thresholds.full or 95,
        high = config.thresholds and config.thresholds.high or 80,
        low = config.thresholds and config.thresholds.low or 20,
        empty = config.thresholds and config.thresholds.empty or 5,
    }
    
    -- Гистерезис для сигналов
    self.hysteresis = config.hysteresis or 5
    
    -- Начальное состояние
    self.state = "CHARGING"
end

-- Сбор данных
function bat:get_data()
    local data = {
        charge = 0,
        max_charge = 0,
        input = 0,
        output = 0,
        batteries_total = 0,
        batteries_found = 0,
    }
    
    for _, proxy in ipairs(self.proxies) do
        -- Суммируем заряд аккумуляторов
        for i = 1, self.battery_count do
            local ok, charge = pcall(function()
                return proxy.getBatteryCharge(i)
            end)
            local ok2, max_charge = pcall(function()
                return proxy.getMaxBatteryCharge(i)
            end)
            
            if ok and charge and ok2 and max_charge then
                data.charge = data.charge + charge
                data.max_charge = data.max_charge + max_charge
                data.batteries_found = data.batteries_found + 1
            end
            data.batteries_total = data.batteries_total + 1
        end
        
        -- Вход/выход
        local ok_in, inp = pcall(function()
            return proxy.getEUInputAverage()
        end)
        if ok_in and inp then
            data.input = data.input + inp
        end
        
        local ok_out, out = pcall(function()
            return proxy.getEUOutputAverage()
        end)
        if ok_out and out then
            data.output = data.output + out
        end
    end
    
    -- Процент заряда
    data.charge_percent = data.max_charge > 0 and (data.charge / data.max_charge * 100) or 0
    
    data.timestamp = os.time()
    
    return data
end

-- Генерация сигналов
function bat:get_signals(data)
    local sigs = {}
    
    if not data then return sigs end
    
    local charge = data.charge_percent or 0
    
    -- Полный
    if charge >= self.thresholds.full then
        table.insert(sigs, "bat_full")
    elseif charge < self.thresholds.full - self.hysteresis then
        table.insert(sigs, "not_full")
    end
    
    -- Пустой
    if charge <= self.thresholds.empty then
        table.insert(sigs, "empty")
    elseif charge > self.thresholds.empty + self.hysteresis then
        table.insert(sigs, "not_empty")
    end
    
    -- Высокий
    if charge >= self.thresholds.high then
        table.insert(sigs, "high")
    end
    
    -- Низкий
    if charge <= self.thresholds.low then
        table.insert(sigs, "low")
    end

    return sigs
end

-- Подписки на сигналы других устройств
function bat:get_subscriptions()
    return {}
end

-- Формат для дисплея
function bat:get_header()
    return string.format("%-15s %8s %7s %7s %12s",
        "Battery", "Charge", "EU In", "EU Out", "State")
end

function bat:format_display(data)
    if not data then
        return string.format("%-15s %8s %7s %7s %12s", 
            self.name, "?", "?", "?", "?")
    end
    
    data = data or {}
    
    local name = self.name:sub(1, 15)
    local charge = string.format("%6.1f%%", data.charge_percent or 0)
    local inp = string.format("%6.1f", data.input or 0)
    local out = string.format("%6.1f", data.output or 0)
    
    local state = self.state or "?"
    if #state > 12 then state = state:sub(1, 12) end
    
    return string.format("%-15s %s %s %s %12s", name, charge, inp, out, state)
end

return bat