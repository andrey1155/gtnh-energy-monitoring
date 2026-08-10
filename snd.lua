local pt = dofile("lib/setpath.lua")()

local cfg = dofile("snd_cfg.lua")
local Manager = require("lib.mgr")  -- сам класс

local sr = require("serialization")
local os = require("os")
local disp = require("lib.disp.disp")
local Net = require("lib.net.net")
local helpers = require("lib.helpers")

-- Создаём экземпляр менеджера
local mgr = Manager:new()
mgr:init(cfg)

local net = Net:new(cfg)

local running = true

local sent = false

-- главный цикл
while running do

    if os.clock() > 7 and ~sent then
        mgr:send_signal("react_1", "stop")
        sent = true
    end

    -- сбор данных
    for _, dev in ipairs(mgr.devices) do
        dev.data = dev:get_data()
    end
    
    -- генерация и распространение сигналов
    mgr:propagate_events()

    mgr:update_states()
    
    -- обновление состояний
    for _, dev in ipairs(mgr.devices) do
        dev.state = dev:update(dev.pending_signals)
    end
    
    -- выполнение действий при смене состояния
    mgr:execute_actions()
    
    -- отображение и отправка
    disp:draw(mgr.devices)
    net:send(mgr:get_payload())
    
    helpers.sleep(1)
end