local redstone = {
    type = "redstone",
    address = "mock-redstone-0001",
    outputs = {},
    inputs = {},
}

function redstone.getInput(side)
    if side == nil then return redstone.inputs end
    return redstone.inputs[side] or 0
end

function redstone.setOutput(side, value)
    if type(side) == "table" then
        for s, v in pairs(side) do redstone.outputs[s] = v end
        return
    end
    redstone.outputs[side] = value
end

function redstone.getOutput(side)
    if side == nil then return redstone.outputs end
    return redstone.outputs[side] or 0
end

function redstone.getBundledInput(side, color)
    if side == nil then return {} end
    if color == nil then return {} end
    return 0
end

function redstone.setBundledOutput(side, color, value)
    return 0
end

function redstone.getBundledOutput(side, color)
    if side == nil then return {} end
    if color == nil then return {} end
    return 0
end

function redstone.getWirelessInput() return 0 end
function redstone.getWirelessOutput() return false end
function redstone.setWirelessOutput(v) return false end
function redstone.getWirelessFrequency() return 0 end
function redstone.setWirelessFrequency(f) return 0 end
function redstone.getComparatorInput(side) return 0 end
function redstone.getWakeThreshold() return 0 end
function redstone.setWakeThreshold(t) return 0 end

return redstone