local pt = dofile("lib/setpath.lua")()

local component = require("component")
local event = require("event")
local os = require("os")
local serial = require("serialization")
local shell = require("shell")
local term = require("term")
local sides = require("sides")

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

local config = loadFile("reactor_sender_config.lua")
if not config then
    return
end

local helpers = loadFile("lib/helpers.lua")
if not helpers then
    print("helpers.lua not found in lib/")
    return
end

local rebootTime = config.rebootTime or 60
local port = config.port or 1
local interval = config.interval or 2
local broadcast = true
if config.broadcast ~= nil then
    broadcast = config.broadcast
end

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

local reactors = {}

for _, reactorConfig in ipairs(config.reactors or {}) do
    local address = reactorConfig.address
    local name = reactorConfig.name or "Unknown"
    local dev_type = reactorConfig.type or "react"
    local invAddress = reactorConfig.inv_address
    local invSide = reactorConfig.inv_side
    local redAddress = reactorConfig.red_address
    local redSide = reactorConfig.red_side


    if invSide == nil then
        invSide = sides.front
    elseif type(invSide) == "string" then
        invSide = sides[invSide] or sides.front
    end

    if redSide == nil then
        redSide = sides.front
    elseif type(redSide) == "string" then
        redSide = sides[redSide] or sides.front
    end


    if not address then
        print("Skipped '" .. name .. "' - no address")
        goto continue
    end

    local proxy = component.proxy(address)
    if not proxy then
        print("Component '" .. name .. "' not found: " .. address)
        goto continue
    end

    if dev_type == "react" and proxy.type ~= "reactor_chamber" then
        print(address .. " is not reactor (type: " .. proxy.type .. ")")
        goto continue
    end

    local invProxy = nil
    if invAddress then
        invProxy = component.proxy(invAddress)
        if not invProxy then
            print("Inventory controller '" .. name .. "' not found: " .. invAddress)
        end
    end

    local redProxy = nil
    if redAddress then
        redProxy = component.proxy(redAddress)
        if not redProxy then
            print("Redstone controller '" .. name .. "' not found: " .. redAddress)
        else
            redProxy.setOutput(redSide, 15)
        end
  
    end

    reactors[#reactors + 1] = {
        name = name,
        address = address,
        proxy = proxy,
        type = dev_type,
        invProxy = invProxy,
        invSide = invSide,
        redProxy = redProxy,
        redSide = redSide,
        lastError = nil,
        rebootStartedAt = -1,
    }
    print("Connected: " .. name .. " (" .. dev_type .. ")")

    ::continue::
end

if #reactors == 0 then
    print("No components available")
    return
end

local function getReactorData(reactor)
    local proxy = reactor.proxy
    local redProxy = reactor.redProxy
    local data = {}

    local ok, heat = pcall(function() return proxy.getHeat() end)
    if ok then
        data.heat = heat
    else
        data.heat = 0
        reactor.lastError = "getHeat"
    end

    local ok, maxHeat = pcall(function() return proxy.getMaxHeat() end)
    if ok then
        data.maxHeat = maxHeat
    else
        data.maxHeat = 100
        reactor.lastError = "getMaxHeat"
    end

    local euOutput = 0
    if proxy.getReactorEUOutput then
        local ok, val = pcall(function() return proxy.getReactorEUOutput() end)
        if ok then euOutput = val end
    end
    if euOutput == 0 and proxy.getEUOutput then
        local ok, val = pcall(function() return proxy.getEUOutput() end)
        if ok then euOutput = val end
    end
    data.euOutput = euOutput

    local active = false
    if proxy.producesEnergy then
        local ok, val = pcall(function() return proxy.producesEnergy() end)
        if ok then active = val end
    end
    if not active and proxy.isActive then
        if type(proxy.isActive) == "function" then
            local ok, val = pcall(function() return proxy.isActive() end)
            if ok then active = val end
        else
            active = proxy.isActive or false
        end
    end
    data.active = active

    if data.maxHeat > 0 then
        data.temp = data.heat / data.maxHeat
    else
        data.temp = 0
    end

    local rebootCount = rebootTime - (os.time() - reactor.rebootStartedAt)    
    reactor.rebootCount = rebootCount

    if reactor.rebootStartedAt ~= -1 and rebootCount > 0 then

    elseif reactor.rebootStartedAt ~= -1 and rebootCount <= 0 then
        
        reactor.rebootStartedAt = -1
        redProxy.setOutput(reactor.redSide, 15)

    elseif proxy.isActive and proxy.getEUOutput then

        local ok_1, euVal  = pcall(function() return proxy.getEUOutput() end)
        local ok_2, actVal = pcall(function() return proxy.isActive() end)
        local ok = ok_1 and ok_2
        
        if ok then            
            if actVal and euVal <= 1 then
                reactor.rebootStartedAt = os.time()
                redProxy.setOutput(reactor.redSide, 0)
            end
        end
        
    end

    data.timestamp = os.time()

    return data
