local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local art = require("src.art")
local stars = require("src.stars")
local factions = require("src.factions")

local sel = {}

-- ★/☆ 글리프: 오토플레이 스크린샷을 Read로 직접 확인한 결과 NanumGothic에 정상 렌더됨
-- (픽셀 검증 포함, .superpowers/sdd/wa-task-2-report.md 참고) — "*"/"-" 대체 불필요.
local STAR_FULL, STAR_EMPTY = "★", "☆"

local FACTION_LABEL = { lua = "Lua 진영", shell = "Shell 진영" }

-- faction(진영 선택 상태가 넘긴 "lua"|"shell", 없으면 "lua" 기본) 기준으로 목록을 구성한다.
-- 언락 판정은 src/factions.lua로 위임(진영 내 목록 이전 항목 클리어 기준 — 전역 id-1 참조 아님).
function sel:enter(_, d, p, faction)
    self.d, self.p = d, p
    self.faction = faction or "lua"
    self.ids = factions.idsFor(d.stages, self.faction)
    self.cursor = 1
    self.scroll = 0 -- 목록 스크롤 오프셋(0-indexed, 화면 첫 줄에 보이는 항목 = ids[scroll+1])
end

function sel:unlocked(id)
    return factions.unlocked(self.ids, self.p.cleared, id)
end

function sel:draw()
    local P = art.pal
    local W = love.graphics.getWidth()
    local OX = (W - 960) / 2 -- 960 기준 좌표(패널·목록)를 창 폭 중앙에 배치하는 오프셋
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, W, 640)

    -- 목록 패널 지오메트리 (스크롤 계산의 기준) — rowLeft/rowW는 커서 하이라이트·기록 텍스트
    -- 정렬에도 재사용해 항상 패널 안쪽에 들어가게 한다.
    local panelX, panelY, panelW, panelH = OX + 200, 96, 560, 470
    local rowLeft, rowW = OX + 220, 520
    local rowRight = rowLeft + rowW
    local rowSpacing = 40
    local topPad, bottomPad = 26, 26 -- "↑/↓ 더 있음" 표시용 여백(스크롤 여부와 무관하게 항상 예약해 목록 위치가 흔들리지 않게 함)
    local listTop = panelY + topPad
    local listBottom = panelY + panelH - bottomPad
    local visibleRows = math.max(1, math.floor((listBottom - listTop) / rowSpacing))

    -- 스크롤 오프셋: 커서가 화면 위/아래를 벗어나면 따라가게 클램프
    if self.cursor - 1 < self.scroll then self.scroll = self.cursor - 1 end
    if self.cursor - 1 > self.scroll + visibleRows - 1 then self.scroll = self.cursor - visibleRows end
    local maxScroll = math.max(0, #self.ids - visibleRows)
    self.scroll = math.max(0, math.min(self.scroll, maxScroll))

    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.85)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
    love.graphics.printf(("스테이지 선택 — %s"):format(FACTION_LABEL[self.faction] or self.faction), 0, 40, W, "center")
    love.graphics.setFont(fonts.ui)
    for j = 1, visibleRows do
        local i = self.scroll + j
        local id = self.ids[i]
        if not id then break end
        local s = self.d.stages[id]
        local y = listTop + (j - 1) * rowSpacing
        local locked = not self:unlocked(id)
        if i == self.cursor then
            love.graphics.setColor(P.green[1], P.green[2], P.green[3], 0.14)
            love.graphics.rectangle("fill", rowLeft, y - 4, rowW, 32, 5, 5)
            love.graphics.setColor(P.green[1], P.green[2], P.green[3])
        elseif locked then love.graphics.setColor(0.35, 0.38, 0.42)
        else love.graphics.setColor(0.85, 0.88, 0.92) end
        local mark = self.p.cleared[id] and " [클리어]" or (locked and " [잠김]" or "")
        local prefix = (i == self.cursor) and "> " or "   "
        love.graphics.printf(("%s%d. %s%s"):format(prefix, id, s.concept, mark), 0, y, W, "center")

        -- 배포 기록 표기 (§6.7) — 행(rowLeft~rowRight) 안쪽 오른쪽 정렬. 폭을 실측해
        -- rowRight - width - padding에 그려 행 배경 밖으로 벗어나지 않게 한다.
        local rec = self.p.records and self.p.records[id]
        if rec then
            local recText
            if self.p.cleared[id] then
                -- "九"(구구 마크)는 나눔고딕에 글리프가 없어("九".hasGlyphs == false) "구"로 대체
                local n = stars.of(rec.bestHP)
                local starText = STAR_FULL:rep(n) .. STAR_EMPTY:rep(3 - n)
                recText = ("[%s · HP %d%s]"):format(starText, rec.bestHP, rec.gugu and " · 구" or "")
            else
                recText = ("[시도 %d]"):format(rec.tries)
            end
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.55, 0.58, 0.62)
            local recPad = 14
            local recW = fonts.small:getWidth(recText)
            love.graphics.print(recText, rowRight - recPad - recW, y + 2)
            love.graphics.setFont(fonts.ui)
        end
    end

    -- 스크롤 인디케이터: 화면 밖에 항목이 더 있음을 알림(폰트에 없는 글리프 회피 —
    -- 게임 전반에서 이미 쓰는 "↑↓" 화살표 재사용)
    love.graphics.setFont(fonts.small)
    if self.scroll > 0 then
        love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
        love.graphics.printf("↑ 더 있음", panelX, panelY + 6, panelW, "center")
    end
    if self.scroll + visibleRows < #self.ids then
        love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
        love.graphics.printf("↓ 더 있음", panelX, listBottom + 6, panelW, "center")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("↑↓ 이동 · Enter 선택 · ESC 진영 선택", 0, 600, W, "center")
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
        Gamestate.switch(require("states.faction"), self.d, self.p)
    end
end

return sel
