-- env.lua
local function setupEnvironment()
    local component = require("mocks.component")
    local event = require("mocks.event")
    local sides = require("mocks.sides")
    local serial = require("mocks.serial")
    local os = require("mocks.os")
    local term = require("mocks.term")
    local shell = require("mocks.shell")
    
    -- Добавляем modem как отдельный компонент
    local modem = require("mocks.modem")
    component.modem = modem
    
    local env = {
        component = component,
        event = event,
        sides = sides,
        serial = serial,
        os = os,
        term = term,
        shell = shell,
        io = io,
        math = math,
        string = string,
        table = table,
        pcall = pcall,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        print = print,
        error = error,
    }
    
    return env
end

return setupEnvironment()