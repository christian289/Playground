local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local db = require("src.db")
local progress = require("src.progress")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setKeyRepeat(true)
    fonts.load()
    local root = love.filesystem.getSource()
    local d = db.load(root)
    local errs = d.validate()
    if #errs > 0 then
        error("데이터 무결성 오류:\n" .. table.concat(errs, "\n"))
    end
    Gamestate.registerEvents()
    Gamestate.switch(require("states.title"), d, progress.load())
end
