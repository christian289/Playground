local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local progress = require("src.progress")
local art = require("src.art")
local stars = require("src.stars")

local result = {}

local STAR_FULL, STAR_EMPTY = "★", "☆" -- stageselect.lua와 동일 글리프 — 스크린샷 확인 결과 정상 렌더

-- 로어(포스트모템) io 기반 로드 — db.lua/play.lua와 동일 패턴(love API 미사용, 순수 Lua)
local function loadText(root, rel)
    local f = io.open(root .. "/data/" .. rel, "rb")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

-- 패배 코칭: ctx.reached(battle.reachedByType)에서 가장 많이 도달한 적 종류 1개를 고른다.
-- 동률이면 스테이지 타임라인에서 더 먼저 스폰된 종을 우선한다(ctx.d.timeline이 at 오름차순 정렬).
local function topReached(ctx)
    local reached = ctx.reached
    if not reached then return nil end
    local order, seen = {}, {}
    for _, ev in ipairs(ctx.d.timeline(ctx.stageId)) do
        if not seen[ev.spawn] then
            seen[ev.spawn] = true
            order[#order + 1] = ev.spawn
        end
    end
    local bestId, bestN
    for _, id in ipairs(order) do
        local n = reached[id] or 0
        if n > 0 and (not bestN or n > bestN) then
            bestId, bestN = id, n
        end
    end
    return bestId, bestN
end

-- 설계서 §4.3 여운 문구
local AFTERWORD = {
    clear = "오늘도 서비스는 무사히 돌아간다. 아무 일 없었다는 듯이.",
    defeat = "서버가 내려갔다. 하지만 개발자는 다시 일어선다.",
}

function result:enter(_, status, ctx)
    self.status, self.ctx = status, ctx
    -- 포스트모템 카드(§8): 클리어 시에만, lore_file이 있고 postmortem이 채워져 있을 때만 연다.
    -- 패배거나 lore가 없으면 pmCard는 false로 남아 draw/keypressed가 곧바로 기존 동작을 한다.
    self.pmCard = false
    self.postmortem = nil
    if status == "clear" then
        ctx.p.cleared[ctx.stageId] = true
        local reward = ctx.d.stages[ctx.stageId].reward_item
        if reward ~= "" then
            local owned = false
            for _, it in ipairs(ctx.p.items) do if it == reward then owned = true end end
            if not owned then ctx.p.items[#ctx.p.items + 1] = reward end
        end

        local stage = ctx.d.stages[ctx.stageId]
        if stage.lore_file and stage.lore_file ~= "" then
            local chunk = loadstring(loadText(ctx.d.root, stage.lore_file) or "")
            local lore = chunk and chunk()
            if lore and lore.postmortem and lore.postmortem ~= "" then
                self.postmortem = lore.postmortem
                self.pmCard = true
            end
        end
    end

    -- 같은 전투 결과(ctx)에 대한 이중 기록 방지 (enter 재호출 대비)
    if self.recordedCtx ~= ctx then
        self.recordedCtx = ctx
        ctx.p.records = ctx.p.records or {}
        local rec = ctx.p.records[ctx.stageId]
        if not rec then
            rec = { tries = 0, clears = 0, bestHP = 0, lastResult = "defeat", gugu = false }
            ctx.p.records[ctx.stageId] = rec
        end
        rec.tries = rec.tries + 1
        if status == "clear" then
            rec.clears = rec.clears + 1
            rec.bestHP = math.max(rec.bestHP, ctx.serverHP or 0)
        end
        rec.lastResult = status
        rec.gugu = rec.gugu or (ctx.guguUsed or false)
        self.rec = rec
        progress.save(ctx.p)
    end
end

-- 포스트모템 카드(§8): 결과 화면 위에 뜨는 오버레이. 배경을 어둡게 깔아 초점을 카드로
-- 모으고, 본문 길이에 맞춰 카드 높이를 동적으로 늘린다(문제 카드의 briefing과 동일 원리).
local function drawPostmortemCard(self)
    local P = art.pal
    local W, H = love.graphics.getWidth(), 640
    local cardW, pad = 640, 24
    love.graphics.setFont(fonts.small)
    local _, wrapped = fonts.small:getWrap(self.postmortem, cardW - pad * 2)
    local bodyLines = math.max(1, #wrapped)
    local titleH, footerH = 46, 40
    local cardH = titleH + bodyLines * fonts.small:getHeight() + footerH
    local cardX, cardY = (W - cardW) / 2, (H - cardH) / 2

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.97)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 10, 10)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3], 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(P.green[1], P.green[2], P.green[3])
    love.graphics.printf(("포스트모템 #%d"):format(self.ctx.stageId), cardX, cardY + 16, cardW, "center")

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.85, 0.88, 0.92)
    love.graphics.printf(self.postmortem, cardX + pad, cardY + titleH, cardW - pad * 2, "left")

    love.graphics.setColor(0.6, 0.65, 0.7)
    -- §8 재클리어 힌트: 이번 결과가 이 스테이지의 첫 클리어면 "Enter 닫기", 재클리어(rec.clears
    -- 는 result:enter가 이미 이번 판을 반영한 뒤 값이므로 >1이면 재클리어)면 "Enter 건너뛰기".
    local isReclear = self.rec and self.rec.clears and self.rec.clears > 1
    love.graphics.printf(isReclear and "Enter 건너뛰기" or "Enter 닫기",
        cardX, cardY + cardH - 26, cardW, "center")
    love.graphics.setColor(1, 1, 1)
