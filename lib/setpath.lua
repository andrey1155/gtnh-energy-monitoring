local function setupPaths()
    -- Способ 1: Проверка через компонент filesystem (если есть)
    local hasFilesystem = pcall(require, "filesystem")
    if hasFilesystem then
        local filesystem = require("filesystem")
        -- Проверяем корневую директорию
        local isOC = filesystem.exists("/")
        if isOC then
            print("ℹ️ OpenComputers mode: using default paths")
            return
        end
    end
    
    -- Способ 2: Проверка через component API
    local hasComponent = pcall(require, "component")
    if hasComponent then
        local component = require("component")
        -- Проверяем наличие характерных для OC компонентов
        if component.isAvailable("filesystem") or component.isAvailable("gpu") then
            print("ℹ️ OpenComputers mode: using default paths")
            return
        end
    end
    
    -- Способ 3: Проверка через package.config (наличие обратных слешей)
    if package.config:sub(1,1) == "\\" then
        -- Это Windows, но проверяем дополнительно
        local testFile, err = io.open("C:\\Windows\\System32\\kernel32.dll", "r")
        if testFile then
            testFile:close()
            -- Реальный Windows
            package.path = "./?.lua;./lib/?.lua;./lib/?/init.lua;./mocks/?.lua;./OOSAPI/?.lua;" .. package.path
            package.cpath = "./?.dll;./lib/?.dll;" .. package.cpath
            print("✅ Local mode: paths configured")
            return
        end
    end
    
    -- Если ничего не сработало - считаем что в OC
    print("ℹ️ OpenComputers mode: using default paths")
end

return setupPaths