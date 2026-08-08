local helpers = {}

function helpers.round(num)
    return math.floor(num + 0.5)
end

function helpers.tostring_safe(val)
    return tostring(val or "")
end

function helpers.getAverageRodDamage(invProxy, side)
    if not invProxy then return 0, 0 end

    local totalDamage = 0
    local count = 0

    local ok, size = pcall(function() return invProxy.getInventorySize(side) end)
    if not ok or size == 0 then return 0, 0 end

    for i = 1, size do
        local ok, item = pcall(function() return invProxy.getStackInSlot(side, i) end)
        if ok and item and item.name and item.name:match("gregtech:gt%.rod") then
            totalDamage = totalDamage + (item.damage or 0)
            count = count + 1
        end
    end

    if count == 0 then
        return 0, 0
    end

    return totalDamage / count, count
end

function helpers.format_reactor(name, eu, temp, avgDmg)
    local name_str = helpers.tostring_safe(name):sub(1, 10)
    local eu_str = string.format("%5d", helpers.round(eu or 0))
    local temp_str = string.format("%3d%%", helpers.round((temp or 0) * 100))
    local dmg_str = string.format("%6d", helpers.round(avgDmg or 0))

    return name_str .. " " .. eu_str .. " " .. temp_str .. " " .. dmg_str
end

function helpers.format_header()
    return "Reactor   | EU/t | T  | AvgDmg"
end

function helpers.format_separator()
    return string.rep("-", 35)
end

return helpers