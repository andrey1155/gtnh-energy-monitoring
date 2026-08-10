local pt = dofile("lib/setpath.lua")()

local component = require("component")
local event = require("event")
local os = require("os")
local serial = require("serialization")
local term = require("term")
local shell = require("shell")

local currentDir = shell.getWorkingDirectory()

local function loadFile(path)
    local fullPath = currentDir .. "/" .. path
    local ok, result = pcall(dofile, fullPath)
    if not ok then
        print("ERROR loading " .. path .. ": " .. tostring(result))
        return nil
    end
    return result
end

local config = loadFile("reactor_receiver_config.lua")
if not config then
    config = { port = 1, retransmit = false, retransmit_power = 10 }
end

local port = config.port or 1
local retransmit = config.retransmit or false
local retransmitPower = config.retransmit_power or 10

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

local function drawDisplay()
    term.clear()
    term.setCursor(1, 1)
    print("Name       | EU/t | T  | Durability")
    print(string.rep("-", 40))

    local row = 3
    for name, info in pairs(displayData) do
        term.setCursor(1, row)
        local type = info._type or "react"

        local name_str = tostring(name):sub(1, 10)
        local eu = round(info._euOutput or 0)
        local temp = round((info["15 sec"] or 0) * 100)

        if type == "react" then
            local dmg = info._rodAvgDamage or 0
            local durability = round(100 - dmg)
            io.write(string.format("%-10s %5d %3d%% %6d\n", name_str, eu, temp, durability))
        else
            io.write(string.format("%-10s %5d %3d%%\n", name_str, eu, temp))
        end
        row = row + 1
    end

    local now = os.time()
    local lastReceived = (now - lastPacketTime)
    if lastPacketTime > 0 and lastReceived > 5 then
        term.setCursor(1, row + 2)
        io.write("⚠️ NO DATA FOR " .. lastReceived .. "s")
    end

    term.setCursor(1, row + 3)
    local lastReceived = os.time() - lastPacketTime
    if lastReceived > 100000 then
        lastReceived = -1
    end

    io.write("Last update: " .. lastReceived .. "s ago")
end

local running = true

event.listen("key_down", function(_, _, char, code)
    if char == 113 or code == 81 then
        running = false
    end
end)

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

            -- Показываем от кого пришёл пакет
            local source = remoteAddress or "unknown"
            
            local ok, payload = pcall(serial.unserialize, msg)

            if ok and type(payload) == "table" then
                -- Обновляем данные

                for name, info in pairs(payload) do
                    displayData[name] = info
                    print(name)
                end
                drawDisplay()
                
                term.setCursor(1, 4 + #displayData + 2)
                --- io.write("Source: " .. source)

                if retransmit then
                    modem.broadcast(port, msg)
                end

            end
        end
    end
end

term.clear()
modem.close(port)
print("Stopped")