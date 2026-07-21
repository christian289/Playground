-- 라이브러리 로드 확인용 스텁. 게임 로직은 여기서부터 바이브코딩으로 채워 나갑니다.
local Gamestate = require("lib.hump.gamestate")
local Timer = require("lib.hump.timer")
local Object = require("lib.classic")

local title = {}

function title:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("TETRIS", 0, 260, love.graphics.getWidth(), "center")
    love.graphics.printf("라이브러리 로드 OK - 게임 로직을 만들어 주세요", 0, 300, love.graphics.getWidth(), "center")
end

function title:keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function love.load()
    love.graphics.setNewFont(18)
    Gamestate.registerEvents()
    Gamestate.switch(title)
end

function love.update(dt)
    Timer.update(dt)
end
