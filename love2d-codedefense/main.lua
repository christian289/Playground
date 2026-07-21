local fonts = require("src.fonts")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    fonts.load()
end

function love.draw()
    love.graphics.setFont(fonts.big)
    love.graphics.printf("Code Defense 부팅 OK", 0, 300, 960, "center")
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end
