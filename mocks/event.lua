local event_mock = {}
local listeners = {}
local timerId = 0
local signalQueue = {}
local sourceCounter = 0

-- Данные для двух источников (по 2 реактора каждый)
local source1Data = {
    Reactor1 = {
        ["15 sec"] = 0.45,
        ["5 min"] = 0.43,
        ["1 hour"] = 0.40,
        ["1 day"] = 0.38,
        _type = "react",
        _heat = 450,
        _maxHeat = 1000,
        _euOutput = 128,
        _active = true,
        _rodAvgDamage = 35.5,
    },
    Reactor2 = {
        ["15 sec"] = 0.32,
        ["5 min"] = 0.30,
        ["1 hour"] = 0.28,
        ["1 day"] = 0.25,
        _type = "react",
        _heat = 320,
        _maxHeat = 1000,
        _euOutput = 95,
        _active = true,
        _rodAvgDamage = 60.0,
    },
}

local source2Data = {
    Reactor3 = {
        ["15 sec"] = 0.85,
        ["5 min"] = 0.80,
        ["1 hour"] = 0.75,
        ["1 day"] = 0.70,
        _type = "react",
        _heat = 580,
        _maxHeat = 1000,
        _euOutput = 200,
        _active = true,
        _rodAvgDamage = 15.0,
    },
    Reactor4 = {
        ["15 sec"] = 0.25,
        ["5 min"] = 0.23,
        ["1 hour"] = 0.20,
        ["1 day"] = 0.18,
        _type = "react",
        _heat = 250,
        _maxHeat = 1000,
        _euOutput = 75,
        _active = true,
        _rodAvgDamage = 82.5,
    },
}

-- Простая сериализация для теста
local function simpleSerialize(data)
    local parts = {}
    for name, info in pairs(data) do
        local infoParts = {}
        for k, v in pairs(info) do
            if type(v) == "string" then
                infoParts[#infoParts + 1] = '"' .. k .. '":"' .. v .. '"'
            elseif type(v) == "number" then
                infoParts[#infoParts + 1] = '"' .. k .. '":' .. tostring(v)
            elseif type(v) == "boolean" then
                infoParts[#infoParts + 1] = '"' .. k .. '":' .. tostring(v)
            end
        end
        parts[#parts + 1] = '"' .. name .. '":{' .. table.concat(infoParts, ",") .. '}'
    end
    return '{' .. table.concat(parts, ",") .. '}'
end

-- Добавляем сигналы от двух источников
local function addSourceSignals()
    -- Источник 1 (Reactor1, Reactor2)
    signalQueue[#signalQueue + 1] = {
        "modem_message",
        "mock-local-001",
        "mock-source-001",
        1,
        10,
        simpleSerialize(source1Data)
    }
    
    -- Источник 2 (Reactor3, Reactor4)
    signalQueue[#signalQueue + 1] = {
        "modem_message",
        "mock-local-002",
        "mock-source-002",
        1,
        15,
        simpleSerialize(source2Data)
    }
end

-- Добавляем сигналы при загрузке
addSourceSignals()

function event_mock.listen(name, callback)
    if not listeners[name] then listeners[name] = {} end
    listeners[name][#listeners[name] + 1] = callback
    return #listeners[name]
end

function event_mock.ignore(name, id)
    if listeners[name] then
        listeners[name][id] = nil
    end
end

function event_mock.pull(timeout, name)
    timeout = timeout or 0.5
    
    -- Генерируем случайное число от 1 до 100
    local rand = math.random(1, 100)

    -- 25% - пакет от источника 1
    if rand <= 25 then
        local serialized = simpleSerialize(source1Data)
        return "modem_message", "mock-local", "mock-source-001", 1, 10, serialized
    end
    
    -- 25% - пакет от источника 2
    if rand <= 50 then
        local serialized = simpleSerialize(source2Data)
        return "modem_message", "mock-local", "mock-source-002", 1, 15, serialized
    end
    
    -- 50% - никакого пакета (таймаут)
    return nil
end

function event_mock.timer(interval, callback, times)
    timerId = timerId + 1
    local id = timerId
    callback()
    return id
end

function event_mock.cancel(id)
    return true
end

-- Функция для добавления своих сигналов
function event_mock.addSignal(signal)
    signalQueue[#signalQueue + 1] = signal
end

-- Функция для очистки очереди
function event_mock.clearSignals()
    signalQueue = {}
end

-- Функция для добавления тестового пакета
function event_mock.sendTestPacket(data, sourceName)
    sourceName = sourceName or "mock-source-001"
    local serialized = simpleSerialize(data)
    signalQueue[#signalQueue + 1] = {
        "modem_message",
        "mock-local",
        sourceName,
        1,
        10,
        serialized
    }
end

-- Функция для добавления пакета от источника 1
function event_mock.sendSource1()
    signalQueue[#signalQueue + 1] = {
        "modem_message",
        "mock-local-001",
        "mock-source-001",
        1,
        10,
        simpleSerialize(source1Data)
    }
end

-- Функция для добавления пакета от источника 2
function event_mock.sendSource2()
    signalQueue[#signalQueue + 1] = {
        "modem_message",
        "mock-local-002",
        "mock-source-002",
        1,
        15,
        simpleSerialize(source2Data)
    }
end

return event_mock