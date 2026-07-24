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
local INFO_X, INFO_W = 400, 240 -- 정보 칼럼(전장과 에디터 사이)
local play = {}

-- enemies.csv의 color 필드("r;g;b" 문자열, 0~1 실수)를 {r,g,b}로 파싱. 형식이 어긋나면 흰색.
local function parseColor(s)
    local r, g, b = tostring(s or ""):match("^([%d%.]+);([%d%.]+);([%d%.]+)$")
    if not r then return { 1, 1, 1 } end
    return { tonumber(r), tonumber(g), tonumber(b) }
end

local function loadText(root, rel)
    local f = io.open(root .. "/data/" .. rel, "rb")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

-- 함수 사전 ①: 빌트인 문서 리터럴. build()만 등재(유저 함수는 소스 발췌로 대신한다).
local BUILTIN_DOCS = {
    build = {
        sig = 'build(종류, 행, 열, "이름")',
        lines = {
            "타워를 짓는 유일한 수단",
            "같은 이름 재호출은 무시(멱등)",
            "예산 차감 · 건설칸(B) 전용",
            "스나이퍼는 컴파일러 필요",
            '한글 별칭: build("구구클래스", ...)',
        },
        example = 'build("printer", 3, 10, "a")',
    },
    demolish = {
        sig = 'demolish("이름")',
        lines = {
            "이름으로 타워를 철거하는 수단",
            "환불: 철거 시점 비용의 50%(내림)",
            "없는 이름이면 실패(false) + 오류 로그",
            "크래시·비활성 타워도 철거 가능",
            '함정: build("이름")가 스크립트에',
            "남아 있으면 다음 저장(F5) 때 재건설됨",
        },
        example = 'demolish("a")',
    },
    ["world.oldest"] = {
        sig = "world.oldest()",
        lines = {
            "필드에서 가장 오래 버틴 적의 스냅샷을 반환한다(없으면 nil).",
            "메모리 릭처럼 시간이 지날수록 강해지는 적은 오래된 것부터 끊어야 싸다.",
        },
        example = "local e = world.oldest()",
    },
}

local DICT_ROW_H = 16 -- fonts.small(14px) 기준 줄 높이

-- 유저 함수 소스 발췌 휴리스틱: `function 이름` 줄부터 키워드 카운팅
-- (function/if/for/while/do +1, end -1)으로 대응 end까지 훑는다. 정밀한 파서가 아니라
-- 근사치이며(예: `while x do`처럼 한 줄에 두 키워드가 오면 이중 카운트될 수 있음), 화면
-- 표시 전용이라 최대 10줄 + "…" 절단으로 방어한다.
local function extractFuncSource(lines, name)
    local pat1 = "^%s*function%s+" .. name .. "%s*%("
    local pat2 = "^%s*function%s+" .. name .. "%s*$"
    local startIdx
    for i, line in ipairs(lines) do
        if line:match(pat1) or line:match(pat2) then startIdx = i break end
    end
    if not startIdx then return nil end
    local depth, endIdx = 0, startIdx
    for i = startIdx, #lines do
        for kw in lines[i]:gmatch("%a+") do
            if kw == "function" or kw == "if" or kw == "for" or kw == "while" or kw == "do" then
                depth = depth + 1
            elseif kw == "end" then
                depth = depth - 1
            end
        end
        endIdx = i
        if depth <= 0 then break end
    end
    local out, truncated = {}, endIdx - startIdx + 1 > 10
    for i = startIdx, math.min(endIdx, startIdx + 9) do out[#out + 1] = lines[i] end
    return out, startIdx, truncated
end

-- 사전 카드(펼침 상태) — 빌트인은 문서 리터럴, 유저 함수는 소스 발췌. 다음 y를 반환한다.
local function drawDictCard(self, x, y, w, name)
    local pad = 6
    love.graphics.setFont(fonts.small)
    if BUILTIN_DOCS[name] then
        local doc = BUILTIN_DOCS[name]
        local innerW = w - pad * 2
        -- 설명 줄이 카드 폭을 넘으면(demolish의 함정 설명처럼 길 수 있음) printf로 줄바꿈해
        -- 카드 밖으로 잘리지 않게 한다. 높이는 실제 래핑된 줄 수 합으로 계산한다(build처럼
        -- 짧은 줄은 그대로 1줄).
        local function wrapRows(s)
            local _, wrapped = fonts.small:getWrap(s, innerW)
            return math.max(1, #wrapped)
        end
        local descRows = 0
        for _, l in ipairs(doc.lines) do descRows = descRows + wrapRows("· " .. l) end
        local n = 1 + descRows + 1
        local h = pad * 2 + n * DICT_ROW_H
        love.graphics.setColor(art.pal.panelLight[1], art.pal.panelLight[2], art.pal.panelLight[3])
        love.graphics.rectangle("fill", x, y, w, h, 4)
        local cy = y + pad
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3])
        love.graphics.print(doc.sig, x + pad, cy)
        cy = cy + DICT_ROW_H
        love.graphics.setColor(0.85, 0.88, 0.92)
        for _, l in ipairs(doc.lines) do
            local text = "· " .. l
            love.graphics.printf(text, x + pad, cy, innerW, "left")
            cy = cy + wrapRows(text) * DICT_ROW_H
        end
        love.graphics.setColor(0.6, 0.9, 0.7)
        love.graphics.print(doc.example, x + pad, cy)
        love.graphics.setColor(1, 1, 1)
        return y + h
    else
        local src, startLine, truncated = extractFuncSource(self.editor.lines, name)
        if not src then
            local h = pad * 2 + DICT_ROW_H
            love.graphics.setColor(art.pal.panelLight[1], art.pal.panelLight[2], art.pal.panelLight[3])
            love.graphics.rectangle("fill", x, y, w, h, 4)
            love.graphics.setColor(0.7, 0.75, 0.8)
            love.graphics.print("소스를 찾을 수 없습니다", x + pad, y + pad)
            love.graphics.setColor(1, 1, 1)
            return y + h
        end
        local n = 1 + #src + (truncated and 1 or 0)
        local h = pad * 2 + n * DICT_ROW_H
        love.graphics.setColor(art.pal.panelLight[1], art.pal.panelLight[2], art.pal.panelLight[3])
        love.graphics.rectangle("fill", x, y, w, h, 4)
        local cy = y + pad
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3])
        love.graphics.print("L" .. startLine, x + pad, cy)
        cy = cy + DICT_ROW_H
        love.graphics.setColor(0.85, 0.88, 0.92)
        for _, l in ipairs(src) do
            love.graphics.print(l, x + pad, cy)
            cy = cy + DICT_ROW_H
        end
        if truncated then
            love.graphics.setColor(0.6, 0.65, 0.7)
            love.graphics.print("…", x + pad, cy)
        end
        love.graphics.setColor(1, 1, 1)
        return y + h
    end
