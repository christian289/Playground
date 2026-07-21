local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.45, 0.70, 0.95)
    fonts.load()
    Gamestate.registerEvents()
    Gamestate.switch(require("states.title"))
end
