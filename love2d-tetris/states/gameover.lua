local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local gameover = {}

function gameover:enter(previous, score, lines, level)
    self.score = score or 0
    self.lines = lines or 0
    self.level = level or 1
end

function gameover:draw()
    local w = love.graphics.getWidth()
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.9, 0.3, 0.3)
    love.graphics.printf("GAME OVER", 0, 160, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SCORE  " .. self.score, 0, 280, w, "center")
    love.graphics.printf("LINES  " .. self.lines .. "    LEVEL  " .. self.level, 0, 310, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.printf("ENTER  RETRY        ESC  TITLE", 0, 420, w, "center")
end

function gameover:keypressed(key)
    if key == "return" or key == "kpenter" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        Gamestate.switch(require("states.title"))
    end
end

return gameover
