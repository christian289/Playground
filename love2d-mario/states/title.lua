local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local title = {}

function title:draw()
    local w = love.graphics.getWidth()

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.95, 0.35, 0.30)
    love.graphics.printf("SUPER MARIO CLONE", 0, 140, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Enter 키를 눌러 시작", 0, 250, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.98, 0.98, 1)
    love.graphics.printf(
        "방향키 / WASD   이동\nSpace / Z / ↑   점프 (길게 누르면 높이 점프)\nP   일시정지      ESC   종료",
        0, 340, w, "center")

    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf("적을 밟고, 코인을 모아, 깃발까지 도달하세요!", 0, 460, w, "center")
end

function title:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
