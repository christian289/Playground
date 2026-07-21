local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local sel = {}

function sel:enter(_, d, p)
    self.d, self.p = d, p
    self.ids = {}
    for id, s in pairs(d.stages) do
        if s.mode == "normal" then self.ids[#self.ids + 1] = id end
    end
    table.sort(self.ids)
    self.cursor = 1
end

function sel:unlocked(id)
    if id == self.ids[1] then return true end
    for i, sid in ipairs(self.ids) do
        if sid == id then return self.p.cleared[self.ids[i - 1]] end
    end
    return false
end

function sel:draw()
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.printf("스테이지 선택", 0, 40, 960, "center")
    love.graphics.setFont(fonts.ui)
    for i, id in ipairs(self.ids) do
        local s = self.d.stages[id]
        local y = 110 + (i - 1) * 40
        local locked = not self:unlocked(id)
        if i == self.cursor then love.graphics.setColor(1, 0.85, 0.3)
        elseif locked then love.graphics.setColor(0.35, 0.38, 0.42)
        else love.graphics.setColor(0.85, 0.88, 0.92) end
        local mark = self.p.cleared[id] and " [클리어]" or (locked and " [잠김]" or "")
        love.graphics.printf(("%d. %s%s"):format(id, s.concept, mark), 0, y, 960, "center")
    end
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("↑↓ 이동 · Enter 선택 · ESC 타이틀", 0, 600, 960, "center")
end

function sel:keypressed(key)
    if key == "up" then self.cursor = math.max(1, self.cursor - 1)
    elseif key == "down" then self.cursor = math.min(#self.ids, self.cursor + 1)
    elseif key == "return" then
        local id = self.ids[self.cursor]
        if self:unlocked(id) then
            Gamestate.switch(require("states.play"), self.d, id, self.p)
        end
    elseif key == "escape" then
        Gamestate.switch(require("states.title"), self.d, self.p)
    end
end

return sel
