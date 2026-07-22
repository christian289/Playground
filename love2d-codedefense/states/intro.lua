local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local progress = require("src.progress")
local art = require("src.art")
local Cutscene = require("src.cutscene")

-- 인트로 컷신 (설계서 4.1). 장면 = 일러스트(art.drawIntroScene) + 하단 타이프라이터 텍스트.
-- 첫 실행 시 자동 재생 후 p.intro_seen 저장 → 타이틀. 타이틀의 "세계관" 메뉴에서
-- returnTo="title" 로 재생하면 저장 없이 곧장 타이틀 복귀.
local intro = {}

local SCENES = {
    { label = "지상 — 화려한 서비스", text = "모두가 매일 쓰는 서비스. 하지만 이것이 어디에서 돌아가는지, 아는 사람은 없다." },
    { label = "지하 — 서버실",       text = "보이지 않는 곳. 새벽 세 시의 서버실. 여기, 한 명의 개발자가 있다." },
    { label = "장애 발생",           text = "버그는 예고 없이 온다. 서비스는 멈추면 안 된다. 아무도 이 싸움을 모른다." },
    { label = "결의",               text = "알아주는 이 없어도, 그의 무기는 단 하나 — 코드다." },
}

local SCENE_W, SCENE_H = 960, 420

function intro:enter(_, d, p, returnTo)
    self.d, self.p, self.returnTo = d, p, returnTo
    self.cs = Cutscene(SCENES)
    self.done = false
end

function intro:finish()
    if self.done then return end
    self.done = true
    if self.returnTo == "title" then
        Gamestate.switch(require("states.title"), self.d, self.p)
    else
        self.p.intro_seen = true
        progress.save(self.p)
        Gamestate.switch(require("states.title"), self.d, self.p)
    end
end

function intro:update(dt)
    self.cs:update(dt)
    if self.cs:done() then self:finish() end
end

function intro:draw()
    local P = art.pal
    local t = love.timer.getTime()
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, 960, 640)

    -- 일러스트 (상단 960×420)
    art.drawIntroScene(self.cs:sceneIndex(), t)

    -- 일러스트 하단 페이드(텍스트 박스로의 전환)
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3], 0.85)
    love.graphics.rectangle("fill", 0, SCENE_H - 24, 960, 24)

    -- 하단 텍스트 박스
    local bx, by, bw, bh = 60, 448, 840, 150
    love.graphics.setColor(0.04, 0.06, 0.11, 0.94)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(P.green[1], P.green[2], P.green[3], 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
    love.graphics.setLineWidth(1)

    -- 장면 라벨
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
    local sc = SCENES[self.cs:sceneIndex()]
    love.graphics.print("[ " .. sc.label .. " ]", bx + 24, by + 18)

    -- 타이프라이터 본문
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.92, 0.95, 0.98)
    love.graphics.printf(self.cs:visibleText(), bx + 24, by + 48, bw - 48, "left")

    -- 타이핑 완료 시 깜빡이는 진행 화살표
    if self.cs:typingDone() and (math.floor(t * 2) % 2) == 0 then
        love.graphics.setColor(P.green[1], P.green[2], P.green[3])
        love.graphics.print("▶", bx + bw - 34, by + bh - 30)
    end

    -- 장면 진행 표시 (점 4개)
    for i = 1, #SCENES do
        if i == self.cs:sceneIndex() then love.graphics.setColor(P.green[1], P.green[2], P.green[3])
        else love.graphics.setColor(0.35, 0.4, 0.46) end
        love.graphics.circle("fill", bx + 24 + (i - 1) * 16, by + bh - 20, 4)
    end

    -- 하단 안내
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("Enter 다음 · ESC 건너뛰기", 0, 612, 960, "center")
    love.graphics.setColor(1, 1, 1)
end

function intro:keypressed(key)
    if key == "return" or key == "space" then
        self.cs:press()
        if self.cs:done() then self:finish() end
    elseif key == "escape" then
        self.cs:skip()
        self:finish()
    end
end

return intro
