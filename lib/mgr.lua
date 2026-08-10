-- lib/mgr.lua
-- Менеджер устройств

local component = require("component")
local event = require("event")
local os = require("os")
local sr = require("serialization")

local Manager = {}

function Manager:new()
    local mgr = {
        devices = {},      -- все устройства
        by_type = {},      -- устройства по типам: {react = {...}, bat = {...}}
        by_id = {},        -- устройства по id для быстрого поиска
        event_queue = {},  -- очередь событий для распространения
        running = false,
    }
    setmetatable(mgr, {__index = Manager})
    return mgr
end

-- Инициализация из конфига
function Manager:init(cfg)
    self.cfg = cfg
    
    if not cfg or not cfg.devices then
        print("No devices in config")
        return false
    end
    
    local loaded = 0
    for dev_type, dev_configs in pairs(cfg.devices) do
        if dev_configs and type(dev_configs) == "table" then
            -- Передаём тип и массив конфигов этого типа
            local count = self:load_device_type(dev_type, dev_configs)
            loaded = loaded + count
        end
    end
    
    if #self.devices == 0 then
        print("No devices loaded")
        return false
    end
    
    print("Total devices loaded: " .. loaded)
    return true
end

-- Загрузка одного типа устройств
function Manager:load_device_type(dev_type, configs)
    -- Загружаем модуль устройства
    local module_path = "./dev/" .. dev_type .. ".lua"
    local ok, module = pcall(dofile, module_path)
    print("loaded: " .. module_path)
    if not ok then
        print("Cannot load device type: " .. dev_type .. " (" .. tostring(module) .. ")")
        return 0
    end
    
    local count = 0
    for _, dev_config in ipairs(configs) do
        -- Вот здесь была проблема: нужно передавать dev_config, а не cfg
        local ok, dev = pcall(function()
            local instance = module:extend()
            instance:init(dev_config)  -- ← передаём конфиг конкретного устройства
            return instance
        end)
        
        if ok and dev then
            self:add_device(dev)
            print(string.format("  [%s] %s loaded", dev_type, dev.name))
            count = count + 1
        else
            print(string.format("  [%s] failed to load: %s", dev_type, tostring(dev)))
        end
    end
    
    return count
end

-- Добавить устройство
function Manager:add_device(dev)
    table.insert(self.devices, dev)
    
    -- Индекс по типу
    self.by_type[dev.type] = self.by_type[dev.type] or {}
    table.insert(self.by_type[dev.type], dev)
    
    -- Индекс по id
    if dev.id then
        self.by_id[dev.id] = dev
    end
end

-- Сбор данных со всех устройств
function Manager:update_data()
    for _, dev in ipairs(self.devices) do
        local ok, data = pcall(function()
            return dev:get_data()
        end)
        
        if ok and data then
            dev.data = data
        else
            dev:set_error("get_data", data)
        end
    end
end

-- Обновление состояний всех устройств
function Manager:update_states()
    for _, dev in ipairs(self.devices) do
        -- Собираем сигналы от самого устройства
        local signals = {}
        if dev.get_signals then
            local dev_signals = dev:get_signals(dev.data)
            for _, sig in ipairs(dev_signals) do
                signals[sig] = true
            end
        end
        
        -- Добавляем внешние сигналы из очереди
        if dev.pending_signals then
            for _, sig in ipairs(dev.pending_signals) do
                signals[sig] = true
            end
        end

        -- Обновляем состояние
        local new_state = dev:update(signals)
        if new_state then
            local changed = dev:set_state(new_state)
            
            if changed then
                -- Если состояние изменилось, генерируем события
                local events = dev:get_events()
                self:add_events(dev, events)
            end
        end
        
        -- Очищаем pending сигналы
        dev.pending_signals = {}
    end
end

-- Добавить события в очередь
function Manager:add_events(source_dev, events)
    for _, event_str in ipairs(events) do
        table.insert(self.event_queue, {
            source = source_dev.id,
            source_type = source_dev.type,
            event = event_str,
        })
    end
end

-- Распространение событий между устройствами
function Manager:propagate_events()
    if #self.event_queue == 0 then
        return
    end
    
    -- Обрабатываем каждое событие
    for _, event_data in ipairs(self.event_queue) do
        local event_str = event_data.event
        -- event_str = "bat.full" или "bat.buffer_1.full"
        
        -- Разбираем имя события
        local parts = {}
        for part in event_str:gmatch("[^.]+") do
            table.insert(parts, part)
        end
        
        -- parts = {"bat", "full"} или {"bat", "buffer_1", "full"}
        local event_type = parts[1]  -- "bat"
        local event_signal  -- "full"
        
        if #parts == 2 then
            event_signal = parts[2]
        elseif #parts == 3 then
            event_signal = parts[3]
        else
            goto continue
        end
        
        -- Для каждого устройства проверяем подписки
        for _, dev in ipairs(self.devices) do
            -- Пропускаем источник события
            if dev.id == event_data.source then
                goto skip_dev
            end
            
            -- Проверяем подписки устройства
            for _, sub in ipairs(dev.subscriptions) do
                if self:match_subscription(sub, event_type, event_str) then
                    -- Добавляем сигнал в pending
                    dev.pending_signals = dev.pending_signals or {}
                    table.insert(dev.pending_signals, event_signal)
                    break
                end
            end
            
            ::skip_dev::
        end
        
        ::continue::
    end
    
    -- Очищаем очередь
    self.event_queue = {}
end

-- Проверка совпадения подписки с событием
function Manager:match_subscription(subscription, event_type, full_event)
    -- subscription = "bat.*.full"
    -- full_event = "bat.buffer_1.full"
    
    -- Заменяем * на .* для Lua паттерна
    local pattern = "^" .. subscription:gsub("%*", ".*") .. "$"
    return full_event:match(pattern) ~= nil
end

-- Выполнение действий при смене состояния
function Manager:execute_actions()
    -- Действия уже выполнены в on_state_change каждого устройства
    -- Здесь можно добавить общие действия, если нужно
end

-- Получить данные для отправки по сети
function Manager:get_payload()
    local payload = {}
    
    for _, dev in ipairs(self.devices) do
        local dev_payload = dev:get_payload()
        payload[dev.id or dev.name] = dev_payload
    end
    
    return payload
end

-- Главный цикл
function Manager:run(interval)
    self.running = true
    
    -- Начальный сбор данных
    self:update_data()
    self:update_states()
    
    while self.running do
        local deadline = os.time() + interval
        
        -- Ждём с обработкой событий
        while os.time() < deadline and self.running do
            event.pull(0.1)
        end
        
        if not self.running then
            break
        end
        
        -- Шаг обновления
        self:update_data()
        self:propagate_events()
        self:update_states()
        self:execute_actions()
    end
end

-- Остановка
function Manager:stop()
    self.running = false
    
    -- Действия при остановке для каждого устройства
    for _, dev in ipairs(self.devices) do
        if dev.on_shutdown then
            dev:on_shutdown()
        end
    end
end

-- Получить устройства определённого типа
function Manager:get_by_type(dev_type)
    return self.by_type[dev_type] or {}
end

-- Получить устройство по id
function Manager:get_by_id(id)
    return self.by_id[id]
end

function Manager:send_signal(device_id, signal_name)
    local dev = self.by_id[device_id]
    if dev then
        table.insert(dev.pending_signals, signal_name)
        print("Signal '" .. signal_name .. "' sent to " .. device_id)
    else
        print("Device '" .. device_id .. "' not found")
    end
end

return Manager