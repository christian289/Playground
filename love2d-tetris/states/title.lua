local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local title = {}

local CONTROLS = [[
← / →        좌우 이동
↓             소프트 드롭
Space        하드 드롭
↑ / X        시계 방향 회전
Z             반시계 방향 회전
C / Shift    홀드
P             일시정지]]

function title:draw()
    local w = love.graphics.getWidth()
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.35, 0.80, 0.90)
    love.graphics.printf("TETRIS", 0, 110, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Enter 키를 눌러 시작", 0, 210, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf(CONTROLS, 130, 290, w - 130, "left")

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("ESC  종료", 0, 560, w, "center")
end

function title:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
