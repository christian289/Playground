local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local art = require("src.art")

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
    local P = art.pal
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, 960, 640)
    -- 목록 패널
    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.85)
    love.graphics.rectangle("fill", 200, 96, 560, 470, 10, 10)

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
    love.graphics.printf("스테이지 선택", 0, 40, 960, "center")
    love.graphics.setFont(fonts.ui)
    for i, id in ipairs(self.ids) do
        local s = self.d.stages[id]
        local y = 118 + (i - 1) * 40
        local locked = not self:unlocked(id)
        if i == self.cursor then
            love.graphics.setColor(P.green[1], P.green[2], P.green[3], 0.14)
            love.graphics.rectangle("fill", 220, y - 4, 520, 32, 5, 5)
            love.graphics.setColor(P.green[1], P.green[2], P.green[3])
        elseif locked then love.graphics.setColor(0.35, 0.38, 0.42)
        else love.graphics.setColor(0.85, 0.88, 0.92) end
        local mark = self.p.cleared[id] and " [클리어]" or (locked and " [잠김]" or "")
        local prefix = (i == self.cursor) and "> " or "   "
        love.graphics.printf(("%s%d. %s%s"):format(prefix, id, s.concept, mark), 0, y, 960, "center")

        -- 배포 기록 표기 (§6.7)
        local rec = self.p.records and self.p.records[id]
        if rec then
            local recText
            if self.p.cleared[id] then
                -- "九"(구구 마크)는 나눔고딕에 글리프가 없어("九".hasGlyphs == false) "구"로 대체
                recText = ("[클리어 · HP %d%s]"):format(rec.bestHP, rec.gugu and " · 구" or "")
            else
                recText = ("[시도 %d]"):format(rec.tries)
            end
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.55, 0.58, 0.62)
            love.graphics.printf(recText, 500, y + 2, 250, "right")
            love.graphics.setFont(fonts.ui)
        end
    end
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("↑↓ 이동 · Enter 선택 · ESC 타이틀", 0, 600, 960, "center")
    love.graphics.setColor(1, 1, 1)
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
