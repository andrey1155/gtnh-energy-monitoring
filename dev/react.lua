-- dev/react.lua
local base = require("dev.base")
local component = require("component")
local helpers = dofile("./lib/helpers.lua")
local sides = require("sides")
local sr = require("serialization")

local react = base:extend()

-- Переопределяемые поля
react.type = "react"

-- Приоритет сигналов (порядок важен)
react.signal_priority = {
    "full",
    "charging",
    "empty",
    "start",
    "stop",
}

-- Таблица переходов
react.transitions = {
    RUNNING = {
        full = "IDLE",
        empty = "RELOADING",
        stop = "SHUTDOWN"
    },
    SHUTDOWN = {
        start = "RUNNING",
    },
    RELOADING = {
        full = "IDLE",
        -- по таймауту возвращаемся в RUNNING (особый случай)
    },
    IDLE = {
        charging = "RUNNING",
    },

}

-- Инициализация
function react:init(config)    
    base.init(self, config)
    
    -- Прокси
    self.red_proxy = component.proxy(config.red_address)
    self.inv_proxy = config.inv_address and component.proxy(config.inv_address)
    self.red_side = config.red_side or sides.front
    self.inv_side = config.inv_side or sides.front
    
    if self.inv_side == nil then
        self.inv_side = sides.front
    elseif type(self.inv_side) == "string" then
        self.inv_side = sides[self.inv_side] or sides.front
    end

    if self.red_side == nil then
        self.red_side = sides.front
    elseif type(self.red_side) == "string" then
        self.red_side = sides[self.red_side] or sides.front
    end

    -- Таймеры и флаги
    self.reboot_started_at = -1
    self.reboot_time = config.reboot_time or 60
    
    -- Начальное состояние
    self.state = nil
    self:set_state("RUNNING")
end

-- Сбор данных
function react:get_data()
    local proxy = self.proxy
    local data = {}

    data.heat =  helpers.round( proxy.getHeat() )
    data.max_heat = helpers.round( proxy.getMaxHeat() )
    data.eu_output = helpers.round( proxy.getReactorEUOutput() )
    data.active = proxy.producesEnergy()

    -- Температура в долях
    data.temp = data.max_heat > 0 and (data.heat / data.max_heat) or 0
    
    -- Данные о стержнях
    if self.inv_proxy then
        data.rod_avg, data.rod_count = helpers.getAverageRodDamage(
            self.inv_proxy, self.inv_side
        )
    end
    
    data.timestamp = os.time()
    
    return data
end

-- Генерация сигналов
function react:get_signals(data)
    local sigs = {}
         
    if data.eu_output <= 1 then
        table.insert(sigs, "empty")
    end
    
    return sigs
end

-- Действия при смене состояния
function react:on_state_change(old_state, new_state)
-- RUNNING
-- SHUTDOWN
-- RELOADING
-- IDLE

    if new_state == "RUNNING" then
        self.red_proxy.setOutput(self.red_side, 15)
    elseif new_state == "SHUTDOWN" then
        self.red_proxy.setOutput(self.red_side, 0)
    elseif new_state == "IDLE" then
        self.red_proxy.setOutput(self.red_side, 0)
    elseif new_state == "RELOADING" then
        self.reboot_started_at = os.time()
        self.red_proxy.setOutput(self.red_side, 0)
    elseif old_state == "RELOADING" and new_state == "RUNNING" then
        self.reboot_started_at = -1
        self.red_proxy.setOutput(self.red_side, 15)
    end
end

-- Особая логика обновления (для таймера ребута)
function react:update(signals)
    local new_state = base.update(self, signals)

    -- Проверка таймера ребута
    if self.state == "RELOADING" then
        local elapsed = os.time() - self.reboot_started_at
        if elapsed >= self.reboot_time then
            new_state = "RUNNING"
        end
    end
    
    return new_state
end

-- Подписки на сигналы других устройств
function react:get_subscriptions()
    return {
        "bat.*.full",
        "bat.*.charging",
    }
end

-- Формат для дисплея
function react:get_header()
    return string.format("%-10s %6s %5s %7s %8s",
        "Reactor", "EU/t", "Temp", "AvgDmg", "State")
end

function react:format_display(data)
    if not data then
        return string.format("%-10s %6s %5s %7s %8s", self.name, "?", "?", "?", "?")
    end
    
    data = data or {}
    
    local name = self.name:sub(1, 10)
    local eu = string.format("%5d", data.eu_output or 0)
    local temp = string.format("%4d%%", math.floor((data.temp or 0) * 100))    
    local dmg = string.format("%6.0f", data.rod_avg or 0)
    
    local state = self.state or "?"
    if #state > 8 then state = state:sub(1, 8) end
    
    return string.format("%-10s %s %s %s %12s", name, eu, temp, dmg, state)
end

return react