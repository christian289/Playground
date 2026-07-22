local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local art = require("src.art")

local title = {}

local ITEMS = { "게임 시작", "세계관", "도감", "종료" }

function title:enter(_, d, p)
    self.d, self.p = d, p
    self.cursor = 1
end

-- 서버실 배경 + 책상 앞 개발자 뒷모습 (하단 밴드에 배치 — 상단은 로고·메뉴 공간)
local function drawBackground(t)
    local P = art.pal
    local FLOOR = 452
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, 960, 640)
    -- 상단 어두운 비네트(로고/메뉴 영역 톤)
    love.graphics.setColor(0.03, 0.04, 0.08)
    love.graphics.rectangle("fill", 0, 0, 960, FLOOR)
    -- 바닥
    love.graphics.setColor(0.05, 0.07, 0.12)
    love.graphics.rectangle("fill", 0, FLOOR, 960, 640 - FLOOR)
    love.graphics.setColor(P.grid[1], P.grid[2], P.grid[3], 0.5)
    for i = 0, 960, 48 do love.graphics.rectangle("fill", i, FLOOR, 1, 640 - FLOOR) end
    for j = 0, 640 - FLOOR, 26 do love.graphics.rectangle("fill", 0, FLOOR + j, 960, 1) end
    -- 서버랙 실루엣 열 (뒤 벽, 좌우로 뻗음) — 바닥 밴드에 앉힘
    for i = 0, 11 do
        love.graphics.push()
        love.graphics.translate(i * 84 - 6, FLOOR - 66)
        love.graphics.scale(2.0)
        art.drawWall(0, 0, t + i * 0.4)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1)
    -- 책상 + 모니터 + 개발자 뒷모습 (중앙 전경)
    local cx = 480
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
    drawBackground(t)

    -- 로고
    art.drawLogo(480, 52)
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.7, 0.75, 0.82)
    love.graphics.printf("코드로 타워를 조종해 서버를 지켜라", 0, 126, 960, "center")

    -- 메뉴
    love.graphics.setFont(fonts.big)
    local P = art.pal
    for i, item in ipairs(ITEMS) do
        local y = 172 + (i - 1) * 48
        if i == self.cursor then
            love.graphics.setColor(P.green[1], P.green[2], P.green[3])
            love.graphics.printf("> " .. item .. " <", 0, y, 960, "center")
        else
            love.graphics.setColor(0.7, 0.74, 0.8)
            love.graphics.printf(item, 0, y, 960, "center")
        end
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.55, 0.6, 0.66)
    love.graphics.printf("↑↓ 이동 · Enter 선택", 0, 372, 960, "center")
    love.graphics.setColor(1, 1, 1)
end

function title:keypressed(key)
    if key == "up" then
        self.cursor = (self.cursor - 2) % #ITEMS + 1
    elseif key == "down" then
        self.cursor = self.cursor % #ITEMS + 1
    elseif key == "return" then
        if self.cursor == 1 then
            Gamestate.switch(require("states.stageselect"), self.d, self.p)
        elseif self.cursor == 2 then
            Gamestate.switch(require("states.intro"), self.d, self.p, "title")
        elseif self.cursor == 3 then
            Gamestate.switch(require("states.codex"), self.d, self.p)
        else
            love.event.quit()
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
