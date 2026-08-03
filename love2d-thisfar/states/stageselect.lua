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

-- 목록 패널 지오메트리 상수(Y축) — title.lua의 MENU_Y0 패턴처럼 모듈 로드 시 1회만 계산해
-- draw()·keypressed()·wheelmoved()·mousemoved()가 항상 같은 값을 공유한다(마우스 히트 판정이
-- 실제로 그려지는 위치와 어긋나지 않도록). X축 값(panelX 등)은 창 폭 중앙 정렬(OX)에 의존하므로
-- draw()에서 매 프레임 계산해 hit-rect(self.rows)에 담는다.
local PANEL_Y, PANEL_H = 96, 470
local ROW_SPACING = 40
local TOP_PAD, BOTTOM_PAD = 26, 26 -- "↑/↓ 더 있음" 표시용 여백(스크롤 여부와 무관하게 항상 예약해 목록 위치가 흔들리지 않게 함)
local LIST_TOP = PANEL_Y + TOP_PAD
local LIST_BOTTOM = PANEL_Y + PANEL_H - BOTTOM_PAD
local VISIBLE_ROWS = math.max(1, math.floor((LIST_BOTTOM - LIST_TOP) / ROW_SPACING))

-- faction(진영 선택 상태가 넘긴 "lua"|"shell", 없으면 "lua" 기본) 기준으로 목록을 구성한다.
-- 언락 판정은 src/factions.lua로 위임(진영 내 목록 이전 항목 클리어 기준 — 전역 id-1 참조 아님).
function sel:enter(_, d, p, faction)
    self.d, self.p = d, p
    self.faction = faction or "lua"
    self.ids = factions.idsFor(d.stages, self.faction)
    self.cursor = 1
    self.scroll = 0 -- 목록 스크롤 오프셋(0-indexed, 화면 첫 줄에 보이는 항목 = ids[scroll+1])
    self.rows = {}  -- 가시 항목 hit-rect({id,index,x0,y0,x1,y1}) — draw()가 매 프레임 갱신(dictRows 패턴)
    self.shakeId = nil    -- 잠긴 항목 클릭 피드백 대상 스테이지 id
    self.shakeTimer = 0   -- 0.3초 흔들림 잔여 시간(뷰 전용, 원시 dt — play.lua의 tutShake 패턴과 동일)
end

function sel:unlocked(id)
    return factions.unlocked(self.ids, self.p.cleared, id)
end