end

local reactorDataCache = {}
local rodDataCache = {}

local function updateCache()
    for _, reactor in ipairs(reactors) do
        reactorDataCache[reactor.name] = getReactorData(reactor)
    end
end

local function updateRodData()
    for _, reactor in ipairs(reactors) do
        if reactor.invProxy then
            local avgDamage, count = helpers.getAverageRodDamage(reactor.invProxy, reactor.invSide)
            rodDataCache[reactor.name] = {
                avgDamage = avgDamage,
                count = count
            }
        end
    end
end

local function drawDisplay()
    term.clear()
    term.setCursor(1, 1)
    print(helpers.format_header())
    print(helpers.format_separator())

    local row = 3
    for _, reactor in ipairs(reactors) do
        local data = reactorDataCache[reactor.name]
        local rods = rodDataCache[reactor.name]
        if data then
            term.setCursor(1, row)
            local line = helpers.format_reactor(
                reactor.name,
                data.euOutput or 0,
                data.temp or 0,
                rods and rods.avgDamage or 0,
                reactor.rebootCount
            )
            io.write(line .. "\n")
        end
        row = row + 1
    end
end

local function sendData()
    updateCache()

    local payload = {}
    local hasError = false

    for _, reactor in ipairs(reactors) do
        local data = reactorDataCache[reactor.name]
        local rods = rodDataCache[reactor.name] or {}

        payload[reactor.name] = {
            ["15 sec"] = data.temp,
            ["5 min"]  = data.temp,
            ["1 hour"] = data.temp,
            ["1 day"]  = data.temp,
            _type = reactor.type,
            _heat = data.heat,
            _maxHeat = data.maxHeat,
            _euOutput = data.euOutput,
            _active = data.active,
            _rodAvgDamage = rods.avgDamage or 101,
        }

        if reactor.lastError then
            hasError = true
            reactor.lastError = nil
        end
    end

    local serialized = serial.serialize(payload)

    if broadcast then
        modem.broadcast(port, serialized)
    else
        if config.targetAddress then
            modem.send(config.targetAddress, port, serialized)
        else
            print("No target address")
            return
        end
    end

    drawDisplay()

    local status = hasError and "⚠️" or "📡"
    term.setCursor(1, 4 + #reactors + 2)
end

updateCache()
updateRodData()
drawDisplay()
term.setCursor(1, 5 + #reactors + 2)
print("Press Q to exit")

sendData()

local running = true
local rodUpdateCounter = 0

event.listen("key_down", function(_, _, char, code)
    if char == 113 or code == 81 then
        running = false
    end
end)

while running do
    local deadline = os.time() + interval

    while os.time() < deadline and running do
        event.pull(0.1)
    end

    if running then
        rodUpdateCounter = rodUpdateCounter + 1

        if rodUpdateCounter >= 5 then
            rodUpdateCounter = 0
            updateRodData()
        end

        sendData()
    end
end

for _, reactor in ipairs(reactors) do
    reactor.redProxy.setOutput(reactor.redSide, 0);
end

term.clear()
modem.close(port)
print("Stopped")