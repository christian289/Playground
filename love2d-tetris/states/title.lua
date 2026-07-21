local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local title = {}

local CONTROLS = [[
LEFT / RIGHT   MOVE
DOWN           SOFT DROP
SPACE          HARD DROP
UP / X         ROTATE CW
Z              ROTATE CCW
C / SHIFT      HOLD
P              PAUSE]]

function title:draw()
    local w = love.graphics.getWidth()
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.35, 0.80, 0.90)
    love.graphics.printf("TETRIS", 0, 120, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("PRESS ENTER TO START", 0, 220, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf(CONTROLS, 140, 300, w - 140, "left")

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("ESC  QUIT", 0, 560, w, "center")
end

function title:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
