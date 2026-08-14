-- rcv.lua (receiver)
local pt = dofile("lib/setpath.lua")()

local component = require("component")
local event = require("event")
local os = require("os")
local serial = require("serialization")
local term = require("term")

local cfg = dofile("rcv_cfg.lua")

local port = cfg.port or 1
local retransmit = cfg.retransmit or false
local retransmitPower = cfg.retransmit_power or 10

if not component.isAvailable("modem") then
    print("Modem not found")
    return
end

local modem = component.modem

if not modem.isOpen(port) then
    local opened = modem.open(port)
    if not opened then
        print("Failed to open port " .. port)
        return
    end
end

if retransmit then
    modem.setStrength(retransmitPower)
    print("Retransmit enabled, power: " .. retransmitPower)
end

print("Listening on port " .. port)
print("Press Q to exit")
print("")

local displayData = {}
local packetCount = 0
local lastPacketTime = 0

local function round(num)
    return math.floor(num + 0.5)
end

-- Формат заголовка для разных типов устройств
local function get_header(dev_type)
    if dev_type == "react" then
        return string.format("%-10s %6s %5s %7s %12s", "Reactor", "EU/t", "Temp", "AvgDmg", "State")
    elseif dev_type == "bat" then
        return string.format("%-15s %7s %7s %7s %12s", "Battery", "Charge", "In", "Out", "State")
    else
        return string.format("%-15s %12s", "Device", "State")
    end
end

-- Формат строки для разных типов
local function round(num)
    return math.floor(num + 0.5)
end

local function to_int(num)
    return math.floor(num or 0)
end

-- Формат строки для разных типов
local function format_device(name, info)
    local dev_type = info._type or "unknown"
    
    if dev_type == "react" then
        local eu = to_int(info.eu_output or info._euOutput or 0)
        local temp = to_int((info.temp or info["15 sec"] or 0) * 100)
        local dmg = to_int(info.rod_avg or info._rodAvgDamage or 0)
        local state = info.state or info._state or "?"
        
        return string.format("%-10s %6d %4d%% %7d %12s", 
            tostring(name):sub(1, 10), eu, temp, dmg, tostring(state):sub(1, 12))
    
    elseif dev_type == "bat" then
        local charge = to_int(info.charge or 0)
        local inp = to_int(info.input or 0)
        local out = to_int(info.output or 0)
        local state = info.state or info._state or "?"
        
        return string.format("%-15s %6d%% %7d %7d %12s",
            tostring(name):sub(1, 15), charge, inp, out, tostring(state):sub(1, 12))
    
    else
        local state = info.state or info._state or "?"
        return string.format("%-15s %12s", tostring(name):sub(1, 15), tostring(state):sub(1, 12))
    end
end

local function drawDisplay()
    term.clear()
    term.setCursor(1, 1)
    
    -- Группируем по типам
    local grouped = {}
    for name, info in pairs(displayData) do
        local t = info._type or "unknown"
        grouped[t] = grouped[t] or {}
        grouped[t][name] = info
    end
    
    local type_order = {"react", "bat", "turb"}
    local headers = {
        react = "=== Reactors ===",
        bat = "=== Batteries ===",
        turb = "=== Turbines ===",
    }
    
    local row = 1
    local first_group = true
    
    for _, dev_type in ipairs(type_order) do
        local devs = grouped[dev_type]
        if devs then
            if not first_group then
                row = row + 1
                term.setCursor(1, row)
                print("")
                row = row + 1
            end
            first_group = false
            
            term.setCursor(1, row)
            print(headers[dev_type] or ("=== " .. dev_type .. " ==="))
            row = row + 1
            
            term.setCursor(1, row)
            print(get_header(dev_type))
            row = row + 1
            
            term.setCursor(1, row)
            print(string.rep("-", 50))
            row = row + 1
            
            -- Сортировка по имени
            local names = {}
            for name in pairs(devs) do
                table.insert(names, name)
            end
            table.sort(names)
            
            for _, name in ipairs(names) do
                term.setCursor(1, row)
                print(format_device(name, devs[name]))
                row = row + 1
            end
        end
    end
    
    -- Статус соединения
    row = row + 1
    term.setCursor(1, row)
    
    local now = os.time()
    if lastPacketTime > 0 then
        local lastReceived = now - lastPacketTime
        print(string.format("Packets: %d | Last update: %ds ago", packetCount, lastReceived))
    else
        print("Waiting for data...")
    end
    
    row = row + 1
    term.setCursor(1, row)
    print("Press Q to exit")
end

local running = true

local function check_exit(_, _, char, code)
    if char == 113 or char == 1049 or code == 16 or code == 113 then
        running = false
    end
end

event.listen("key_down", check_exit)

drawDisplay()

while running do
    local signal = {event.pull(0.5, "modem_message")}
    
    if signal[1] == "modem_message" then
        local remoteAddress = signal[3]
        local senderPort = signal[4]
        local msg = signal[6]
        
        if senderPort == port and msg then
            packetCount = packetCount + 1
            lastPacketTime = os.time()
            
            local ok, payload = pcall(serial.unserialize, msg)
            
            if ok and type(payload) == "table" then
                -- Обновляем данные
                for name, info in pairs(payload) do
                    displayData[name] = info
                end
                
                drawDisplay()
                
                if retransmit then
                    modem.broadcast(port, msg)
                end
            end
        end
    end
end

event.ignore("key_down", check_exit)
term.clear()
modem.close(port)
print("Stopped")