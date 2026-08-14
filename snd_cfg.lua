-- snd_cfg.lua
local config = {
    -- Общие настройки
    port = 1,
    interval = 2,
    broadcast = true,
    targetAddress = nil,
    
    -- Устройства сгруппированы по типам
    devices = {
        react = {
            {
                name = "Reactor1",
                id = "react_1",
                address = "mock-reactor-0001",
                inv_address = "mock-inv-0001",
                inv_side = "front",
                red_address = "mock-redstone-0001",
                red_side = "front",
                reboot_time = 60,
            },
            {
                name = "Reactor2",
                id = "react_2",
                address = "mock-reactor-0002",
                inv_address = "mock-inv-0002",
                inv_side = "front",
                red_address = "mock-redstone-0001",
                red_side = "front",
                reboot_time = 60,
            },           
        },    
        bat = {
             {
                name = "Main buffer",
                id = "bat_storage",
                addresses = {
                    "mock-battery-0002",
                    "mock-battery-0001",
                },
                battery_count = 4,
                thresholds = {
                    full = 95,
                    high = 80,
                    low = 20,
                    empty = 5,
                },
            },
        }
    },
}

return config