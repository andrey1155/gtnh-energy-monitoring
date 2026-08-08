local term_mock = {
    buffer = {},
    cursorX = 1,
    cursorY = 1,
}

function term_mock.clear()
    term_mock.buffer = {}
    term_mock.cursorX = 1
    term_mock.cursorY = 1
end

function term_mock.setCursor(x, y)
    term_mock.cursorX = x
    term_mock.cursorY = y
end

function term_mock.getCursor()
    return term_mock.cursorX, term_mock.cursorY
end

function term_mock.write(text)
    table.insert(term_mock.buffer, text)
    print(text)
end

function term_mock.getViewport()
    return 80, 25
end

return term_mock