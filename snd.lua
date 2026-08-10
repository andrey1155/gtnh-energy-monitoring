-- snd.lua
local pt = dofile("lib/setpath.lua")()

local cfg = dofile("snd_cfg.lua")
local Manager = require("lib.mgr")
local sr = require("serialization")
local os = require("os")
local event = require("event")
local disp = require("lib.disp.disp")
local Net = require("lib.net.net")
local helpers = require("lib.helpers")

-- Создаём экземпляр менеджера
local mgr = Manager:new()
mgr:init(cfg)

local mgr = Manager:new()
local ok = mgr:init(cfg)

print("Init result: " .. tostring(ok))
print("Devices count: " .. #mgr.devices)

if #mgr.devices == 0 then
    print("No devices loaded! Check config.")
    print("Config devices:")
    for dev_type, devs in pairs(cfg.devices) do
        print("  " .. dev_type .. ": " .. #devs .. " configs")
    end
    os.sleep(5)
    return
end

for i, dev in ipairs(mgr.devices) do
    print("Device " .. i .. ": " .. dev.name .. " type=" .. dev.type .. " proxy=" .. tostring(dev.proxy))
end

local net = Net:new(cfg)

local running = true

-- Обработчик выхода
local function check_exit(_, _, char, code)
    -- Q (латиница) = 113, Q (кириллица Й) = 1049
    -- code 16 = Q (в некоторых версиях OC)
    if char == 113 or char == 1049 or code == 16 or code == 113 then
        running = false
    end
end

event.listen("key_down", check_exit)

-- главный цикл
while running do
    -- сбор данных
    mgr:update_data()
    
    -- генерация и распространение событий
    mgr:propagate_events()
    
    -- обновление состояний
    mgr:update_states()
    
    -- отображение и отправка
    disp:draw(mgr.devices)
    net:send(mgr:get_payload())
    
    -- ожидание с обработкой событий
    local deadline = os.time() + (cfg.interval or 2)
    while os.time() < deadline and running do
        event.pull(0.1)
    end
end

-- Остановка
event.ignore("key_down", check_exit)
mgr:stop()
net:close()
disp:clear()
print("Stopped")