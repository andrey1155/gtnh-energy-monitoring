local shell_mock = {
    workingDir = ".",
}

function shell_mock.getWorkingDirectory()
    return shell_mock.workingDir
end

function shell_mock.setWorkingDirectory(path)
    shell_mock.workingDir = path
end

function shell_mock.execute(cmd)
    print("EXEC: " .. cmd)
    return 0
end

return shell_mock