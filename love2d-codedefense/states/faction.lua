-- states/faction.lua — 타이틀 "게임 시작" 다음에 오는 진영 선택 화면(신규, Wave D Task 3).
-- 뷰 전용: 진영 판정(어떤 스테이지가 어느 진영인지)은 src/factions.lua(순수 로직)에 위임하고,
-- 여기서는 메뉴 렌더링과 stageselect로의 전달만 한다.
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local art = require("src.art")
local factions = require("src.factions")

local faction = {}

local ITEMS = {
    { key = "lua", label = "Lua 진영", desc = "스크립트로 방어한다", color = "green" },
    { key = "shell", label = "Shell 진영", desc = "명령줄로 방어한다", color = "cyan" },
}
local MENU_Y0, MENU_STEP = 220, 76 -- 항목당 y 밴드(라벨+설명 두 줄을 담을 만큼 넉넉히)

function faction:enter(_, d, p)
    self.d, self.p = d, p
    self.cursor = 1
    -- 셸 스테이지가 하나도 없으면(Task 4 데이터 도입 전) Shell 항목을 "(준비 중)"으로 표시하고
    -- 진입을 막는다 — 이번 태스크(뷰) 커밋 시점의 안전장치.
    self.shellReady = #factions.idsFor(d.stages, "shell") > 0
end

local function itemAt(y)
    local rel = y - (MENU_Y0 - MENU_STEP / 2)
    if rel < 0 then return nil end
    local i = math.floor(rel / MENU_STEP) + 1
    if i >= 1 and i <= #ITEMS then return i end
    return nil
end

function faction:blocked(i)
    return ITEMS[i].key == "shell" and not self.shellReady
end

-- cursor(선택된 진영)에 해당하는 동작을 실행한다(Enter/좌클릭 공용). 막힌 항목은 무시.
function faction:choose()
    if self:blocked(self.cursor) then return end
    Gamestate.switch(require("states.stageselect"), self.d, self.p, ITEMS[self.cursor].key)
end

function faction:draw()
    local P = art.pal
    local W = love.graphics.getWidth()
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, W, 640)

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
    love.graphics.printf("진영 선택", 0, 110, W, "center")
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.7, 0.75, 0.82)
    love.graphics.printf("서버를 지킬 방법을 골라라", 0, 160, W, "center")

    for i, item in ipairs(ITEMS) do
        local y = MENU_Y0 + (i - 1) * MENU_STEP
        local blocked = self:blocked(i)
        local col = P[item.color] or P.white
        if blocked then
            love.graphics.setColor(0.35, 0.38, 0.42)
        elseif i == self.cursor then
            love.graphics.setColor(col[1], col[2], col[3])
        else
            love.graphics.setColor(0.7, 0.74, 0.8)
        end
        love.graphics.setFont(fonts.big)
        local label = item.label .. (blocked and " (준비 중)" or "")
        if i == self.cursor and not blocked then label = "> " .. label .. " <" end
        love.graphics.printf(label, 0, y, W, "center")
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(blocked and 0.4 or 0.65, blocked and 0.42 or 0.7, blocked and 0.46 or 0.76)
        love.graphics.printf(item.desc, 0, y + 34, W, "center")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.55, 0.6, 0.66)
    love.graphics.printf("↑↓/마우스 이동 · Enter/클릭 선택 · ESC 타이틀", 0, 460, W, "center")
    love.graphics.setColor(1, 1, 1)
end

function faction:keypressed(key)
    if key == "up" then
        self.cursor = (self.cursor - 2) % #ITEMS + 1
    elseif key == "down" then
        self.cursor = self.cursor % #ITEMS + 1
    elseif key == "return" then
        self:choose()
    elseif key == "escape" then
        Gamestate.switch(require("states.title"), self.d, self.p)
    end
end

function faction:mousemoved(_, y)
    local i = itemAt(y)
    if i then self.cursor = i end
end

function faction:mousepressed(x, y, button)
    if button ~= 1 then return end
    local i = itemAt(y)
    if i then
        self.cursor = i
        self:choose()
    end
end

return faction
