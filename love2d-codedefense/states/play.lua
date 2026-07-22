local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")
local Editor = require("src.editor")
local Battle = require("src.battle")
local progress = require("src.progress")
local art = require("src.art")
local particles = require("src.particles")
local stageinfo = require("src.stageinfo")

local GRID_X, GRID_Y = 8, 48
local FIELD_W = grid.COLS * grid.CELL -- 384
local FIELD_H = grid.ROWS * grid.CELL -- 512
local play = {}

local function loadText(root, rel)
    local f = io.open(root .. "/data/" .. rel, "rb")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

function play:enter(_, d, stageId, p)
    self.d, self.stageId, self.p = d, stageId, p
    self.stage = d.stages[stageId]
    self.battle = Battle(d, stageId, { items = p.items })
    self.speed = 1
    self.tut = nil
    self.tutSaved = false
    self.autotype = nil                 -- {target=문자열, pos=글자수, timer}
    self.buttons = {}
    if self.stage.buttons_file ~= "" then
        local chunk = loadstring(loadText(d.root, self.stage.buttons_file) or "")
        if chunk then self.buttons = chunk() or {} end
    end
    self.editor = Editor(400, 48, 552, 470)
    self.editor:setQuickbar({
        { key = "f1", label = "build", text = 'build("printer", ${1}, , "")' },
        { key = "f2", label = "on_tick", text = "function on_tick(self, world)\n  ${1}\nend" },
        { key = "f3", label = "공격", text = "self:attack(world.nearest())" },
        { key = "f4", label = "if", text = "if ${1} then\nend" },
    })
    local saved = p.codes[stageId]
    if saved then self.editor:setText(saved)
    elseif self.stage.hints_file ~= "" then
        self.editor:setText(loadText(d.root, self.stage.hints_file) or "")
    end
    self.battle:start()                 -- 카운트다운부터 실시간 진행

    -- 적 구성 패널·문제 카드용 데이터: 타임라인은 결정론이라 진입 시 1회만 계산
    self.info = stageinfo.totals(self.battle.timeline)
    self.enemyTypes = {}                -- 적 구성 패널 표시 순서 = 타임라인 첫 등장 순
    do
        local seen = {}
        for _, ev in ipairs(self.info.events) do
            if not seen[ev.spawn] then
                seen[ev.spawn] = true
                self.enemyTypes[#self.enemyTypes + 1] = ev.spawn
            end
        end
    end
    self.showBrief = true               -- 문제 카드: 카운트다운 중 자동 표시, Ctrl+I로 재열람

    particles.clear()
    self.fx = {
        prevEnemies = {}, prevTowerCount = #self.battle.towers, prevServerHP = self.battle.serverHP,
        prevCrashed = {}, shake = 0, redFlash = 0, devAnim = { pose = "idle", timer = 0 },
        prevCd = {}, firedTimer = {}, smokeAcc = {}, hitTimer = {},
        guguFx = 0, guguSeen = false,    -- 구구 클래스 소환 연출 타이머(§6.6) — 원시 dt 감쇠
    }

    if self.stage.tutorial_file ~= "" and not p.tutorial_done[stageId] then
        self.tut = require("src.tutorial").load(d.root .. "/data/" .. self.stage.tutorial_file)
    end
end

function play:isButtonStage() return self.stage.ui == "button" end

function play:save()
    local before = #self.battle.towers
    local code = self.editor:getText()
    local ok = self.battle:setScript(code)
    if ok then
        self.p.codes[self.stageId] = code
        progress.save(self.p)
        self.fx.devAnim.pose = "typing"; self.fx.devAnim.timer = 1.0  -- 저장 성공 → 타이핑 1초
        if #self.battle.towers > before and self.tut then self.tut:notify("built") end
        if self.tut then self.tut:notify("saved") end
    end
    return ok
end

function play:pressButton(i)
    local b = self.buttons[i]
    if not b then return end
    self.autotype = { target = b.script, timer = 0, pos = 0 }
    self.editor:setText("")
end

function play:update(dt)
    -- 버튼 오토타이핑 (초당 40자, 끝나면 자동 저장)
    if self.autotype then
        local at = self.autotype
        at.timer = at.timer + dt
        local want = math.min(math.floor(at.timer * 40), #at.target)
        if want > at.pos then
            self.editor:setText(at.target:sub(1, want))
            self.editor.cr = #self.editor.lines
            self.editor.cc = 1
            at.pos = want
        end
        if at.pos >= #at.target then
            self.autotype = nil
            self.editor:setText(at.target)
            self.editor.cr = #self.editor.lines
            self.editor.cc = 1
            self:save()
        end
    end

    self.battle:update(dt * self.speed)
    if self.tut and self.tut:done() and not self.tutSaved then
        self.tutSaved = true
        self.p.tutorial_done[self.stageId] = true
        progress.save(self.p)
    end

    if self.battle.status == "clear" or self.battle.status == "defeat" then
        Gamestate.switch(require("states.result"), self.battle.status,
            { d = self.d, stageId = self.stageId, p = self.p })
    end

    -- 뷰 전용 프레임-diff 이펙트 발동 (battle 코어 상태는 읽기만 한다)
    local b = self.battle
    local fx = self.fx

    -- 타워: 발사 감지(cd 증가) + 크래시 연기 + 크래시 전환 스파크
    for _, tw in ipairs(b.towers) do
        if tw.cd > (fx.prevCd[tw] or 0) then fx.firedTimer[tw] = 0.1 end
        fx.prevCd[tw] = tw.cd
        if fx.firedTimer[tw] and fx.firedTimer[tw] > 0 then
            fx.firedTimer[tw] = math.max(0, fx.firedTimer[tw] - dt)
        end
        local crashedNow = tw.crashed > 0 or tw.disabled
        if crashedNow then
            fx.smokeAcc[tw] = (fx.smokeAcc[tw] or 0) + dt
            while fx.smokeAcc[tw] >= 0.15 do
                particles.spawn("smoke", tw.x, tw.y, { color = { 0.55, 0.58, 0.62 } })
                fx.smokeAcc[tw] = fx.smokeAcc[tw] - 0.15
            end
            if not fx.prevCrashed[tw] then
                particles.spawn("spark", tw.x, tw.y, { count = 6, color = art.pal.red })
                fx.devAnim.pose = "alarm"; fx.devAnim.timer = 1.0  -- 크래시 전이 → 놀람 1초
            end
        else
            fx.smokeAcc[tw] = 0
        end
        fx.prevCrashed[tw] = crashedNow
    end

    -- 적 사망/도달 감지 + 피격 점멸
    local now = {}
    for _, e in ipairs(b.enemies) do
        now[e.id] = { x = e.x, y = e.y, reward = e.def.reward or 0, hp = e.hp }
        local prev = fx.prevEnemies[e.id]
        if prev and e.hp < prev.hp then fx.hitTimer[e.id] = 0.08 end
    end
    for id, timer in pairs(fx.hitTimer) do
        if timer > 0 then fx.hitTimer[id] = math.max(0, timer - dt) end
    end
    for id, info in pairs(fx.prevEnemies) do
        if not now[id] then
            if b.serverHP < fx.prevServerHP then
                -- 도달분은 아래 serverHP 처리에서 일괄
            else
                particles.spawn("burst", info.x, info.y, { count = 8, color = art.pal.orange })
                particles.spawn("float", info.x - 8, info.y - 12, { text = "+" .. info.reward, color = art.pal.green })
            end
        end
    end
    fx.prevEnemies = now
    -- 서버 피격
    if b.serverHP < fx.prevServerHP then
        fx.shake = 0.2
        fx.redFlash = 0.35
    end
    fx.prevServerHP = b.serverHP
    -- 설치 감지 (+ 구구 클래스 등장 frame-diff → 소환 연출, 스펙 §6.6)
    if #b.towers > fx.prevTowerCount then
        local tw = b.towers[#b.towers]
        particles.spawn("flash", tw.x, tw.y, { color = art.pal.cyan })
        if tw.def.id == "gugu-class" then
            fx.guguFx = 1.2
            fx.guguSeen = true
            fx.shake = 0.4
            -- 구구단 파티클 6개: 타워 위치가 아니라 전장 여러 x,y에 흩뿌린다(3열×2행) —
            -- 타워가 우상단(적 구성 패널 부근)에 세워져도 패널 텍스트와 겹치지 않도록.
            for i = 1, 6 do
                local col = (i - 1) % 3
                local row = math.floor((i - 1) / 3)
                local px = FIELD_W * (col + 0.5) / 3
                local py = FIELD_H * 0.32 + row * FIELD_H * 0.34
                particles.spawn("float", px, py,
                    { text = ("2 × %d = %d"):format(i, 2 * i), color = art.pal.orange, ttl = 1.4 })
            end
        end
    end
    fx.prevTowerCount = #b.towers
    fx.shake = math.max(0, fx.shake - dt)
    fx.redFlash = math.max(0, fx.redFlash - dt)
    fx.guguFx = math.max(0, fx.guguFx - dt) -- 원시 dt 감쇠(배속 무관하게 1.2초 유지)

    -- 구구 클래스 최초 발견 → progress에 1회 저장 (도감 ???, Task 6 배포 로그가 사용)
    if not self.p.gugu_found then
        for _, tw in ipairs(b.towers) do
            if tw.def.id == "gugu-class" then
                self.p.gugu_found = true
                progress.save(self.p)
                break
            end
        end
    end
    -- 개발자 아바타 포즈 감쇠 (원시 dt — 배속 무관하게 1초 유지)
    if fx.devAnim.timer > 0 then
        fx.devAnim.timer = fx.devAnim.timer - dt
        if fx.devAnim.timer <= 0 then fx.devAnim.pose = "idle" end
    end
    particles.update(dt)
end

function play:draw()
    local b = self.battle
    local fx = self.fx
    local t = love.timer.getTime()
    -- 셰이크는 전장(그리드/엔티티/파티클)에만 — 에디터/HUD/튜토리얼은 고정
    local shakeX = fx.shake > 0 and math.sin(t * 60) * 3 or 0
    local shakeY = fx.shake > 0 and math.cos(t * 60) * 3 or 0

    -- 상단 바
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    local clockText = b.clock < 0
        and ("전투 시작까지 %d초 — 코드를 준비하세요!"):format(math.ceil(-b.clock))
        or ("%.0f / 300초"):format(b.clock)
    love.graphics.print(("%s   서버 HP %d   잔액 %d   배속 x%d"):format(clockText, b.serverHP, b.money, self.speed), 8, 12)

    -- 진행 바 (HUD 아래, 300초 대비 현재 시각 + 스폰 이벤트 눈금) — 좌표 라벨(아래에서 y를
    -- GRID_Y-12로 내림)과 겹치지 않도록 얇게(4px) y=30에 둔다.
    do
        local barX, barY, barW, barH = GRID_X, 30, FIELD_W, 4
        love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3], 0.9)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        local frac = math.max(0, math.min(1, b.clock / Battle.TOTAL))
        love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3], 0.9)
        love.graphics.rectangle("fill", barX, barY, barW * frac, barH)
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3], 0.9)
        for _, ev in ipairs(self.info.events) do
            local tx = barX + (ev.at / Battle.TOTAL) * barW
            love.graphics.rectangle("fill", tx, barY, 1, barH)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- 전장 타일
    for r = 1, grid.ROWS do
        for c = 1, grid.COLS do
            local x, y = grid.toXY(r, c)
            x, y = x + GRID_X + shakeX, y + GRID_Y + shakeY
            if b.grid.build[r][c] then art.drawPad(x, y, t)
            elseif b.grid.walls[r][c] then art.drawWall(x, y, t)
            else art.drawFloor(x, y) end
        end
    end
    -- 행·열 좌표 라벨 (코드로 좌표를 지정하므로 상시 표기) — 진행 바(y=30~34)와 겹치지
    -- 않도록 열 라벨을 그리드 쪽으로 4px 내려 y=-12 오프셋(=38)에서 그린다.
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 0.55, 0.6)
    for c = 1, grid.COLS do love.graphics.print(tostring(c), GRID_X + shakeX + (c - 1) * grid.CELL + 10, GRID_Y + shakeY - 12) end
    for r = 1, grid.ROWS do love.graphics.print(tostring(r), GRID_X + shakeX - 6 - fonts.small:getWidth(tostring(r)) + 4, GRID_Y + shakeY + (r - 1) * grid.CELL + 8) end
    -- 서버라인
    art.drawServerline(GRID_X + shakeX, GRID_Y + shakeY + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, t)

    -- 적 구성 패널 (전장 우상단, 좌하단 로그 오버레이와 대칭인 반투명 박스). 모든 스폰이
    -- 끝나면 패널 하단에 "잔여 소탕" 문구를 한 줄 더 붙인다 — HUD 한 줄에 붙였다가 긴
    -- 문장이 에디터 패널 쪽으로 넘쳐 겹치는 문제가 있어(스크린샷으로 발견) 폭이 고정된
    -- 이 패널 안으로 옮겼다.
    do
        local killed = stageinfo.killedCounts(self.info, b)
        local sweeping = b.clock >= self.info.lastEnd and (b.status == "running" or b.status == "clear")
        local panelW, rowH = 172, 26
        local n = #self.enemyTypes
        local panelH = 10 + 18 + (n + (sweeping and 1 or 0)) * rowH + 4
        local px2 = GRID_X + shakeX + FIELD_W - panelW - 4
        local py2 = GRID_Y + shakeY + 4
        love.graphics.setColor(art.pal.bg[1], art.pal.bg[2], art.pal.bg[3], 0.75)
        love.graphics.rectangle("fill", px2, py2, panelW, panelH)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.75, 0.8, 0.86)
        love.graphics.print("적 구성", px2 + 8, py2 + 5)
        for i, id in ipairs(self.enemyTypes) do
            local rowY = py2 + 10 + 18 + (i - 1) * rowH
            art.drawEnemy(id, px2 + 22, rowY + rowH / 2, t, false)
            local def = self.d.enemies[id]
            local kn = killed[id] or 0
            local tot = self.info.byType[id] or 0
            love.graphics.setColor(0.85, 0.88, 0.92)
            love.graphics.print(("%s"):format(def and def.name or id), px2 + 40, rowY + rowH / 2 - 15)
            love.graphics.setColor(0.6, 0.9, 0.7)
            love.graphics.print(("처리 %d / %d"):format(kn, tot), px2 + 40, rowY + rowH / 2 - 1)
        end
        if sweeping then
            local rowY = py2 + 10 + 18 + n * rowH
            love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
            love.graphics.print("잔여 소탕 · 생존!", px2 + 8, rowY + rowH / 2 - 7)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- 타워 (justFired 플래시 프레임, 크래시/disabled 틴트 오버레이 — art.drawTower는 항상
    -- 자체 팔레트 색으로 그리므로 사전 setColor 틴트가 먹지 않아 사후 반투명 오버레이로 표현)
    for _, tw in ipairs(b.towers) do
        local cx, cy = GRID_X + shakeX + tw.x, GRID_Y + shakeY + tw.y
        local firing = (fx.firedTimer[tw] or 0) > 0
        art.drawTower(tw.def.id, cx, cy, t, firing)
        if tw.crashed > 0 or tw.disabled then
            love.graphics.setColor(0.08, 0.08, 0.1, 0.55)
            love.graphics.rectangle("fill", cx - 16, cy - 16, 32, 32)
        end
        love.graphics.setColor(art.pal.white[1], art.pal.white[2], art.pal.white[3])
        love.graphics.print(tw.name or "", cx - 10, cy - 26)
    end
    -- 적 (hit 점멸 — 흰 실루엣 시트)
    for _, e in ipairs(b.enemies) do
        local ex, ey = GRID_X + shakeX + e.x, GRID_Y + shakeY + e.y
        local hit = (fx.hitTimer[e.id] or 0) > 0
        art.drawEnemy(e.def.id, ex, ey, t, hit)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", ex - 10, ey - 16, 20, 3)
        love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
        love.graphics.rectangle("fill", ex - 10, ey - 16, 20 * e.hp / e.max_hp, 3)
    end
    love.graphics.setColor(1, 1, 1)
    -- 총알: 글로우(알파0.3·2배 크기) + 본체 — 차지 총알(size>4)은 마젠타, 일반은 흰색
    for _, pr in ipairs(b.projectiles) do
        local glow = pr.size > 4 and art.pal.magenta or art.pal.white
        local px, py = GRID_X + shakeX + pr.x, GRID_Y + shakeY + pr.y
        love.graphics.setColor(glow[1], glow[2], glow[3], 0.3)
        love.graphics.circle("fill", px, py, pr.size * 2)
        love.graphics.setColor(glow[1], glow[2], glow[3], 1)
        love.graphics.circle("fill", px, py, pr.size)
    end
    love.graphics.setColor(1, 1, 1)
    -- 파티클 (사망 burst/보상 float/설치 flash/크래시 smoke/spark)
    particles.draw(GRID_X + shakeX, GRID_Y + shakeY)

    -- IDE 패널 (에디터 뒤 배경 + 타이틀바) — 우측 20px은 Task 5의 개발자 아바타 자리
    do
        local ex, ey, ew, eh = self.editor.x, self.editor.y, self.editor.w, self.editor.h
        local px, py = ex - 4, ey - 22
        local pw, ph = ew + 8, eh + 26
        love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3])
        love.graphics.rectangle("fill", px, py, pw, ph)
        love.graphics.setColor(art.pal.panelLight[1], art.pal.panelLight[2], art.pal.panelLight[3])
        love.graphics.rectangle("fill", px, py, pw, 22)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(art.pal.white[1], art.pal.white[2], art.pal.white[3])
        love.graphics.print("script.lua", px + 8, py + 4)
        -- 개발자 미니 아바타 (우측): 저장 시 typing, 크래시 전이 시 alarm, 그 외 idle
        art.drawDev(fx.devAnim.pose, px + pw - 22, py + 3, 1, t)
        love.graphics.setColor(1, 1, 1)
    end

    -- 에디터 또는 버튼 패널
    if self:isButtonStage() then
        -- 버튼 스테이지에서는 퀵바 단축키가 애초에 눌리지 않으므로(keypressed 상단에서 분기)
        -- 편집기 자체 퀵바 줄을 그리지 않는다 — 버튼 목록/튜토리얼 말풍선과의 시각적 겹침을 줄인다.
        local qb = self.editor.quickbar
        self.editor.quickbar = {}
        self.editor:draw(fonts, false)
        self.editor.quickbar = qb
        -- Task 5: 튜토리얼 말풍선(y>=580)과 겹치지 않도록 버튼 패널을 에디터 바로 아래로 당김
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.95, 0.85, 0.4)
        love.graphics.print("버튼 → 코드 자동 입력·저장:", 400, 520)
        for i, btn in ipairs(self.buttons) do
            love.graphics.setColor(0.85, 0.88, 0.92)
            love.graphics.print(("[%d] %s"):format(i, btn.label), 400, 534 + (i - 1) * 13)
        end
    else
        self.editor:draw(fonts, true)
    end

    -- 전투 로그 오버레이 (전장 내부, 상단 왼쪽 — 최근 3줄만 표시)
    do
        local logStartY = GRID_Y + shakeY + grid.ROWS * grid.CELL - 3 * 18 - 8
        local logX = GRID_X + shakeX + 4
        local logCount = math.min(3, #b.log)
        if logCount > 0 then
            -- 배경 반투명 박스
            love.graphics.setColor(art.pal.bg[1], art.pal.bg[2], art.pal.bg[3], 0.7)
            love.graphics.rectangle("fill", logX - 2, logStartY - 2, 200, logCount * 18 + 4)
            -- 로그 텍스트 (가장 최근 3줄)
            love.graphics.setFont(fonts.small)
            for i = math.max(1, #b.log - 2), #b.log do
                local idx = i - math.max(1, #b.log - 2) + 1
                love.graphics.setColor(0.8, 0.82, 0.86, 1 - (logCount - idx) * 0.1)
                love.graphics.print(b.log[i], logX, logStartY + (idx - 1) * 18)
            end
        end
    end
    -- 저장 오류
    if b.scriptError then
        love.graphics.setColor(1, 0.45, 0.4)
        love.graphics.printf("저장 실패 — " .. b.scriptError, 400, 545, 552, "left")
    end
    -- 힌트바 (튜토리얼 말풍선이 대신 안내하는 동안은 겹치지 않도록 숨긴다)
    if not (self.tut and not self.tut:done()) then
        love.graphics.setColor(0.6, 0.65, 0.7)
        local hint = self:isButtonStage()
            and "숫자키 버튼 실행 · Ctrl+1/2/4 배속 · Ctrl+I 문제 · ESC 나가기"
            or "F5 저장·반영 · F1~F4 스니펫 · Ctrl+1/2/4 배속 · Ctrl+I 문제 · ESC 나가기"
        love.graphics.printf(hint, 0, 620, 960, "center")
    end

    -- 서버 피격 화면 테두리 플래시 (화면 전체 오버레이 — 튜토리얼 아래, HUD보다 위)
    if fx.redFlash > 0 then
        local a = math.min(1, fx.redFlash * 2)
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        love.graphics.setColor(art.pal.red[1], art.pal.red[2], art.pal.red[3], a)
        love.graphics.rectangle("fill", 0, 0, sw, 6)
        love.graphics.rectangle("fill", 0, sh - 6, sw, 6)
        love.graphics.rectangle("fill", 0, 0, 6, sh)
        love.graphics.rectangle("fill", sw - 6, 0, 6, sh)
        love.graphics.setColor(1, 1, 1)
    end

    -- 구구 클래스 소환 연출 (스펙 §6.6, 뷰 전용 frame-diff 이펙트) — 튜토리얼 아래 z순서
    if fx.guguFx > 0 then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        -- 흰 전체 플래시: 트리거 직후 0.3초 구간만 (1.2 → 0.9)
        local flashA = math.max(0, fx.guguFx - 0.9)
        if flashA > 0 then
            love.graphics.setColor(1, 1, 1, flashA)
            love.graphics.rectangle("fill", 0, 0, sw, sh)
        end
        -- 금색 테두리 펄스
        local pulse = 0.6 + 0.4 * math.sin(t * 16)
        love.graphics.setColor(art.pal.orange[1], art.pal.orange[2], art.pal.orange[3], pulse)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", 3, 3, sw - 6, sh - 6)
        love.graphics.setLineWidth(1)
        -- 중앙 배너
        love.graphics.setFont(fonts.big)
        local bannerA = math.min(1, fx.guguFx * 2)
        love.graphics.setColor(art.pal.orange[1], art.pal.orange[2], art.pal.orange[3], bannerA)
        love.graphics.printf("전설의 클래스, 소환.", 0, sh / 2 - 24, sw, "center")
        love.graphics.setColor(1, 1, 1)
    end

    -- 문제 카드 (카운트다운 중 자동 표시, Ctrl+I 재열람) — 튜토리얼 말풍선보다 아래 z순서이므로
    -- tut:draw보다 반드시 먼저 그려 튜토리얼이 카드 위에 겹쳐 보이게 한다.
    if self.showBrief then
        local stage = self.stage
        local cardW = 360
        local cardX = GRID_X + (FIELD_W - cardW) / 2
        local cardH = 190
        local cardY = GRID_Y + (grid.ROWS * grid.CELL - cardH) / 2
        love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3], 0.94)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6)
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3], 0.8)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6)
        local pad = 14
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(art.pal.white[1], art.pal.white[2], art.pal.white[3])
        love.graphics.printf(("[문제 %d] %s"):format(self.stageId, stage.concept), cardX + pad, cardY + pad, cardW - pad * 2, "left")
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3])
        love.graphics.printf("메모리 영역: " .. stage.theme, cardX + pad, cardY + pad + 24, cardW - pad * 2, "left")
        love.graphics.setColor(0.85, 0.88, 0.92)
        love.graphics.printf(stage.problem, cardX + pad, cardY + pad + 46, cardW - pad * 2, "left")
        love.graphics.setColor(0.7, 0.75, 0.8)
        love.graphics.printf(("제한: 예산 %d · 유입 예정 %d기"):format(stage.budget, self.info.total),
            cardX + pad, cardY + cardH - 58, cardW - pad * 2, "left")
        love.graphics.printf("제출: F5 · 채점: 300초 생존", cardX + pad, cardY + cardH - 40, cardW - pad * 2, "left")
        love.graphics.setColor(0.55, 0.6, 0.65)
        love.graphics.printf("Enter 닫기 · Ctrl+I 다시 보기", cardX + pad, cardY + cardH - 20, cardW - pad * 2, "left")
        love.graphics.setColor(1, 1, 1)
    end

    if self.tut then self.tut:draw(fonts, GRID_X, GRID_Y) end
