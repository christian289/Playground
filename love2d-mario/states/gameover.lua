local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local gameover = {}

function gameover:enter(previous, data)
    data = data or {}
    self.score = data.score or 0
end

function gameover:draw()
    local w = love.graphics.getWidth()
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, w, love.graphics.getHeight())

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.95, 0.30, 0.25)
    love.graphics.printf("GAME OVER", 0, 200, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SCORE  " .. self.score, 0, 300, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.printf("ENTER  RETRY        ESC  TITLE", 0, 380, w, "center")
end

function gameover:keypressed(key)
    if key == "return" or key == "kpenter" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        Gamestate.switch(require("states.title"))
    end
end

return gameover
