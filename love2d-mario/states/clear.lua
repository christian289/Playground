local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local clear = {}

function clear:enter(previous, data)
    data = data or {}
    self.score = data.score or 0
    self.coins = data.coins or 0
end

function clear:draw()
    local w = love.graphics.getWidth()

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.25, 0.85, 0.35)
    love.graphics.printf("COURSE CLEAR!", 0, 190, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SCORE  " .. self.score .. "      COINS  " .. self.coins, 0, 290, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.printf("ENTER  PLAY AGAIN        ESC  TITLE", 0, 370, w, "center")
end

function clear:keypressed(key)
    if key == "return" or key == "kpenter" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        Gamestate.switch(require("states.title"))
    end
end

return clear