-- 커서가 화면 위/아래를 벗어나면 스크롤이 따라가게 클램프(키보드 ↑↓ 전용 — 마우스 휠 스크롤은
-- 커서를 움직이지 않으므로 이 함수를 거치지 않고 wheelmoved가 self.scroll을 직접 조정한다).
function sel:ensureCursorVisible()
    if self.cursor - 1 < self.scroll then self.scroll = self.cursor - 1 end
    if self.cursor - 1 > self.scroll + VISIBLE_ROWS - 1 then self.scroll = self.cursor - VISIBLE_ROWS end
    local maxScroll = math.max(0, #self.ids - VISIBLE_ROWS)
    self.scroll = math.max(0, math.min(self.scroll, maxScroll))
end

-- 잠금 클릭 피드백(0.3초) 감쇠 — 원시 dt, 배속 개념이 없는 화면이라 dt 그대로 사용.
function sel:update(dt)
    if (self.shakeTimer or 0) > 0 then
        self.shakeTimer = math.max(0, self.shakeTimer - dt)
    end
end

function sel:draw()
    local P = art.pal
    local W = love.graphics.getWidth()
    local OX = (W - 960) / 2 -- 960 기준 좌표(패널·목록)를 창 폭 중앙에 배치하는 오프셋
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, W, 640)

    -- 목록 패널 지오메트리 (X축만 여기서 계산 — Y축은 모듈 상수 PANEL_Y/PANEL_H/VISIBLE_ROWS
    -- 등을 공유). rowLeft/rowW는 커서 하이라이트·기록 텍스트 정렬·마우스 hit-rect에도 재사용해
    -- 항상 패널 안쪽에 들어가고 클릭 판정이 그려지는 위치와 어긋나지 않게 한다.
    local panelX, panelW = OX + 200, 560
    local rowLeft, rowW = OX + 220, 520
    local rowRight = rowLeft + rowW

    -- 스크롤 오프셋 안전 클램프 (0..maxScroll). 커서를 따라가는 스크롤 이동은 키보드 ↑↓ 시점에
    -- ensureCursorVisible()이 처리하므로 여기서는 범위 밖 값(예: #ids 변화)만 방어한다 — 매
    -- 프레임 커서 위치로 강제 복귀시키면 마우스 휠 스크롤(커서를 안 움직임)이 다음 프레임에
    -- 곧바로 원위치로 튕겨 나가 버리기 때문에, 두 입력 경로(키보드 vs 휠)의 스크롤 갱신 책임을
    -- 분리했다.
    local maxScroll = math.max(0, #self.ids - VISIBLE_ROWS)
    self.scroll = math.max(0, math.min(self.scroll, maxScroll))

    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.85)
    love.graphics.rectangle("fill", panelX, PANEL_Y, panelW, PANEL_H, 10, 10)

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
    love.graphics.printf(("스테이지 선택 — %s"):format(FACTION_LABEL[self.faction] or self.faction), 0, 40, W, "center")
    love.graphics.setFont(fonts.ui)
    self.rows = {} -- 가시 항목 hit-rect 재구성(호버/클릭 판정용 — play.lua의 dictRows 패턴)
    for j = 1, VISIBLE_ROWS do
        local i = self.scroll + j
        local id = self.ids[i]
        if not id then break end
        local s = self.d.stages[id]
        local y = LIST_TOP + (j - 1) * ROW_SPACING
        local locked = not self:unlocked(id)
        -- 잠긴 항목 클릭 피드백: 0.3초 흔들림 + 경고색(빨강) 강조. tutShake 패턴과 동일한
        -- sin 진폭 공식을 재사용하되, 흔들리는 대상은 이 행 하나(push/translate로 국소 적용)뿐이다.
        local shaking = locked and id == self.shakeId and (self.shakeTimer or 0) > 0
        local sx = shaking and math.sin(love.timer.getTime() * 50) * (4 * self.shakeTimer / 0.3) or 0
        love.graphics.push()
        love.graphics.translate(sx, 0)
        if shaking then
            love.graphics.setColor(P.red[1], P.red[2], P.red[3], 0.22)
            love.graphics.rectangle("fill", rowLeft, y - 4, rowW, 32, 5, 5)
            love.graphics.setColor(P.red[1], P.red[2], P.red[3])
        elseif i == self.cursor then
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
        love.graphics.pop()

        -- hit-rect 등록: 흔들림 오프셋과 무관하게 기준 좌표(커서 하이라이트와 동일한 32px 밴드)로
        -- 고정 — 다음 mousemoved/mousepressed가 이 프레임의 self.rows를 읽어 판정한다.
        self.rows[#self.rows + 1] = { id = id, index = i, x0 = rowLeft, y0 = y - 4, x1 = rowRight, y1 = y - 4 + 32 }
    end

    -- 스크롤 인디케이터: 화면 밖에 항목이 더 있음을 알림(폰트에 없는 글리프 회피 —
    -- 게임 전반에서 이미 쓰는 "↑↓" 화살표 재사용)
    love.graphics.setFont(fonts.small)
    if self.scroll > 0 then
        love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
        love.graphics.printf("↑ 더 있음", panelX, PANEL_Y + 6, panelW, "center")
    end
    if self.scroll + VISIBLE_ROWS < #self.ids then
        love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
        love.graphics.printf("↓ 더 있음", panelX, LIST_BOTTOM + 6, panelW, "center")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("↑↓/마우스 이동 · Enter/클릭 선택 · 휠 스크롤 · ESC 진영 선택", 0, 600, W, "center")
    love.graphics.setColor(1, 1, 1)
end

function sel:keypressed(key)
    if key == "up" then
        self.cursor = math.max(1, self.cursor - 1)
        self:ensureCursorVisible()
    elseif key == "down" then
        self.cursor = math.min(#self.ids, self.cursor + 1)
        self:ensureCursorVisible()
    elseif key == "return" then
        local id = self.ids[self.cursor]
        if self:unlocked(id) then
            Gamestate.switch(require("states.play"), self.d, id, self.p)
        end
    elseif key == "escape" then
        Gamestate.switch(require("states.faction"), self.d, self.p)
    end
end

-- 호버: 마우스가 가시 항목(self.rows, draw()가 매 프레임 갱신) 위에 있으면 커서를 그 항목으로
-- 옮긴다. title.lua/faction.lua의 itemAt() 방식과 달리 스크롤 목록이라 고정 공식이 아니라
-- draw()가 저장한 실제 hit-rect를 그대로 사용한다(play.lua의 dictRows 클릭 판정과 동일 관례).
function sel:mousemoved(x, y)
    for _, row in ipairs(self.rows or {}) do
        if x >= row.x0 and x < row.x1 and y >= row.y0 and y < row.y1 then
            self.cursor = row.index
            return
        end
    end
end

-- 좌클릭: 언락된 스테이지면 Enter와 동일 경로(play로 전환). 잠긴 스테이지는 전환하지 않고
-- 0.3초 흔들림 피드백만 남긴다(draw()가 self.shakeId/self.shakeTimer를 읽어 렌더).
function sel:mousepressed(x, y, button)
    if button ~= 1 then return end
    for _, row in ipairs(self.rows or {}) do
        if x >= row.x0 and x < row.x1 and y >= row.y0 and y < row.y1 then
            self.cursor = row.index
            if self:unlocked(row.id) then
                Gamestate.switch(require("states.play"), self.d, row.id, self.p)
            else
                self.shakeId = row.id
                self.shakeTimer = 0.3
            end
            return
        end
    end
end

-- 마우스 휠: 기존 키보드 스크롤과 동일한 클램프(0..maxScroll)로 self.scroll을 직접 조정한다.
-- 커서는 움직이지 않으므로(요구사항 3) 스크롤 후 호버 항목이 바뀌면 다음 mousemoved가 자연히
-- 반영한다. LÖVE 관례상 y>0은 휠을 위로 굴린 것(목록 위쪽을 보여줘야 하므로 스크롤 감소).
function sel:wheelmoved(_, y)
    local maxScroll = math.max(0, #self.ids - VISIBLE_ROWS)
    self.scroll = math.max(0, math.min(self.scroll - y, maxScroll))
    -- 같은 프레임에 배칭된 클릭이 스크롤 이전 좌표(직전 draw의 rect)로 다른 스테이지에
    -- 진입하는 것을 방지 — rect를 비우면 그 클릭은 무해하게 무시되고 다음 draw가 재구성한다.
    self.rows = {}
end

return sel