end

-- 함수 사전 ③: 접힘 목록(> build + 유저 함수들, 클릭 판정용 self.dictRows 갱신) + 클릭된
-- 항목의 펼침 카드(목록의 해당 줄 바로 아래에 삽입돼 다음 섹션을 밀어낸다).
local function drawFuncDict(self, x, y, w)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
    love.graphics.print("함수 사전", x, y)
    local cy = y + 18

    self.dictRows = {}
    local function addRow(name, label)
        local open = self.dictOpen == name
        if open then love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3])
        else love.graphics.setColor(0.85, 0.88, 0.92) end
        love.graphics.print(label, x, cy)
        self.dictRows[#self.dictRows + 1] = { name = name, x0 = x, x1 = x + w, y0 = cy, y1 = cy + DICT_ROW_H }
        cy = cy + DICT_ROW_H
        if open then
            cy = cy + 3
            cy = drawDictCard(self, x, cy, w, name)
            cy = cy + 6
        end
    end

    addRow("build", "> build")
    addRow("demolish", "> demolish")
    addRow("world.oldest", "> world.oldest")
    local funcs = self.battle.userFuncs
    if #funcs == 0 then
        love.graphics.setColor(0.7, 0.75, 0.8)
        love.graphics.print("F5로 저장하면 함수가 등록됩니다", x, cy)
        cy = cy + DICT_ROW_H
    else
        for _, name in ipairs(funcs) do addRow(name, "  " .. name) end
    end

    cy = cy + 2
    love.graphics.setColor(0.5, 0.55, 0.6)
    love.graphics.print("(local 함수는 목록에 잡히지 않아요)", x, cy)
    cy = cy + DICT_ROW_H
    love.graphics.setColor(1, 1, 1)
    return cy
end

function play:enter(_, d, stageId, p)
    self.d, self.stageId, self.p = d, stageId, p
    self.stage = d.stages[stageId]
    self.battle = Battle(d, stageId, { items = p.items })
    self.speed = 1
    self.mx, self.my = -100, -100 -- 마우스 이동 전 호버 오탐 방지
    self.escArmed = 0
    self.tut = nil
    self.tutSaved = false
    self.dictOpen = nil     -- 함수 사전 펼침 상태: nil | "build" | 함수명
    self.dictRows = {}      -- 정보 칼럼 사전 목록 클릭 판정({name,x0,x1,y0,y1})
    self.funcCounted = {}   -- 판당 funcbook 카운트 1회 가드(이름별)
    self.autotype = nil                 -- {target=문자열, pos=글자수, timer}
    self.buttons = {}
    if self.stage.buttons_file ~= "" then
        local chunk = loadstring(loadText(d.root, self.stage.buttons_file) or "")
        if chunk then self.buttons = chunk() or {} end
    end
    -- 로어(브리핑/포스트모템): db.lua와 동일하게 io 기반 로드(순수 Lua, love API 미사용).
    -- lore_file이 비어 있으면 self.lore는 nil로 남아 브리핑 문단이 조용히 생략된다.
    self.lore = nil
    if self.stage.lore_file and self.stage.lore_file ~= "" then
        local chunk = loadstring(loadText(d.root, self.stage.lore_file) or "")
        if chunk then self.lore = chunk() end
    end
    self.editor = Editor(656, 48, 610, 470)
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
    self.enemyColors = {}               -- 진행 바 스폰 눈금 색 캐시(d.enemies[id].color 파싱)
    do
        local seen = {}
        for _, ev in ipairs(self.info.events) do
            if not seen[ev.spawn] then
                seen[ev.spawn] = true
                self.enemyTypes[#self.enemyTypes + 1] = ev.spawn
            end
            if not self.enemyColors[ev.spawn] then
                local def = d.enemies[ev.spawn]
                self.enemyColors[ev.spawn] = parseColor(def and def.color)
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
        crisisTimer = 0,                 -- 위기 경고 비네트 사인 펄스용 누적 타이머 — 원시 dt(배속 무관)
        prevPhased = {},                 -- 하이젠버그 은신→재출현 전환 감지(프레임-diff)용
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
        -- funcbook 영구 수집: 판당 이름별 1회만 등록/카운트한다(F5를 여러 번 눌러도 중복 집계 방지).
        self.funcCounted = self.funcCounted or {}
        for _, name in ipairs(self.battle.userFuncs) do
            if not self.funcCounted[name] then
                self.funcCounted[name] = true
                self.p.funcbook[name] = self.p.funcbook[name] or { first = self.stageId, count = 0 }
                self.p.funcbook[name].count = self.p.funcbook[name].count + 1
            end
        end
        progress.save(self.p)
        self.fx.devAnim.pose = "typing"; self.fx.devAnim.timer = 1.0  -- 저장 성공 → 타이핑 1초
        if #self.battle.towers > before and self.tut then self.tut:notify("built") end
        if self.tut then self.tut:notify("saved") end
    else
        -- 저장 실패는 하단 빨간 한 줄뿐이라 전투에 집중하면 놓친다 — 아바타 알람 +
        -- 에디터 테두리 플래시로 배포 실패를 몸으로 느끼게 한다.
        self.fx.devAnim.pose = "alarm"; self.fx.devAnim.timer = 1.0
        self.fx.saveErrFlash = 0.7
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

    -- 스플래시 명중 감지 준비(프레임-diff): battle:update가 죽거나 소멸한 투사체를 배열에서
    -- 즉시 제거해 버리므로, 아직 안 끝난 splash 투사체 "참조"를 미리 붙잡아 둔다 — 같은
    -- 오브젝트이므로 update 후 splashHit(코어가 명중 순간 직접 세팅한 순수 관측 필드)만
    -- 읽으면 이번 프레임에 실제 폭발이 있었는지 정확히 알 수 있다(배열 소멸 여부로 추측하는
    -- 방식은 target이 다른 이유로 먼저 사라진 경우와 구별이 안 돼 오탐할 수 있었다).
    local splashWatch = {}
    for _, p in ipairs(self.battle.projectiles) do
        if p.splash and not p.done then splashWatch[#splashWatch + 1] = p end
    end

    self.battle:update(dt * self.speed)
    if self.tut and self.tut:done() and not self.tutSaved then
        self.tutSaved = true
        self.p.tutorial_done[self.stageId] = true
        progress.save(self.p)
    end

    if self.battle.status == "clear" or self.battle.status == "defeat" then
        Gamestate.switch(require("states.result"), self.battle.status,
            { d = self.d, stageId = self.stageId, p = self.p,
              guguUsed = self.fx.guguSeen or false, towerCount = #self.battle.towers,
              serverHP = self.battle.serverHP, clock = self.battle.clock,
              reached = self.battle.reachedByType })
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

    -- 스플래시 명중 링: 위에서 붙잡아 둔 splashWatch 중 이번 프레임에 실제로 폭발한
    -- (splashHit) 투사체만 명중 좌표(hitX,hitY)에 gc-collector 색 링을 띄운다. 반경을
    -- 60px 스케일로 보이게 하려고 burst의 기본 ttl(0.5·speed60→반경30)만 1.0으로 늘려
    -- speed60×ttl1.0=반경60에 맞춘다(파티클 로직 자체는 손대지 않는다).
    do
        local gcColor = parseColor(self.d.towers["gc-collector"] and self.d.towers["gc-collector"].color)
        for _, p in ipairs(splashWatch) do
            if p.splashHit then
                particles.spawn("burst", p.hitX, p.hitY, { count = 12, ttl = 1.0, color = gcColor })
            end
        end
    end

    -- 하이젠버그 은신→재출현 전환 감지: 이전 프레임엔 은신, 이번 프레임엔 가시로 바뀐
    -- 순간에만 짧은 재출현 플래시를 띄운다(phase 없는 적은 항상 false라 무시된다).
    for _, e in ipairs(b.enemies) do
        if e.abilities.phase then
            local nowPhased = e:isPhased(b.clock)
            if fx.prevPhased[e.id] and not nowPhased then
                particles.spawn("flash", e.x, e.y, { ttl = 0.2, color = art.pal.purple })
            end
            fx.prevPhased[e.id] = nowPhased
        end
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
        for i = fx.prevTowerCount + 1, #b.towers do
            local tw = b.towers[i]
            particles.spawn("flash", tw.x, tw.y, { color = art.pal.cyan })
            if tw.def.id == "gugu-class" then
                fx.guguFx = 1.2
                fx.guguSeen = true
                fx.shake = 0.4
                -- 구구단 파티클 6개: 타워 위치가 아니라 전장 여러 x,y에 흩뿌린다(3열×2행) —
                -- 타워가 우상단(적 구성 패널 부근)에 세워져도 패널 텍스트와 겹치지 않도록.
                for j = 1, 6 do
                    local col = (j - 1) % 3
                    local row = math.floor((j - 1) / 3)
                    local px = FIELD_W * (col + 0.5) / 3
                    local py = FIELD_H * 0.32 + row * FIELD_H * 0.34
                    particles.spawn("float", px, py,
                        { text = ("2 × %d = %d"):format(j, 2 * j), color = art.pal.orange, ttl = 1.4 })
                end
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
    -- ESC 포기 확인 대기 시간 감쇠 (원시 dt — 배속 무관하게 3초 유지)
    if (self.escArmed or 0) > 0 then self.escArmed = self.escArmed - dt end
    -- 저장 실패 테두리 플래시 감쇠 (원시 dt)
    if (fx.saveErrFlash or 0) > 0 then fx.saveErrFlash = fx.saveErrFlash - dt end
    -- 위기 경고 비네트 사인 펄스 누적 (원시 dt — 배속 무관하게 항상 흘러 위기 진입 시 끊김 없이 이어짐)
    fx.crisisTimer = fx.crisisTimer + dt
    particles.update(dt)
end

function play:draw()
    local b = self.battle
    local fx = self.fx
    local t = love.timer.getTime()
    -- 셰이크는 전장(그리드/엔티티/파티클)에만 — 에디터/HUD/튜토리얼은 고정
    local shakeX = fx.shake > 0 and math.sin(t * 60) * 3 or 0
    local shakeY = fx.shake > 0 and math.cos(t * 60) * 3 or 0

    -- 상단 바: HUD 텍스트 · 진행 바 · 좌표 열 라벨을 창 폭 전체(y=0~GRID_Y)의 불투명 패널
    -- 위에 그려 전장(GRID_Y=48부터) 및 정보 칼럼/에디터 헤더(둘 다 y=48부터 시작)와 명확히
    -- 분리한다 — 이 셋 다 y<GRID_Y 안에 들어가도록 y를 조정했다(HUD 6~24, 진행 바 26~30,
    -- 열 라벨 32~46, 2px 여유를 두고 GRID_Y와 만난다).
    love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3], 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), GRID_Y)

    love.graphics.setFont(fonts.ui)
    local clockText = b.clock < 0
        and ("전투 시작까지 %d초 — 코드를 준비하세요!"):format(math.ceil(-b.clock))
        or ("%.0f / 300초"):format(b.clock)
    -- 위기 경고: serverHP<=3이며 전투가 계속 진행 중이면 "서버 HP n" 부분만 빨갛게 강조하기
    -- 위해 문자열을 셋으로 나눠 print를 세 번 호출한다(가운데 조각만 색이 다름).
    local crisis = b.serverHP <= 3 and b.status == "running"
    local hudLead = clockText .. "   "
    local hudHP = ("서버 HP %d"):format(b.serverHP)
    local hudTail = ("   잔액 %d   배속 x%g"):format(b.money, self.speed)
    local hx = 8
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.print(hudLead, hx, 6)
    hx = hx + fonts.ui:getWidth(hudLead)
    if crisis then love.graphics.setColor(art.pal.red[1], art.pal.red[2], art.pal.red[3])
    else love.graphics.setColor(0.9, 0.92, 0.95) end
    love.graphics.print(hudHP, hx, 6)
    hx = hx + fonts.ui:getWidth(hudHP)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.print(hudTail, hx, 6)

    -- 진행 바 (HUD 아래, 300초 대비 현재 시각 + 스폰 이벤트 눈금)
    do
        local barX, barY, barW, barH = GRID_X, 26, FIELD_W, 4
        love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3], 0.9)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        local frac = math.max(0, math.min(1, b.clock / Battle.TOTAL))
        love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3], 0.9)
        love.graphics.rectangle("fill", barX, barY, barW * frac, barH)
        -- 스폰 눈금: 적 종류 색(d.enemies[ev.spawn].color)으로 구분 표시, 지나간 눈금은
        -- 알파를 낮춰(0.35) 앞으로 올 이벤트와 구분한다.
        for _, ev in ipairs(self.info.events) do
            local tx = barX + (ev.at / Battle.TOTAL) * barW
            local col = self.enemyColors[ev.spawn] or art.pal.cyan
            local a = (b.clock >= ev.at) and 0.35 or 0.9
            love.graphics.setColor(col[1], col[2], col[3], a)
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
    -- 행·열 좌표 라벨 (코드로 좌표를 지정하므로 상시 표기) — 진행 바(y=26~30)와 전장
    -- 타일(y=GRID_Y=48부터) 사이, 상단 바 안(y=32~46)에 들어가도록 GRID_Y-16 오프셋에서
    -- 그린다(fonts.small 높이 14 → 46, GRID_Y와 2px 여유).
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 0.55, 0.6)
    for c = 1, grid.COLS do love.graphics.print(tostring(c), GRID_X + shakeX + (c - 1) * grid.CELL + 10, GRID_Y + shakeY - 16) end
    for r = 1, grid.ROWS do love.graphics.print(tostring(r), GRID_X + shakeX - 6 - fonts.small:getWidth(tostring(r)) + 4, GRID_Y + shakeY + (r - 1) * grid.CELL + 8) end
    -- 서버라인
    art.drawServerline(GRID_X + shakeX, GRID_Y + shakeY + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, t)

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
    -- 적 (hit 점멸 — 흰 실루엣 시트, 하이젠버그 은신 중엔 알파 0.25로 깜빡임)
    for _, e in ipairs(b.enemies) do
        local ex, ey = GRID_X + shakeX + e.x, GRID_Y + shakeY + e.y
        local hit = (fx.hitTimer[e.id] or 0) > 0
        local phased = e.abilities.phase and e:isPhased(b.clock)
        art.drawEnemy(e.def.id, ex, ey, t, hit, phased and 0.25 or nil)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", ex - 10, ey - 16, 20, 3)
        love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
        love.graphics.rectangle("fill", ex - 10, ey - 16, 20 * e.hp / e.max_hp, 3)
        -- slowfield: 감속 중인 적 하단에 작은 파란 점(2px, cyan) — 디버거 사거리 안 표시
        if e.slowed then
            love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3])
            love.graphics.rectangle("fill", ex - 1, ey + 14, 2, 2)
        end
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

    -- 위기 경고 비네트: 서버 HP가 3 이하로 떨어지고 전투가 계속되는 동안 전장 가장자리에
    -- 붉은 테두리를 4겹 알파 그라데이션으로 겹쳐 그리고, 1.2초 주기 사인 펄스(원시 dt 누적
    -- 타이머 fx.crisisTimer — 배속 무관)로 밝기를 흔든다.
    if b.serverHP <= 3 and b.status == "running" then
        local pulse = 0.5 + 0.5 * math.sin(fx.crisisTimer / 1.2 * (2 * math.pi))
        love.graphics.setLineWidth(1)
        for i = 1, 4 do
            local inset = (i - 1) * 2
            local a = (0.55 - (i - 1) * 0.1) * pulse
            love.graphics.setColor(art.pal.red[1], art.pal.red[2], art.pal.red[3], a)
            love.graphics.rectangle("line", GRID_X + inset, GRID_Y + inset, FIELD_W - inset * 2, FIELD_H - inset * 2)
        end
        love.graphics.setColor(1, 1, 1)
    end

    -- 타워 호버: 사거리 원(전장 안으로 클리핑) — 코드로 (행,열)을 지정하는 게임이라
    -- 사거리 감각이 배치 판단의 핵심인데 지금까지 시각화가 없었다. 툴팁은 draw 끝에서
    -- (문제 카드 위 z순서로) 그리도록 hoverTower만 여기서 확정한다.
    self.hoverTower = nil
    for _, tw in ipairs(b.towers) do
        local hx, hy = GRID_X + shakeX + tw.x, GRID_Y + shakeY + tw.y
        if math.abs((self.mx or -100) - hx) <= 16 and math.abs((self.my or -100) - hy) <= 16 then
            self.hoverTower = tw
            if (tw.def.range or 0) > 0 then
                love.graphics.setScissor(GRID_X, GRID_Y, FIELD_W, FIELD_H)
                love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3], 0.08)
                love.graphics.circle("fill", hx, hy, tw.def.range)
                love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3], 0.45)
                love.graphics.circle("line", hx, hy, tw.def.range)
                love.graphics.setScissor()
                love.graphics.setColor(1, 1, 1)
            end
            break
        end
    end

    -- 정보 칼럼 (전장과 에디터 사이, x=400 y=48 w=240 h=512 — 전장과 바닥이 나란하다):
    -- ① 문제 요약 ② 적 구성(구 전장 오버레이 흡수) ③ 함수 사전 자리(Task 3 스텁)
    -- ④ 전투 로그(구 전장 오버레이 흡수, 최근 8줄). 셰이크는 전장 전용이라 이 칼럼은
    -- 흔들리지 않는다(에디터/HUD와 동일하게 고정).
    do
        local ix, iy, iw, ih = INFO_X, GRID_Y, INFO_W, FIELD_H
        local pad = 10
        -- 함수 사전 카드 펼침 + 적 구성 줄바꿈이 겹치면 내용이 칼럼 바닥(iy+ih)을 넘어설 수
        -- 있으므로, 칼럼 밖(힌트바/창 밖)으로 새지 않도록 draw 전체를 scissor로 감싼다.
        love.graphics.setScissor(ix, iy, iw, ih)
        love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3])
        love.graphics.rectangle("fill", ix, iy, iw, ih)
        local cx, cy = ix + pad, iy + pad
        local cw = iw - pad * 2

        -- ① 문제 요약
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
        love.graphics.print("문제 요약", cx, cy)
        cy = cy + 18
        love.graphics.setColor(0.85, 0.88, 0.92)
        love.graphics.print(("[문제 %d] %s"):format(self.stageId, self.stage.concept), cx, cy)
        cy = cy + 16
        love.graphics.setColor(0.7, 0.75, 0.8)
        love.graphics.print("영역: " .. self.stage.theme, cx, cy)
        cy = cy + 16
        love.graphics.setColor(0.55, 0.6, 0.65)
        love.graphics.print("Ctrl+I 상세", cx, cy)
        cy = cy + 22

        -- ② 적 구성 (구 전장 우상단 오버레이 이동) — 모든 스폰이 끝나면 "잔여 소탕" 한 줄 추가
        love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
        love.graphics.print("적 구성", cx, cy)
        cy = cy + 20
        local killed = stageinfo.killedCounts(self.info, b)
        local sweeping = b.clock >= self.info.lastEnd and (b.status == "running" or b.status == "clear")
        local rowH = 26
        local nameW = cw - 32 -- 아이콘(32px) 뺀 이름 가용 폭 — 좁은 칼럼 밖(에디터 쪽)으로
        -- 넘치지 않도록 긴 이름(예: concat-nil의 농담 이름 "attempt to concatenate a nil
        -- value")은 printf로 줄바꿈하고, 줄바꿈된 만큼 행 높이를 늘린다.
        for _, id in ipairs(self.enemyTypes) do
            local def = self.d.enemies[id]
            local name = def and def.name or id
            local _, wrapped = fonts.small:getWrap(name, nameW)
            local nameLines = math.max(1, #wrapped)
            local blockH = math.max(rowH, nameLines * 16 + 16 + 6)
            art.drawEnemy(id, cx + 14, cy + blockH / 2, t, false)
            local kn = killed[id] or 0
            local tot = self.info.byType[id] or 0
            love.graphics.setColor(0.85, 0.88, 0.92)
            love.graphics.printf(name, cx + 32, cy + 2, nameW, "left")
            love.graphics.setColor(0.6, 0.9, 0.7)
            love.graphics.print(("처리 %d / %d"):format(kn, tot), cx + 32, cy + 2 + nameLines * 16)
            cy = cy + blockH
        end
        if sweeping then
            love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
            love.graphics.print("잔여 소탕 · 생존!", cx, cy + rowH / 2 - 7)
            cy = cy + rowH
        end
        cy = cy + 6

        -- ③ 함수 사전 자리 (Task 3이 본 구현)
        cy = drawFuncDict(self, cx, cy, cw)
        cy = cy + 8

        -- ④ 전투 로그 (최근 최대 8줄, 오래된 줄일수록 옅어지는 페이드 유지) — 위 섹션들이
        -- 이미 칼럼 바닥 근처까지 차 있으면 scissor로 잘리기 전에 표시 줄 수 자체를 남은
        -- 높이만큼 줄인다(0줄 이하면 섹션 자체를 생략).
        local avail = (iy + ih) - cy
        local rows = math.min(8, math.floor((avail - 18) / 18))
        if rows > 0 then
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
            love.graphics.print("전투 로그", cx, cy)
            cy = cy + 18
            local logCount = math.min(rows, #b.log)
            local startI = math.max(1, #b.log - logCount + 1)
            for i = startI, #b.log do
                local idx = i - startI + 1
                love.graphics.setColor(0.8, 0.82, 0.86, 1 - (logCount - idx) * 0.1)
                love.graphics.print(b.log[i], cx, cy)
                cy = cy + 16
            end
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.setScissor()
    end

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
        love.graphics.print("버튼 → 코드 자동 입력·저장:", self.editor.x, 520)
        for i, btn in ipairs(self.buttons) do
            love.graphics.setColor(0.85, 0.88, 0.92)
            love.graphics.print(("[%d] %s"):format(i, btn.label), self.editor.x, 534 + (i - 1) * 13)
        end
    else
        self.editor:draw(fonts, true)
    end

    -- 저장 오류
    if b.scriptError then
        love.graphics.setColor(1, 0.45, 0.4)
        love.graphics.printf("저장 실패 — " .. b.scriptError, self.editor.x, 545, self.editor.w, "left")
    end
    -- 저장 실패 직후 에디터 테두리 플래시 (놓치기 쉬운 하단 한 줄을 보강)
    if (fx.saveErrFlash or 0) > 0 then
        love.graphics.setColor(1, 0.35, 0.3, math.min(1, fx.saveErrFlash * 1.4))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.editor.x - 4, self.editor.y - 4,
            self.editor.w + 8, self.editor.h + 8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1)
    end
    -- 힌트바 (튜토리얼 말풍선이 대신 안내하는 동안은 겹치지 않도록 숨긴다)
    if not (self.tut and not self.tut:done()) then
        love.graphics.setColor(0.6, 0.65, 0.7)
        local hint = self:isButtonStage()
            and "숫자키 버튼 실행 · Ctrl+5/1/2/4 배속 · Ctrl+I 문제 · Ctrl+R 재시작 · ESC 포기"
            or "F5 저장·반영 · F1~F4 스니펫 · Ctrl+L 비우기 · Ctrl+5/1/2/4 배속 · Ctrl+I 문제 · Ctrl+R 재시작 · ESC 포기"
        love.graphics.printf(hint, 0, 620, 1280, "center")
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
        local combinedW = (INFO_X + INFO_W) - GRID_X -- 전장+정보 칼럼 기준 중앙(x≈320)
        local cardX = GRID_X + (combinedW - cardW) / 2
        local pad = 14
        -- 브리핑 문단(Task 5, §8): 문제 서술(problem) 위에 서사체 도입부를 얹는다.
        -- lore 파일이 없거나 briefing이 비어 있으면 briefH=0이라 카드가 기존 그대로 190 높이.
        love.graphics.setFont(fonts.small)
        local briefing = self.lore and self.lore.briefing
        local briefLines = 0
        if briefing and briefing ~= "" then
            local _, wrapped = fonts.small:getWrap(briefing, cardW - pad * 2)
            briefLines = math.max(1, #wrapped)
        end
        local briefH = briefLines > 0 and (briefLines * fonts.small:getHeight() + 10) or 0
        local cardH = 190 + briefH
        local cardY = GRID_Y + (grid.ROWS * grid.CELL - cardH) / 2
        love.graphics.setColor(art.pal.panel[1], art.pal.panel[2], art.pal.panel[3], 0.94)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6)
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3], 0.8)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6)
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(art.pal.white[1], art.pal.white[2], art.pal.white[3])
        love.graphics.printf(("[문제 %d] %s"):format(self.stageId, stage.concept), cardX + pad, cardY + pad, cardW - pad * 2, "left")
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3])
        love.graphics.printf("영역: " .. stage.theme, cardX + pad, cardY + pad + 24, cardW - pad * 2, "left")
        local textY = cardY + pad + 46
        if briefLines > 0 then
            love.graphics.setColor(0.6, 0.63, 0.68) -- 회색 서사체 — 문제 서술(흰색)과 톤 구분
            love.graphics.printf(briefing, cardX + pad, textY, cardW - pad * 2, "left")
            textY = textY + briefH
        end
        love.graphics.setColor(0.85, 0.88, 0.92)
        love.graphics.printf(stage.problem, cardX + pad, textY, cardW - pad * 2, "left")
        love.graphics.setColor(0.7, 0.75, 0.8)
        love.graphics.printf(("제한: 예산 %d · 유입 예정 %d기"):format(stage.budget, self.info.total),
            cardX + pad, cardY + cardH - 58, cardW - pad * 2, "left")
        love.graphics.printf("제출: F5 · 채점: 300초 생존", cardX + pad, cardY + cardH - 40, cardW - pad * 2, "left")
        love.graphics.setColor(0.55, 0.6, 0.65)
        love.graphics.printf("Enter 닫기 · Ctrl+I 다시 보기", cardX + pad, cardY + cardH - 20, cardW - pad * 2, "left")
        love.graphics.setColor(1, 1, 1)
    end

    -- 타워 호버 툴팁 (문제 카드보다 위, 튜토리얼 말풍선보다 아래 z순서)
    if self.hoverTower then
        local tw = self.hoverTower
        local dmg = (tw.def.damage or 0) * (tw.dan or 1)
        local lines = {
            tw.def.name .. (tw.dan and (" %d단"):format(tw.dan) or "")
                .. (tw.name and tw.name ~= "" and (" [" .. tw.name .. "]") or ""),
            ("데미지 %d · 사거리 %d · 쿨다운 %.1f초"):format(dmg, tw.def.range or 0, tw.def.cooldown or 0),
        }
        if tw.crashed > 0 or tw.disabled then lines[#lines + 1] = "상태: 크래시 — F5 재배포로 복구" end
        love.graphics.setFont(fonts.small)
        local wMax = 0
        for _, s in ipairs(lines) do wMax = math.max(wMax, fonts.small:getWidth(s)) end
        local bw, bh = wMax + 16, #lines * 16 + 12
        local bx = math.min((self.mx or 0) + 14, love.graphics.getWidth() - bw - 4)
        local by = math.min((self.my or 0) + 14, love.graphics.getHeight() - bh - 4)
        love.graphics.setColor(0.05, 0.07, 0.12, 0.93)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
        love.graphics.setColor(art.pal.cyan[1], art.pal.cyan[2], art.pal.cyan[3], 0.4)
        love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)
        love.graphics.setColor(0.85, 0.88, 0.92)
        for i, s in ipairs(lines) do love.graphics.print(s, bx + 8, by + 6 + (i - 1) * 16) end
        love.graphics.setColor(1, 1, 1)
    end

    -- ESC 포기 확인 토스트
    if (self.escArmed or 0) > 0 then
        local W = love.graphics.getWidth()
        local msg = "한 번 더 ESC를 누르면 전투를 포기합니다 · Ctrl+R 즉시 재시작"
        love.graphics.setFont(fonts.ui)
        local mw = fonts.ui:getWidth(msg) + 28
        love.graphics.setColor(0.05, 0.05, 0.08, 0.85)
        love.graphics.rectangle("fill", (W - mw) / 2, 296, mw, 36, 6, 6)
        love.graphics.setColor(1, 0.75, 0.4)
        love.graphics.printf(msg, 0, 304, W, "center")
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
        -- 5분짜리 판이 오타 한 번에 날아가지 않도록 2단 확인: 3초 안에 한 번 더 누르면 포기.
        if (self.escArmed or 0) > 0 then
            Gamestate.switch(require("states.stageselect"), self.d, self.p)
        else
            self.escArmed = 3
        end
        return
    end
    if ctrl and key == "r" then
        Gamestate.switch(require("states.play"), self.d, self.stageId, self.p)
        return
    end
    if ctrl and (key == "1" or key == "2" or key == "4" or key == "5") then
        self.speed = (key == "5") and 0.5 or tonumber(key)
        if self.tut then self.tut:notify("speed_changed") end
        return
    end
    if self:isButtonStage() then
        local i = tonumber(key)
        if i and self.buttons[i] and not self.autotype then self:pressButton(i) end
        return
    end
    if ctrl and key == "l" then
        -- 힌트 템플릿을 버리고 처음부터 짤 때 지우기 수단이 Backspace 연타뿐이었다.
        self.editor:setText("")
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