end

function result:draw()
    local P = art.pal
    local W = love.graphics.getWidth()
    local OX = (W - 960) / 2 -- 960 기준 패널을 창 폭 중앙에 배치하는 오프셋
    -- 배경 톤
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, W, 640)
    -- 중앙 패널
    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.92)
    love.graphics.rectangle("fill", OX + 180, 180, 600, 300, 10, 10)
    local edge = self.status == "clear" and P.green or P.red
    love.graphics.setColor(edge[1], edge[2], edge[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", OX + 180, 180, 600, 300, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fonts.big)
    if self.status == "clear" then
        love.graphics.setColor(0.4, 0.9, 0.5)
        love.graphics.printf("스테이지 클리어!", 0, 230, W, "center")
        local reward = self.ctx.d.stages[self.ctx.stageId].reward_item
        if reward ~= "" then
            love.graphics.setFont(fonts.ui)
            love.graphics.setColor(1, 0.85, 0.3)
            love.graphics.printf("아이템 획득: " .. self.ctx.d.items[reward].name, 0, 300, W, "center")
        end
        -- 별점: 이번 판(ctx.serverHP)과 이 스테이지 최고 기록(rec.bestHP, 이번 판 반영 후) 둘 다 표기
        if self.rec then
            local nowN = stars.of(self.ctx.serverHP or 0)
            local bestN = stars.of(self.rec.bestHP or 0)
            local nowStr = STAR_FULL:rep(nowN) .. STAR_EMPTY:rep(3 - nowN)
            local bestStr = STAR_FULL:rep(bestN) .. STAR_EMPTY:rep(3 - bestN)
            love.graphics.setFont(fonts.ui)
            love.graphics.setColor(1, 0.85, 0.3)
            love.graphics.printf(("이번 %s (최고 %s)"):format(nowStr, bestStr), 0, 325, W, "center")
        end
    else
        love.graphics.setColor(0.95, 0.4, 0.35)
        love.graphics.printf("서버 다운...", 0, 230, W, "center")
        -- 클리어 타임은 300초 고정이라 무의미하지만, 패배 시 버틴 시간은 다음 시도의
        -- 기준점이 된다 (어디까지 막았는지 = 어떤 웨이브에서 뚫렸는지).
        if self.ctx.clock then
            love.graphics.setFont(fonts.ui)
            love.graphics.setColor(0.85, 0.7, 0.4)
            love.graphics.printf(("버틴 시간 %d초 / 300초"):format(math.max(0, self.ctx.clock)),
                0, 300, W, "center")
        end
        -- 패배 코칭(§7): 가장 많이 뚫린 적 종류 1개(도달 0이면 생략) — 다음 시도의 우선 방어
        -- 대상 힌트 + 조언 꼬리(스펙 원문 그대로). concat-nil의 표시명(영문 에러 문구 그대로)이
        -- 섞이면 fonts.ui로는 600px 패널 폭을 넘기므로(측정: 711px) fonts.small로 렌더링한다.
        local topId, topN = topReached(self.ctx)
        if topId and topN and topN > 0 then
            local name = self.ctx.d.enemies[topId] and self.ctx.d.enemies[topId].name or topId
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(0.85, 0.5, 0.45)
            love.graphics.printf(("가장 많이 도달: %s %d기 — 사거리와 화력 배치를 다시 보라"):format(name, topN),
                0, 325, W, "center")
        end
    end

    -- 배포 로그 줄 (§6.7, 여운 문구 위)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.62, 0.68, 0.74)
    if self.rec then
        local deployLine = ("배포 #%d %s · 서버 HP %d 잔존 · 타워 %d기%s"):format(
            self.rec.tries, self.status == "clear" and "성공" or "롤백",
            self.ctx.serverHP or 0, self.ctx.towerCount or 0,
            self.ctx.guguUsed and " · 구구 클래스 투입" or "")
        love.graphics.printf(deployLine, OX + 210, 370, 540, "center")
    end

    -- 여운 문구 (기존 안내 위, 작은 폰트)
    love.graphics.printf(AFTERWORD[self.status] or "", OX + 210, 400, 540, "center")

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.85, 0.88, 0.92)
    love.graphics.printf("R 재도전 · Enter/클릭 스테이지 선택으로", 0, 500, W, "center")
    love.graphics.setColor(1, 1, 1)

    if self.pmCard then drawPostmortemCard(self) end
end

function result:keypressed(key)
    -- R 재도전은 포스트모템 카드가 열려 있어도 그대로 동작한다(카드 상태와 무관).
    if key == "r" then
        -- 반복 숙달이 목표인 게임이라 재도전 루프를 최단으로: 스테이지 선택 왕복 없이 즉시.
        Gamestate.switch(require("states.play"), self.ctx.d, self.ctx.stageId, self.ctx.p)
        return
    end
    if key == "return" or key == "escape" then
        -- Enter 1회차: 카드만 닫는다. 2회차(카드가 이미 닫혀 있을 때): 기존 동작.
        if self.pmCard then
            self.pmCard = false
            return
        end
        Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
    end
end

function result:mousepressed(_, _, button)
    if button ~= 1 then return end
    -- Enter와 대칭: 카드가 열려 있으면 좌클릭도 카드 닫기로만 소비한다.
    if self.pmCard then
        self.pmCard = false
        return
    end
    Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
end

return result
