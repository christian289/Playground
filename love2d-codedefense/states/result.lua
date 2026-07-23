local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local progress = require("src.progress")
local art = require("src.art")

local result = {}

-- 설계서 §4.3 여운 문구
local AFTERWORD = {
    clear = "오늘도 서비스는 무사히 돌아간다. 아무 일 없었다는 듯이.",
    defeat = "서버가 내려갔다. 하지만 개발자는 다시 일어선다.",
}

function result:enter(_, status, ctx)
    self.status, self.ctx = status, ctx
    if status == "clear" then
        ctx.p.cleared[ctx.stageId] = true
        local reward = ctx.d.stages[ctx.stageId].reward_item
        if reward ~= "" then
            local owned = false
            for _, it in ipairs(ctx.p.items) do if it == reward then owned = true end end
            if not owned then ctx.p.items[#ctx.p.items + 1] = reward end
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
end

function result:keypressed(key)
    if key == "return" or key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
    elseif key == "r" then
        -- 반복 숙달이 목표인 게임이라 재도전 루프를 최단으로: 스테이지 선택 왕복 없이 즉시.
        Gamestate.switch(require("states.play"), self.ctx.d, self.ctx.stageId, self.ctx.p)
    end
end

function result:mousepressed(_, _, button)
    if button ~= 1 then return end
    Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
end

return result
