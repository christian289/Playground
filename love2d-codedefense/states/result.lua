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
    self.status, self.ctx, self.recorded = status, ctx, false
    if status == "clear" then
        ctx.p.cleared[ctx.stageId] = true
        local reward = ctx.d.stages[ctx.stageId].reward_item
        if reward ~= "" then
            local owned = false
            for _, it in ipairs(ctx.p.items) do if it == reward then owned = true end end
            if not owned then ctx.p.items[#ctx.p.items + 1] = reward end
        end
    end

    -- 배포 기록 갱신 (1회 가드)
    if not self.recorded then
        self.recorded = true
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
    -- 배경 톤
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, 960, 640)
    -- 중앙 패널
    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.92)
    love.graphics.rectangle("fill", 180, 180, 600, 300, 10, 10)
    local edge = self.status == "clear" and P.green or P.red
    love.graphics.setColor(edge[1], edge[2], edge[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 180, 180, 600, 300, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(fonts.big)
    if self.status == "clear" then
        love.graphics.setColor(0.4, 0.9, 0.5)
        love.graphics.printf("스테이지 클리어!", 0, 230, 960, "center")
        local reward = self.ctx.d.stages[self.ctx.stageId].reward_item
        if reward ~= "" then
            love.graphics.setFont(fonts.ui)
            love.graphics.setColor(1, 0.85, 0.3)
            love.graphics.printf("아이템 획득: " .. self.ctx.d.items[reward].name, 0, 300, 960, "center")
        end
    else
        love.graphics.setColor(0.95, 0.4, 0.35)
        love.graphics.printf("서버 다운...", 0, 230, 960, "center")
    end

    -- 배포 로그 줄 (§6.7, 여운 문구 위)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.62, 0.68, 0.74)
    if self.rec then
        local deployLine = ("배포 #%d %s · 서버 HP %d 잔존 · 타워 %d기%s"):format(
            self.rec.tries, self.status == "clear" and "성공" or "롤백",
            self.ctx.serverHP or 0, self.ctx.towerCount or 0,
            self.ctx.guguUsed and " · 구구 클래스 투입 ✓" or "")
        love.graphics.printf(deployLine, 210, 370, 540, "center")
    end

    -- 여운 문구 (기존 안내 위, 작은 폰트)
    love.graphics.printf(AFTERWORD[self.status] or "", 210, 400, 540, "center")

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.85, 0.88, 0.92)
    love.graphics.printf("Enter 스테이지 선택으로", 0, 500, 960, "center")
    love.graphics.setColor(1, 1, 1)
end

function result:keypressed(key)
    if key == "return" or key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
    end
end

return result
