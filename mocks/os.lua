local os_mock = {}

local time = 0

function os_mock.time()
    time = time + 1
    return time
end

function os_mock.sleep(seconds)
    -- В тестах просто пропускаем
end

function os_mock.date(format, timestamp)
    if format == "%H:%M:%S" then
        return "12:34:56"
    end
    return "2024-01-01"
end

function os_mock.getenv(name)
    return nil
end

function os_mock.execute(cmd)
    return 0
end

return os_mock