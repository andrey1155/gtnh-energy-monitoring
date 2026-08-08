local config = {
    port = 1,
    interval = 2,
    broadcast = true,
    targetAddress = nil,
    reactors = {
        {
            type = "react",
            name = "Reactor1",
            address = "mock-reactor-0001",
            inv_address = "mock-inv-0001",
            inv_side = "front",
        },
        {
            type = "react",
            name = "Reactor2",
            address = "mock-reactor-0002",
            inv_address = "mock-inv-0002",
            inv_side = "front",
        },
    }
}

return config