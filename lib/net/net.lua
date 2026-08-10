-- lib/net/net.lua
local serial = require("serialization")

local Net = {}

function Net:new(cfg)

    local net = {
        cfg = cfg,
        port = cfg.port or 1,
        broadcast = cfg.broadcast,
        target = cfg.targetAddress,
        modem = nil,  -- мок-модем
    }
    
    -- Пытаемся получить модем, если нет компонента - используем мок
    local component = require("component")
    if component.isAvailable and component.isAvailable("modem") then
        net.modem = component.modem
        if not net.modem.isOpen(net.port) then
            net.modem.open(net.port)
        end
    else
        -- Мок-модем
        net.modem = {
            isOpen = function(port) return true end,
            open = function(port) return true end,
            close = function(port) end,
            broadcast = function(port, data) 
                print("[NET] Broadcast on port " .. port)
                print("[NET] Data: " .. data:sub(1, 100) .. (data:len() > 100 and "..." or ""))
            end,
            send = function(address, port, data)
                print("[NET] Send to " .. address .. " on port " .. port)
                print("[NET] Data: " .. data:sub(1, 100) .. (data:len() > 100 and "..." or ""))
            end,
        }
    end
    
    setmetatable(net, {__index = Net})
    return net
end

function Net:send(payload)
    local data = serial.serialize(payload)

    if self.broadcast then
        self.modem.broadcast(self.port, data)
    else
        if self.target then
            self.modem.send(self.target, self.port, data)
        else
            print("[NET] No target address and broadcast disabled")
        end
    end
end

function Net:close()
    if self.modem then
        self.modem.close(self.port)
    end
end

return Net