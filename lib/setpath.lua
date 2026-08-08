local function setupPaths()
    -- Проверяем, существует ли диск C: (Windows)
    local isWindows = pcall(io.open, "C:\\", "r")
    
    if isWindows then
        package.path = "./?.lua;./lib/?.lua;./lib/?/init.lua;./mocks/?.lua;./OOSAPI/?.lua;" .. package.path
        package.cpath = "./?.dll;./lib/?.dll;" .. package.cpath
        print("✅ Local mode: paths configured")
    else
        print("ℹ️ OpenComputers mode: using default paths")
    end
end

return setupPaths