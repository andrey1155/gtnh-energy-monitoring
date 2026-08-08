local mock_component = {}

-- Хранилище для прокси компонентов
local proxies = {}

-- Базовые компоненты по умолчанию
local defaultComponents = {
    modem = {
        type = "modem",
        address = "mock-modem-0001",
        isOpen = function(port) return true end,
        open = function(port) return true end,
        close = function(port) return true end,
        send = function(address, port, data) return true end,
        broadcast = function(port, data) return true end,
        setStrength = function(power) return power end,
        getStrength = function() return 10 end,
        isWireless = function() return true end,
    },
    reactor1 = {
        type = "reactor_chamber",
        address = "mock-reactor-0001",
        getHeat = function() return 450 end,
        getMaxHeat = function() return 1000 end,
        getEUOutput = function() return 128 end,
        getReactorEUOutput = function() return 128 end,
        isActive = function() return true end,
        setActive = function(state) end,
        producesEnergy = function() return true end,
    },
    reactor2 = {
        type = "reactor_chamber",
        address = "mock-reactor-0002",
        getHeat = function() return 320 end,
        getMaxHeat = function() return 1000 end,
        getEUOutput = function() return 95 end,
        getReactorEUOutput = function() return 95 end,
        isActive = function() return true end,
        setActive = function(state) end,
        producesEnergy = function() return true end,
    },
    inv1 = {
        type = "inventory_controller",
        address = "mock-inv-0001",
        getInventorySize = function(side) return 9 end,
        getStackInSlot = function(side, slot)
            local items = {
                { name = "gregtech:gt.rodThorium4", damage = 45, size = 1 },
                { name = "gregtech:gt.rodUranium", damage = 30, size = 1 },
                { name = "gregtech:gt.rodPlutonium", damage = 60, size = 1 },
                { name = "gregtech:gt.rodThorium2", damage = 20, size = 1 },
            }
            return items[slot] or nil
        end,
        getStackInInternalSlot = function(slot)
            return { name = "item", damage = 0, size = 1 }
        end,
    },
    inv2 = {
        type = "inventory_controller",
        address = "mock-inv-0002",
        getInventorySize = function(side) return 9 end,
        getStackInSlot = function(side, slot)
            local items = {
                { name = "gregtech:gt.rodThorium4", damage = 70, size = 1 },
                { name = "gregtech:gt.rodUranium", damage = 50, size = 1 },
            }
            return items[slot] or nil
        end,
        getStackInInternalSlot = function(slot)
            return { name = "item", damage = 0, size = 1 }
        end,
    },
}

-- Регистрация компонентов в proxies
for _, comp in pairs(defaultComponents) do
    proxies[comp.address] = comp
end

-- Основные функции component
function mock_component.isAvailable(name)
    for _, comp in pairs(proxies) do
        if comp.type == name then
            return true
        end
    end
    return false
end

function mock_component.proxy(address)
    return proxies[address] or nil
end

function mock_component.list(filter, exact)
    local data = {}
    local tbl = {}
    for addr, comp in pairs(proxies) do
        if filter == nil or (exact and comp.type == filter) or (not exact and comp.type:find(filter, nil, true)) then
            data[#data + 1] = addr
            data[#data + 1] = comp.type
            tbl[addr] = comp.type
        end
    end
    local place = 1
    return setmetatable(tbl, {__call = function()
        local addr, type = data[place], data[place + 1]
        place = place + 2
        return addr, type
    end})
end

function mock_component.type(address)
    if proxies[address] then
        return proxies[address].type
    end
    return nil
end

-- Доступ через component.modem и т.д.
setmetatable(mock_component, {
    __index = function(_, key)
        for _, comp in pairs(proxies) do
            if comp.type == key then
                return comp
            end
        end
        return nil
    end
})

return mock_component