end

function play:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    -- Task 5 훅: 튜토리얼이 활성 상태면 허용된 키만 통과시킨다. 튜토리얼이 키를 소비했으면
    -- (Ctrl+X 스킵, Enter 진행, 스텝 지정 키 진행) 여기서 멈춰 에디터로 새어나가지 않게 한다.
    if self.tut and not self.tut:done() then
        if not self.tut:allows(key, ctrl) then return end
        if self.tut:keypressed(key, ctrl) then return end
    end
    -- 문제 카드: Ctrl+I로 언제든 토글(버튼/에디터 입력과 무충돌), Enter는 카드가 열려
    -- 있는 동안만 닫기로 소비한다(그 외에는 에디터 개행으로 그대로 흘러간다).
    if ctrl and key == "i" then
        self.showBrief = not self.showBrief
        return
    end
    if key == "return" and self.showBrief then
        self.showBrief = false
        return
    end
    if key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
        return
    end
    if ctrl and (key == "1" or key == "2" or key == "4") then
        self.speed = tonumber(key)
        if self.tut then self.tut:notify("speed_changed") end
        return
    end
    if self:isButtonStage() then
        local i = tonumber(key)
        if i and self.buttons[i] and not self.autotype then self:pressButton(i) end
        return
    end
    if key == "f5" then self:save() return end
    if not self.editor:quickbarPressed(key) then self.editor:keypressed(key) end
end

function play:textinput(ch)
    -- Task 5 훅: 튜토리얼이 텍스트 입력을 막는 구간에서는 무시한다.
    if self.tut and not self.tut:done() and not self.tut:allowsText() then return end
    if self:isButtonStage() or self.autotype then return end
    self.editor:textinput(ch)
end

return play