-- 함수 사전 클릭 연동: 에디터에서 build/유저 함수 식별자를 클릭하거나, 정보 칼럼의
-- 사전 목록 항목을 직접 클릭하면 dictOpen을 토글(같은 항목 재클릭 시 닫힘)/교체한다.
-- 그 외 클릭(빈 곳, 다른 식별자, 우클릭 등)은 무시한다.
function play:mousemoved(x, y)
    self.mx, self.my = x, y
end

function play:mousepressed(x, y, button)
    if button ~= 1 then return end
    -- 문제 카드가 열려 있으면 좌클릭은 카드 닫기로만 소비한다(Enter 닫기와 대칭) — 그렇지
    -- 않으면 카드 뒤에 가려진 사전 목록이 오작동으로 클릭될 수 있다.
    if self.showBrief then self.showBrief = false; return end
    local editor = self.editor
    if x >= editor.x and x < editor.x + editor.w and y >= editor.y and y < editor.y + editor.h then
        local lineH = fonts.mono:getHeight() + 4
        local measure = function(s) return fonts.mono:getWidth(s) end
        local li, ci = editor:charAt(x - editor.x, y - editor.y, lineH, measure)
        if not li then return end
        local tok = Editor.tokenAt(editor.lines[li], ci)
        if not tok then return end
        local isDict = BUILTIN_DOCS[tok] ~= nil
        if not isDict then
            for _, name in ipairs(self.battle.userFuncs) do
                if name == tok then isDict = true break end
            end
        end
        if isDict then self.dictOpen = (self.dictOpen == tok) and nil or tok end
        return
    end

    for _, row in ipairs(self.dictRows or {}) do
        if x >= row.x0 and x < row.x1 and y >= row.y0 and y < row.y1 then
            self.dictOpen = (self.dictOpen == row.name) and nil or row.name
            return
        end
    end
end

return play
