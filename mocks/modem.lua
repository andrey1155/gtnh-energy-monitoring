local modem_mock = {
    port = nil,
    isOpen = function(port) return true end,
    open = function(port) 
        modem_mock.port = port
        return true 
    end,
    close = function(port) 
        modem_mock.port = nil
        return true 
    end,
    send = function(address, port, data) 
        print(string.format("[MODEM] Send to %s:%d - %s", address, port, data))
        return true 
    end,
    broadcast = function(port, data) 
        print(string.format("[MODEM] Broadcast on %d - %s", port, data))
        return true 
    end,
    setStrength = function(power) return power end,
    getStrength = function() return 10 end,
    isWireless = function() return true end,
    type = "modem",
    address = "mock-modem-0001",
}

return modem_mock