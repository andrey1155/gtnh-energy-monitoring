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
    "bat_full",
    "bat_not_full",
    "empty",
    "start",
    "stop",
}

-- Таблица переходов
react.transitions = {
    RUNNING = {
        bat_full = "IDLE",
        empty = "RELOADING",
        stop = "SHUTDOWN"
    },
    SHUTDOWN = {
        start = "RUNNING",
    },
    RELOADING = {
        -- по таймауту возвращаемся в RUNNING (особый случай)
    },
    IDLE = {
        bat_not_full = "RUNNING",
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
    
    -- Таймеры и флаги
    self.reboot_started_at = -1
    self.reboot_time = config.reboot_time or 60
    
    -- Начальное состояние
    self.state = "RUNNING"
end

-- Сбор данных
function react:get_data()
    local proxy = self.proxy
    local data = {}
    
    data.heat = self:safe_call(proxy.getHeat, proxy) or 0
    data.max_heat = self:safe_call(proxy.getMaxHeat, proxy) or 100
    data.eu_output = self:safe_call(proxy.getReactorEUOutput, proxy) 
                  or self:safe_call(proxy.getEUOutput, proxy) 
                  or 0
    data.active = self:safe_call(proxy.producesEnergy, proxy)
               or self:safe_call(proxy.isActive, proxy)
               or false
    
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
        "bat.*.not_full",
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