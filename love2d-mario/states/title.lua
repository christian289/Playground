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
    love.graphics.printf("PRESS ENTER TO START", 0, 250, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.95, 0.95, 1)
    love.graphics.printf(
        "ARROWS / WASD   MOVE\nSPACE / Z / UP   JUMP  (HOLD FOR HIGHER)\nP   PAUSE      ESC   QUIT",
        0, 340, w, "center")

    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("STOMP ENEMIES, GRAB COINS, REACH THE FLAG!", 0, 460, w, "center")
end

function title:keypressed(key)
    if key == "return" or key == "kpenter" or key == "space" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
