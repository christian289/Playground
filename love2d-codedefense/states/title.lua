local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local art = require("src.art")

local title = {}

local ITEMS = { "게임 시작", "세계관", "도감", "종료" }
local MENU_Y0, MENU_STEP = 160, 48 -- 항목 y 시작·간격(각 항목이 이 간격만큼의 y 밴드를 차지)

function title:enter(_, d, p)
    self.d, self.p = d, p
    self.cursor = 1
end

-- 마우스 y 좌표가 몇 번째 메뉴 항목 밴드 위에 있는지(항목 y 범위 판정). 없으면 nil.
local function itemAt(y)
    local rel = y - (MENU_Y0 - MENU_STEP / 2)
    if rel < 0 then return nil end
    local i = math.floor(rel / MENU_STEP) + 1
    if i >= 1 and i <= #ITEMS then return i end
    return nil
end

-- cursor(선택된 메뉴 인덱스)에 해당하는 동작을 실행한다(Enter/좌클릭 공용).
function title:choose()
    if self.cursor == 1 then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
    elseif self.cursor == 2 then
        Gamestate.switch(require("states.intro"), self.d, self.p, "title")
    elseif self.cursor == 3 then
        Gamestate.switch(require("states.codex"), self.d, self.p)
    else
        love.event.quit()
    end
end

-- 서버실 배경 + 책상 앞 개발자 뒷모습 (하단 밴드에 배치 — 상단은 로고·메뉴 공간)
local function drawBackground(t)
    local P = art.pal
    local W = love.graphics.getWidth()
    local FLOOR = 452
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, W, 640)
    -- 상단 어두운 비네트(로고/메뉴 영역 톤)
    love.graphics.setColor(0.03, 0.04, 0.08)
    love.graphics.rectangle("fill", 0, 0, W, FLOOR)
    -- 바닥
    love.graphics.setColor(0.05, 0.07, 0.12)
    love.graphics.rectangle("fill", 0, FLOOR, W, 640 - FLOOR)
    love.graphics.setColor(P.grid[1], P.grid[2], P.grid[3], 0.5)
    for i = 0, W, 48 do love.graphics.rectangle("fill", i, FLOOR, 1, 640 - FLOOR) end
    for j = 0, 640 - FLOOR, 26 do love.graphics.rectangle("fill", 0, FLOOR + j, W, 1) end
    -- 서버랙 실루엣 열 (뒤 벽, 좌우로 뻗음) — 바닥 밴드에 앉힘, 창 폭 전체를 채운다
    for i = 0, math.ceil(W / 84) do
        love.graphics.push()
        love.graphics.translate(i * 84 - 6, FLOOR - 66)
        love.graphics.scale(2.0)
        art.drawWall(0, 0, t + i * 0.4)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1)
    -- 책상 + 모니터 + 개발자 뒷모습 (중앙 전경)
    local cx = W / 2
    -- 모니터 발광 원뿔
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.12)
    love.graphics.polygon("fill", cx, 486, cx - 150, 640, cx + 150, 640)
    -- 책상
    love.graphics.setColor(0.14, 0.10, 0.07)
    love.graphics.rectangle("fill", cx - 160, 588, 320, 52)
    love.graphics.setColor(0.09, 0.06, 0.04)
    love.graphics.rectangle("fill", cx - 160, 588, 320, 6)
    -- 모니터 (뒷면에서 새어나오는 빛)
    love.graphics.setColor(0.06, 0.09, 0.14)
    love.graphics.rectangle("fill", cx - 78, 492, 156, 100)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.45 + 0.1 * math.sin(t * 2))
    love.graphics.rectangle("fill", cx - 74, 496, 148, 6)
    -- 개발자 뒷모습 (후드 + 뒤통수 + 어깨)
    local hood, hoodDk, hair = { 0.23, 0.29, 0.42 }, { 0.16, 0.21, 0.32 }, { 0.29, 0.21, 0.15 }
    love.graphics.setColor(hood)
    love.graphics.rectangle("fill", cx - 52, 560, 104, 70)     -- 어깨/등
    love.graphics.setColor(hoodDk)
    love.graphics.rectangle("fill", cx - 52, 560, 104, 5)
    love.graphics.rectangle("fill", cx - 26, 528, 52, 38, 7, 7) -- 후드(뒤통수 감싼)
    love.graphics.setColor(hair)
    love.graphics.rectangle("fill", cx - 19, 537, 38, 27, 5, 5) -- 뒤통수 머리카락
    love.graphics.setColor(hoodDk)
    love.graphics.rectangle("fill", cx - 52, 566, 7, 60)       -- 팔(좌)
    love.graphics.rectangle("fill", cx + 45, 566, 7, 60)       -- 팔(우)
    love.graphics.setColor(1, 1, 1)
end

function title:draw()
    local t = love.timer.getTime()
    local W = love.graphics.getWidth()
    drawBackground(t)

    -- 룩 심볼 (로고 위, scale 4)
    local rookScale = 4
    art.drawRook(W / 2 - 8 * rookScale, 4, rookScale, t)

    -- 로고
    art.drawLogo(W / 2, 76)
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.7, 0.75, 0.82)
    love.graphics.printf("코드로 타워를 조종해 서버를 지켜라", 0, 112, W, "center")

    -- 메뉴
    love.graphics.setFont(fonts.big)
    local P = art.pal
    for i, item in ipairs(ITEMS) do
        local y = MENU_Y0 + (i - 1) * MENU_STEP
        if i == self.cursor then
            love.graphics.setColor(P.green[1], P.green[2], P.green[3])
            love.graphics.printf("> " .. item .. " <", 0, y, W, "center")
        else
            love.graphics.setColor(0.7, 0.74, 0.8)
            love.graphics.printf(item, 0, y, W, "center")
        end
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.55, 0.6, 0.66)
    love.graphics.printf("↑↓/마우스 이동 · Enter/클릭 선택", 0, 360, W, "center")
    love.graphics.setColor(1, 1, 1)
end

function title:keypressed(key)
    if key == "up" then
        self.cursor = (self.cursor - 2) % #ITEMS + 1
    elseif key == "down" then
        self.cursor = self.cursor % #ITEMS + 1
    elseif key == "return" then
        self:choose()
    elseif key == "escape" then
        love.event.quit()
    end
end

function title:mousemoved(_, y)
    local i = itemAt(y)
    if i then self.cursor = i end
end

function title:mousepressed(x, y, button)
    if button ~= 1 then return end
    local i = itemAt(y)
    if i then
        self.cursor = i
        self:choose()
    end
end

return title
