local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local title = {}

function title:enter(_, d, p)
    self.d, self.p = d, p
end

function title:draw()
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.setFont(fonts.big)
    love.graphics.printf("Code Defense", 0, 180, 960, "center")
    love.graphics.setFont(fonts.ui)
    love.graphics.printf("코드로 타워를 조종해 서버를 지켜라", 0, 240, 960, "center")
    love.graphics.printf("Enter 키를 눌러 시작", 0, 380, 960, "center")
    love.graphics.setFont(fonts.small)
    love.graphics.printf("ESC 종료", 0, 420, 960, "center")
end

function title:keypressed(key)
    if key == "return" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
