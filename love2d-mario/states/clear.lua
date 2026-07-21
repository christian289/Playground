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
    love.graphics.printf("코스 클리어!", 0, 190, w, "center")

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("점수  " .. self.score .. "      코인  " .. self.coins, 0, 290, w, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.printf("Enter  한 번 더        ESC  타이틀", 0, 370, w, "center")
end

function clear:keypressed(key)
    if key == "return" or key == "kpenter" then
        Gamestate.switch(require("states.play"))
    elseif key == "escape" then
        Gamestate.switch(require("states.title"))
    end
end

return clear
