# codedefense 비주얼 에셋+세계관 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 코드 생성 픽셀아트(네온 서버실 테마 + 안경 쓴 개발자 캐릭터)와 파티클 이펙트로 게임을 시각적으로 완성하고, 개발자의 애환을 담은 인트로 컷신 4장면 + 타이틀 메뉴 "세계관" 항목으로 세계관을 전달한다.

**Architecture:** 전투 코어는 불변. `src/art.lua`(로드 시 캔버스 생성 아트 + 그리기 헬퍼), `src/particles.lua`(뷰 전용 파티클), `src/cutscene.lua`(순수 진행 로직) 3개 모듈을 신설하고, play/title/result/stageselect의 그리기와 `states/intro.lua`만 얹는다. 이펙트는 play가 프레임 간 battle 상태 비교로 발동한다.

**Tech Stack:** LÖVE 11.5, 기존 모듈 재사용. 외부 에셋·의존성 없음 (나눔고딕 폰트 제외).

**Spec:** `docs/superpowers/specs/2026-07-22-codedefense-visual-lore-design.md`

## Global Constraints

- **전투 코어(battle/api/sandbox/tutorial/editor) 파일 수정 금지** — 기존 테스트 141개 무손상이 합격 조건
- 에셋은 전부 `love.graphics` 프리미티브로 캔버스에 그려 로드 시 1회 생성, nearest 필터. 외부 이미지/사운드 금지
- 팔레트는 `art.pal` 상수 테이블 하나로 통일: bg `#0e1220` 근처 다크 네이비, 패널 `#171c2e`, 네온 그린 `#3cf07c`, 시안 `#41d8e0`, 마젠타 `#e04fd8`, 레드 `#e8483f`, 오렌지 `#f0a03c`, 퍼플 `#a06ce8`, 화이트 `#e8ecf4` (0..1 스케일 변환값으로 정의)
- 파티클 상한 400개, 초과 시 오래된 것부터 제거. 파티클·이펙트는 시뮬에 영향 금지 (읽기 전용)
- 개발자 캐릭터: 안경 쓴 귀여운 남성, 포즈 3종(idle 눈 깜빡임/typing 손 2프레임/alarm 안경 번쩍)
- 인트로 4장면 텍스트는 설계서 4.1의 문구 그대로 (한 글자도 바꾸지 않음)
- 결과 여운 문구: 클리어 "오늘도 서비스는 무사히 돌아간다. 아무 일 없었다는 듯이." / 패배 "서버가 내려갔다. 하지만 개발자는 다시 일어선다."
- 유저 대면 텍스트 전부 한글. 결정론 유지 (아트 애니메이션은 love.timer 기반 — 시뮬과 무관하므로 허용)
- 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` (PowerShell). 스크린샷 검증은 스크래치패드 하네스 (리포 미포함)
- 커밋은 태스크마다, 브랜치 `feature/codedefense-tutorial`

## File Structure

```
신규: src/particles.lua   ← spawn/update/draw/count/clear, MAX=400 (draw만 love 의존)
신규: src/cutscene.lua    ← 컷신 진행 순수 로직 (love 비의존, 헤드리스 테스트)
신규: src/art.lua         ← art.pal + art.load() + 그리기 헬퍼 (전장/타워/몬스터/개발자/로고/인트로 장면)
신규: states/intro.lua    ← cutscene 로직 + art 일러스트 + 타이프라이터 렌더
변경: main.lua            ← art.load(), 첫 실행 intro 분기
변경: states/play.lua     ← 그리기 교체 + frame-diff 이펙트 + 셰이크 + IDE 패널/아바타
변경: states/title.lua    ← 메뉴 3항목 + 배경 아트 + 로고
변경: states/result.lua   ← 여운 문구 + 팔레트 톤
변경: states/stageselect.lua ← 팔레트 톤
변경: src/progress.lua    ← intro_seen 보강
변경: tests/main.lua      ← suites에 test_particles, test_cutscene 추가
신규: tests/test_particles.lua, tests/test_cutscene.lua
```

---

### Task 1: particles.lua — 뷰 전용 파티클 시스템

**Files:**
- Create: `love2d-codedefense/src/particles.lua`, `love2d-codedefense/tests/test_particles.lua`
- Modify: `love2d-codedefense/tests/main.lua` (suites에 "test_particles")

**Interfaces:**
- Produces: `particles.spawn(kind, x, y, opts)` (kind: "spark"|"burst"|"float"|"smoke"|"flash"; opts: color={r,g,b}, text=문자열(float용), count=개수(burst/spark)), `particles.update(dt)`, `particles.draw(ox, oy)` (love 의존 — 테스트에서 호출 금지), `particles.count() → n`, `particles.clear()`, `particles.MAX = 400`. smoke는 opts.ttl(기본 0.6) 수명의 단발 스폰 — 지속 연기는 호출자가 주기적으로 재스폰.

- [ ] **Step 1: 실패하는 테스트** — `tests/test_particles.lua`:

```lua
return function(t)
    local particles = require("src.particles")
    particles.clear()

    particles.spawn("spark", 10, 10, { count = 5 })
    t.eq(particles.count(), 5, "spark 5개 스폰")

    particles.spawn("float", 10, 10, { text = "+10" })
    t.eq(particles.count(), 6, "float 텍스트 스폰")

    -- 수명 만료 제거 (spark ttl 0.35, float ttl 0.9)
    particles.update(0.5)
    t.eq(particles.count(), 1, "spark 만료 후 float만 생존")
    particles.update(0.5)
    t.eq(particles.count(), 0, "float 만료")

    -- 상한: 오래된 것부터 제거
    particles.clear()
    for i = 1, 450 do particles.spawn("spark", i, 0, { count = 1 }) end
    t.eq(particles.count(), particles.MAX, "상한 400 유지")

    -- 이동 갱신 (결정론 무관, vy 존재 확인)
    particles.clear()
    particles.spawn("burst", 0, 0, { count = 3 })
    local before = particles.count()
    particles.update(0.01)
    t.eq(particles.count(), before, "짧은 dt에는 생존")
end
```

- [ ] **Step 2: suites 등록 후 실행 — FAIL 확인** (`module 'src.particles' not found`)

- [ ] **Step 3: 구현** — `src/particles.lua`:

```lua
-- 뷰 전용 파티클. 시뮬 상태를 절대 만지지 않는다.
local particles = {}
particles.MAX = 400

local pool = {}

-- 각 파티클: {kind, x, y, vx, vy, ttl, age, color, text, size}
-- 방향은 스폰 인덱스 기반 고정 각도(랜덤 금지 — 뷰라도 코드 단순성/재현성 유지)
local function push(p)
    if #pool >= particles.MAX then table.remove(pool, 1) end
    pool[#pool + 1] = p
end

local KIND = {
    spark = { ttl = 0.35, speed = 90, size = 2 },
    burst = { ttl = 0.5, speed = 60, size = 3 },
    float = { ttl = 0.9, speed = 30, size = 0 },
    smoke = { ttl = 0.6, speed = 18, size = 4 },
    flash = { ttl = 0.18, speed = 0, size = 14 },
}

function particles.spawn(kind, x, y, opts)
    opts = opts or {}
    local def = KIND[kind]
    if not def then return end
    local n = opts.count or 1
    if kind == "float" or kind == "flash" then n = 1 end
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + (kind == "spark" and 0.4 or 0)
        push({
            kind = kind, x = x, y = y,
            vx = math.cos(ang) * def.speed,
            vy = (kind == "float" or kind == "smoke") and -def.speed
                or math.sin(ang) * def.speed,
            ttl = opts.ttl or def.ttl, age = 0,
            color = opts.color or { 1, 1, 1 },
            text = opts.text, size = def.size,
        })
    end
end

function particles.update(dt)
    for i = #pool, 1, -1 do
        local p = pool[i]
        p.age = p.age + dt
        if p.age >= p.ttl then
            table.remove(pool, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

function particles.draw(ox, oy)
    for _, p in ipairs(pool) do
        local a = 1 - p.age / p.ttl
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        if p.text then
            love.graphics.print(p.text, ox + p.x, oy + p.y)
        elseif p.kind == "flash" then
            love.graphics.circle("line", ox + p.x, oy + p.y, p.size * (1 - a) * 2 + 4)
        else
            local s = p.size
            love.graphics.rectangle("fill", ox + p.x - s / 2, oy + p.y - s / 2, s, s)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function particles.count() return #pool end
function particles.clear() pool = {} end

return particles
```

- [ ] **Step 4: 통과 확인** (기존 141 + 신규 = 전부 PASS) → **Step 5: Commit** `codedefense: 파티클 시스템`

---

### Task 2: cutscene.lua 순수 로직 + progress.intro_seen

**Files:**
- Create: `love2d-codedefense/src/cutscene.lua`, `love2d-codedefense/tests/test_cutscene.lua`
- Modify: `love2d-codedefense/src/progress.lua`, `love2d-codedefense/tests/test_progress.lua`, `love2d-codedefense/tests/main.lua` (suites에 "test_cutscene")

**Interfaces:**
- Produces: `Cutscene(scenes)` — scenes = `{ {text="..."}, ... }` (일러스트는 뷰가 인덱스로 그림). 메서드: `:update(dt)` (타이프라이터 초당 30자), `:visibleText() → string`, `:sceneIndex() → n`, `:press()` (타이핑 중이면 전체 표시, 완료 상태면 다음 장면), `:skip()`, `:done() → bool`. `progress.load()`가 `intro_seen` 필드 보강 (기본 nil/false — 테이블 아님).

- [ ] **Step 1: 실패하는 테스트** — `tests/test_cutscene.lua`:

```lua
return function(t)
    local Cutscene = require("src.cutscene")
    local cs = Cutscene({ { text = "가나다라" }, { text = "마바" } })

    t.eq(cs:sceneIndex(), 1, "장면 1 시작")
    t.eq(cs:visibleText(), "", "타이핑 전 빈 텍스트")
    cs:update(2 / 30)
    t.eq(cs:visibleText(), "가나", "초당 30자 타이프라이터")
    cs:press()
    t.eq(cs:visibleText(), "가나다라", "타이핑 중 press = 전체 표시")
    cs:press()
    t.eq(cs:sceneIndex(), 2, "완료 후 press = 다음 장면")
    t.ok(not cs:done(), "아직 안 끝남")
    cs:press()  -- 장면2 전체 표시
    cs:press()  -- 장면2 넘김
    t.ok(cs:done(), "마지막 장면 넘기면 done")

    local cs2 = Cutscene({ { text = "가" }, { text = "나" } })
    cs2:skip()
    t.ok(cs2:done(), "skip 즉시 done")
end
```

또한 `tests/test_progress.lua`에 추가:

```lua
    local p2 = progress.load()
    p2.intro_seen = true
    progress.save(p2)
    t.ok(progress.load().intro_seen, "intro_seen 저장/복원")
```

- [ ] **Step 2: FAIL 확인** → **Step 3: 구현** — `src/cutscene.lua`:

```lua
local Object = require("lib.classic")
local utf8 = require("utf8")

local CHARS_PER_SEC = 30

local Cutscene = Object:extend()

function Cutscene:new(scenes)
    self.scenes = scenes
    self.idx = 1
    self.shown = 0        -- 표시된 글자 수 (실수 누적)
    self.finished = false
end

local function charLen(s)
    return utf8.len(s) or #s
end

local function sub(s, n)
    if n <= 0 then return "" end
    local total = charLen(s)
    if n >= total then return s end
    return s:sub(1, utf8.offset(s, n + 1) - 1)
end

function Cutscene:current() return self.scenes[self.idx] end
function Cutscene:sceneIndex() return self.idx end
function Cutscene:done() return self.finished end

function Cutscene:update(dt)
    if self.finished then return end
    self.shown = self.shown + dt * CHARS_PER_SEC
end

function Cutscene:visibleText()
    if self.finished then return "" end
    return sub(self:current().text, math.floor(self.shown))
end

function Cutscene:typingDone()
    return math.floor(self.shown) >= charLen(self:current().text)
end

function Cutscene:press()
    if self.finished then return end
    if not self:typingDone() then
        self.shown = charLen(self:current().text)
    elseif self.idx < #self.scenes then
        self.idx = self.idx + 1
        self.shown = 0
    else
        self.finished = true
    end
end

function Cutscene:skip()
    self.finished = true
end

return Cutscene
```

`src/progress.lua` load()의 기본값 보강 위치에 주석 한 줄과 함께 intro_seen은 **별도 보강 불필요**(불리언이라 nil이면 falsy로 동작) — 단 저장 왕복이 되는지만 테스트로 보장. (serialize가 boolean을 지원하는지 확인 — 지원함.)

- [ ] **Step 4: 통과 확인** → **Step 5: Commit** `codedefense: 컷신 진행 로직과 intro_seen`

---

### Task 3: art.lua — 팔레트·전장·타워·몬스터·개발자 캐릭터

**Files:**
- Create: `love2d-codedefense/src/art.lua`
- 검증: 스크래치패드 스크린샷 하네스 (커밋 안 함)

**Interfaces:**
- Produces (play/title 등 뷰가 쓰는 전부 — 시그니처 고정):
  - `art.pal` — 색 테이블: `bg, panel, panelLight, grid, green, cyan, magenta, red, orange, purple, white` (각 {r,g,b} 0..1)
  - `art.load()` — love.load에서 1회. 내부 캔버스 → Image 생성
  - 전장: `art.drawFloor(x, y)`, `art.drawWall(x, y, t)` (LED 점멸: t 기반 2프레임), `art.drawPad(x, y, t)` (발광 맥동), `art.drawServerline(x, y, w, t)` (맥동 게이트 바)
  - 타워: `art.drawTower(id, x, y, t, firing)` — id "printer"|"compiler"|"sniper", 32×32에 중심 정렬, t 기반 2프레임 유휴, firing=true면 총구 플래시 오버레이
  - 몬스터: `art.drawEnemy(id, x, y, t, hit)` — id "bug"|"null-ptr"|"concat-nil", 중심 정렬 걷기 2프레임, hit=true면 흰색 실루엣
  - 개발자: `art.drawDev(pose, x, y, scale, t)` — pose "idle"|"typing"|"alarm", 16×16 기반, idle은 t 기반 눈 깜빡임(3.5초 주기 0.15초), typing 손 2프레임(t*8), alarm 안경 흰 번쩍
  - 로고: `art.drawLogo(cx, y)` — "CODE DEFENSE" 픽셀 타이포 (중심 cx)
- 모든 draw 함수는 setColor를 스스로 관리하고 끝에 흰색 복원. love.timer 미사용 — t는 호출자가 넘김 (뷰의 love.timer.getTime()).

- [ ] **Step 1: 모듈 골격 + 시트 생성 패턴** — 마리오 sprites.lua 패턴 (참고로 읽을 것: `love2d-mario/src/sprites.lua`). 골격:

```lua
local art = {}

local function c(hex)  -- "#RRGGBB" → {r,g,b}
    local r = tonumber(hex:sub(2, 3), 16) / 255
    local g = tonumber(hex:sub(4, 5), 16) / 255
    local b = tonumber(hex:sub(6, 7), 16) / 255
    return { r, g, b }
end

art.pal = {
    bg = c("#0e1220"), panel = c("#171c2e"), panelLight = c("#232a42"),
    grid = c("#1c2338"), green = c("#3cf07c"), cyan = c("#41d8e0"),
    magenta = c("#e04fd8"), red = c("#e8483f"), orange = c("#f0a03c"),
    purple = c("#a06ce8"), white = c("#e8ecf4"),
}

local function setCol(col, a)
    love.graphics.setColor(col[1], col[2], col[3], a or 1)
end

-- PX 단위 픽셀 사각형을 캔버스에 찍는 헬퍼로 16x16 시트를 그린 뒤 Image화
local function makeSheet(frames, px, size, drawFrame)
    local canvas = love.graphics.newCanvas(frames * size * px, size * px)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    for f = 1, frames do
        love.graphics.push()
        love.graphics.translate((f - 1) * size * px, 0)
        love.graphics.scale(px)
        drawFrame(f)
        love.graphics.pop()
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    local img = love.graphics.newImage(canvas:newImageData())
    img:setFilter("nearest", "nearest")
    return img
end

-- 프레임 내부에서 1px 단위 도트를 찍는 헬퍼
local function dot(col, x, y, w, h)
    setCol(col)
    love.graphics.rectangle("fill", x, y, w or 1, h or 1)
end
```

`art.load()`에서 각 시트를 만들어 `art._img.*`에 저장, draw 헬퍼는 quad로 그린다.

- [ ] **Step 2: 대표 에셋 완성 코드 2종** (이 수준의 밀도로 전 에셋 제작):

bug 몬스터 (16×16, 2프레임 걷기 — 다리 위치 교차):

```lua
local function drawBugFrame(f)
    local P = art.pal
    -- 몸통: 빨간 타원형 등딱지
    dot(P.red, 4, 5, 8, 7)
    dot(P.red, 3, 6, 10, 5)
    -- 등 갈라진 선
    dot(c("#a83028"), 8, 5, 1, 7)
    -- 머리
    dot(c("#a83028"), 5, 3, 6, 3)
    -- 눈 (흰자+점)
    dot(P.white, 5, 3, 2, 2); dot(c("#000000"), 6, 4, 1, 1)
    dot(P.white, 9, 3, 2, 2); dot(c("#000000"), 9, 4, 1, 1)
    -- 더듬이
    dot(c("#a83028"), 4, 1, 1, 2); dot(c("#a83028"), 11, 1, 1, 2)
    -- 다리 3쌍 (프레임별 교차)
    local o = (f == 1) and 0 or 1
    dot(c("#601814"), 2, 7 + o, 2, 1); dot(c("#601814"), 12, 8 - o, 2, 1)
    dot(c("#601814"), 2, 9 - o, 2, 1); dot(c("#601814"), 12, 10 + o, 2, 1)
    dot(c("#601814"), 2, 11 + o, 2, 1); dot(c("#601814"), 12, 12 - o, 2, 1)
end
```

개발자 캐릭터 (16×16, idle 프레임 — 안경 쓴 귀여운 남성):

```lua
local function drawDevFrame(pose, f)
    local P = art.pal
    local skin, hair, hood = c("#f0c8a0"), c("#4a3626"), c("#3a4a6a")
    -- 후드티 몸통
    dot(hood, 3, 10, 10, 6)
    dot(c("#2c3a54"), 3, 10, 10, 1)     -- 어깨선
    -- 얼굴
    dot(skin, 4, 3, 8, 7)
    -- 머리카락 (앞머리 + 옆)
    dot(hair, 3, 2, 10, 2); dot(hair, 3, 3, 1, 3); dot(hair, 12, 3, 1, 3)
    dot(hair, 4, 4, 2, 1); dot(hair, 10, 4, 2, 1)
    -- 안경: 큰 렌즈 2개 + 브릿지, 렌즈 반사 하이라이트(시안)
    dot(c("#202430"), 4, 5, 3, 3); dot(c("#202430"), 9, 5, 3, 3)
    dot(P.cyan, 5, 6, 1, 1); dot(P.cyan, 10, 6, 1, 1)   -- 모니터 빛 반사
    dot(c("#202430"), 7, 6, 2, 1)                        -- 브릿지
    -- 눈 (idle: f==2에서 감은 눈), alarm: 안경 전체 흰 번쩍
    if pose == "alarm" then
        dot(P.white, 4, 5, 3, 3); dot(P.white, 9, 5, 3, 3)
        dot(c("#202430"), 5, 9, 6, 1)   -- 벌린 입
    elseif pose == "idle" and f == 2 then
        dot(skin, 5, 6, 1, 1); dot(skin, 10, 6, 1, 1)   -- 감은 눈(렌즈 안 스킨)
    end
    -- 입
    if pose ~= "alarm" then dot(c("#c09070"), 7, 9, 2, 1) end
    -- 팔/손 (typing: f에 따라 상하)
    if pose == "typing" then
        local o = (f == 1) and 0 or 1
        dot(skin, 2, 13 + o, 2, 1); dot(skin, 12, 14 - o, 2, 1)
    else
        dot(hood, 2, 12, 1, 3); dot(hood, 13, 12, 1, 3)
    end
end
```

- [ ] **Step 3: 나머지 에셋 명세** (같은 dot 기법, 16×16 px=2):
  - **null-ptr**: 보라 유령 실루엣(밑단 물결 3굴곡, 프레임별 물결 위상 반전), 얼굴에 흰 물음표 3도트, 눈은 어두운 세로 2도트
  - **concat-nil**: 주황 슬라임 두 덩이가 가운데 1px 다리로 연결(분열 예고), 프레임별 좌우 덩이 높이 교차, 하이라이트 도트
  - **printer 타워**: 회색 몸체 + 상단 총구 슬릿(네온 그린), 측면 배기구, 프레임2에서 상태 LED 색 변화. firing 오버레이 = 총구 위 3×3 흰/그린 플래시
  - **compiler 타워**: 티얼 몸체 + 중앙 기어(8각 도트) — 프레임별 기어 45도 회전 느낌(도트 위치 교차), 공격 없음
  - **sniper 타워**: 좁은 받침 + 긴 안테나(세로 6px) + 끝 마젠타 발광 도트(프레임별 크기), firing 시 안테나 끝 흰 플래시
  - **전장 타일** (32px 직접 그리기 — 시트 아님, drawFloor/drawWall/drawPad/drawServerline은 rectangle 조합): 벽=패널색 캐비닛+테두리+LED 2개(t 기반 green/cyan 점멸, `math.floor(t*2)%2`), 바닥=bg+grid색 1px 격자, 건설칸=바닥+green 모서리 브래킷 4개+중앙 은은한 발광(`0.15+0.1*math.sin(t*3)` 알파), 서버라인=cyan 게이트 바(알파 `0.5+0.3*math.sin(t*4)`)+상단 1px 흰 라인
  - **로고**: "CODE DEFENSE" — 5×7 도트 폰트로 두 단어(직접 도트 배열 정의), green/cyan 2색, px=3

- [ ] **Step 4: 스크린샷 검증** — 스크래치패드 `art-shot/` LÖVE 하네스: 모든 에셋을 한 화면에 나열(타워 3종×2프레임+firing, 몬스터 3종×2프레임+hit, 개발자 3포즈, 타일 4종, 로고) → `love.graphics.captureScreenshot` → 캡처 PNG를 **Read 도구로 직접 열어 눈으로 확인** (형태 붕괴·색 오류 점검). 프로젝트 `assets/` 불필요 (아트는 코드 생성).

- [ ] **Step 5: 전체 스위트 무손상 확인** (art는 아직 아무 데서도 require 안 됨 — 로드 회귀 없음) → **Step 6: Commit** `codedefense: 네온 서버실 아트 모듈 (전장·타워·몬스터·개발자)`

---

### Task 4: play.lua 비주얼 통합 — 그리기 교체 + 이펙트

**Files:**
- Modify: `love2d-codedefense/states/play.lua`, `love2d-codedefense/main.lua` (art.load 호출만 — intro 분기는 Task 5)

**Interfaces:**
- Consumes: art.* draw 헬퍼 전부, particles.*
- Produces: play가 유지하는 이펙트 상태 필드 — `self.fx = { prevEnemies = {}, prevTowerCount = 0, prevServerHP = 10, prevCrashed = {}, shake = 0, redFlash = 0, devAnim = { pose = "idle", timer = 0 } }` (Task 5의 아바타 로직이 devAnim 재사용)

- [ ] **Step 1: main.lua에 `require("src.art").load()` 추가** (fonts.load 다음)

- [ ] **Step 2: 전장 그리기 교체** — play:draw의 셀 루프에서 rectangle 색칠을 art 호출로:

```lua
local t = love.timer.getTime()
for r = 1, grid.ROWS do
    for c = 1, grid.COLS do
        local x, y = grid.toXY(r, c)
        x, y = x + GRID_X + shakeX, y + GRID_Y + shakeY
        if b.grid.build[r][c] then art.drawPad(x, y, t)
        elseif b.grid.walls[r][c] then art.drawWall(x, y, t)
        else art.drawFloor(x, y) end
    end
end
art.drawServerline(GRID_X + shakeX, GRID_Y + shakeY + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, t)
```

타워: `art.drawTower(tw.def.id, ..., t, tw.justFired)` — justFired는 play가 프레임 간 `tw.cd` 증가(발사 직후 cd가 커짐)로 감지해 0.1초 유지하는 뷰 상태 (fx 테이블에 타워별 타이머). 크래시/disabled 타워는 `love.graphics.setColor(0.5,0.5,0.5)` 틴트 후 그리기 + 크래시 중 매 0.15초 `particles.spawn("smoke", ...)`. 적: `art.drawEnemy(e.def.id, ..., t, hitFlash)` — hitFlash는 프레임 간 hp 감소 감지 0.08초. HP바 유지. 총알: 기존 원 + 글로우(같은 위치에 알파 0.3·크기 2배 원 먼저) — 차지 총알(size>4)은 마젠타 글로우.

- [ ] **Step 3: frame-diff 이펙트 발동** — play:update 마지막에:

```lua
local fx = self.fx
-- 적 사망/도달 감지
local now = {}
for _, e in ipairs(b.enemies) do now[e.id] = { x = e.x, y = e.y, reward = e.def.reward or 0 } end
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
-- 설치 감지
if #b.towers > fx.prevTowerCount then
    local tw = b.towers[#b.towers]
    particles.spawn("flash", tw.x, tw.y, { color = art.pal.cyan })
end
fx.prevTowerCount = #b.towers
fx.shake = math.max(0, fx.shake - dt)
fx.redFlash = math.max(0, fx.redFlash - dt)
particles.update(dt)
```

주의: 사망/도달 구분이 완벽할 필요 없음(같은 프레임에 사망+도달 혼재 시 근사 허용) — 뷰 전용. draw에서 `shakeX = fx.shake > 0 and math.sin(love.timer.getTime() * 60) * 3 or 0`, `shakeY` 코사인 동일, 파티클은 `particles.draw(GRID_X + shakeX, GRID_Y + shakeY)`, redFlash는 화면 가장자리 빨간 사각 테두리(알파 = fx.redFlash*2, 두께 6px).

- [ ] **Step 4: IDE 패널** — 에디터 뒤에 패널 사각형(art.pal.panel) + 상단 타이틀바(panelLight, 높이 22px)에 "script.lua" 텍스트 + 우측에 개발자 아바타 자리 예약(Task 5에서 drawDev 연결). 파스텔 배경 대비 확인.

- [ ] **Step 5: 검증** — 전체 스위트 141+ 무손상 (play는 테스트 대상 아님 — battle 코어 불변 확인이 핵심), 부팅 스모크, 스크린샷 하네스로 전투 화면 캡처(적·타워·파티클 발동 장면) → Read로 확인.

- [ ] **Step 6: Commit** `codedefense: 전투 화면 비주얼·이펙트 적용`

---

### Task 5: 인트로 컷신 + 타이틀 메뉴 + 여운 문구 + 아바타

**Files:**
- Create: `love2d-codedefense/states/intro.lua`
- Modify: `love2d-codedefense/src/art.lua` (인트로 장면 4종 일러스트 헬퍼 추가), `love2d-codedefense/main.lua`, `states/title.lua`, `states/result.lua`, `states/stageselect.lua`, `states/play.lua` (아바타)

**Interfaces:**
- Consumes: Cutscene, art.drawDev/drawLogo/pal, progress.intro_seen
- Produces: `art.drawIntroScene(n, t)` (n=1..4, 960×420 영역 0,0 기준 — 뷰가 translate), `intro:enter(prev, d, p, returnTo)` — returnTo="title"이면 종료 후 타이틀로 (세계관 메뉴 재생용)

- [ ] **Step 1: 인트로 장면 일러스트 4종** (art.lua에 추가 — 프리미티브 조합 씬, 각각 별도 로컬 함수):
  1. 지상: 밝은 하늘 그라데이션(사각형 밴드 3단), 건물 실루엣, 인도 위 사람 3명(단순 픽셀 인물, 폰 든 손), 폰 화면 발광 도트, 말풍선 하트/느낌표
  2. 서버실: 어두운 배경, 서버랙 6대(art.drawWall 재사용 확대), 구석 책상+모니터 발광 원뿔(알파 다각형)+drawDev("idle") 확대, 벽시계 "3:00"
  3. 장애: 2번 구도 재사용 + 모니터/랙 LED 전부 red로, 랙 사이에서 drawEnemy("bug"/"null-ptr") 6마리, 화면 상단 알림 박스 3개(red 테두리 + "!" )
  4. 결의: drawDev("typing") 대형(scale 6) 클로즈업 + 키보드, 배경 어둡게, 커서 깜빡임 사각형(t 기반)
- [ ] **Step 2: states/intro.lua** — Cutscene({4장면 텍스트 — 설계서 4.1 문구 그대로}) + 하단 텍스트 박스(타이프라이터 = cs:visibleText()), Enter→cs:press(), ESC→cs:skip(), `cs:done()`이면: returnTo=="title"→타이틀로, 아니면(첫 실행) `p.intro_seen = true; progress.save(p)` 후 타이틀로. 하단 안내 "Enter 다음 · ESC 건너뛰기".
- [ ] **Step 3: main.lua 분기** — `p.intro_seen`이 아니면 `Gamestate.switch(intro, d, p)` 아니면 title.
- [ ] **Step 4: 타이틀 개편** — 배경: bg + 서버랙 실루엣 열 + 책상 앞 개발자 뒷모습(drawDev 변형 불필요 — 후드 뒷모습은 사각 조합으로 직접) + drawLogo. 메뉴 3항목 `게임 시작 / 세계관 / 종료` (↑↓+Enter, 선택 항목 green 하이라이트+`>` 커서). "세계관" → `Gamestate.switch(intro, d, p, "title")`.
- [ ] **Step 5: 여운 문구·톤** — result에 클리어/패배 여운 문구(Global Constraints 문구 그대로, fonts.small, 기존 안내 위) + 배경 art.pal.bg + 패널. stageselect도 bg/패널/하이라이트 색만 팔레트로.
- [ ] **Step 6: 아바타 연결** — play IDE 타이틀바 우측에 `art.drawDev(fx.devAnim.pose, ...)`: save 성공 시 pose="typing" 1초, 크래시 전이 감지 시 pose="alarm" 1초, 그 외 idle. (크래시 전이는 fx.prevCrashed 테이블로 감지.)
- [ ] **Step 7: 검증** — 스위트 무손상 + 부팅 스모크 + 스크린샷: 인트로 4장면·타이틀·결과 화면 캡처 → Read로 확인. progress 초기화 상태에서 인트로 자동 재생 → 타이틀 흐름 확인 (하네스는 별도 identity).
- [ ] **Step 8: Commit** `codedefense: 인트로 컷신·타이틀 메뉴·세계관 연출`

---

### Task 6: 문서 갱신 + 최종 검증

**Files:**
- Modify: `love2d-codedefense/CLAUDE.md`, `love2d-codedefense/README.md`

- [ ] **Step 1: 문서** — 구조에 art/particles/cutscene/intro 추가, 아트 규칙(코드 생성·팔레트 상수·코어 불변 원칙·파티클 상한 400), 조작에 인트로/타이틀 메뉴(↑↓ Enter, 세계관), README에 세계관 소개 문단 + 스크린샷 설명.
- [ ] **Step 2: 최종 검증** — 전체 스위트 (141+신규 전부), 부팅 스모크, 인트로→타이틀→스테이지1 튜토리얼 흐름 스크린샷 재확인.
- [ ] **Step 3: Commit** `codedefense: 비주얼·세계관 문서화`

---

## Self-Review 결과

- **스펙 커버리지**: §2 아트(Task 3·4), §3 캐릭터(Task 3 스프라이트, Task 5 등장 3지점), §4 세계관(Task 2 로직+Task 5), §5 이펙트(Task 1·4), §6 아키텍처(전 태스크), §7 테스트(각 태스크 + Task 6). 사운드·외부 도구는 스펙 제외 그대로.
- **플레이스홀더**: 아트 에셋은 dot 기법 완성 예시 2종 + 에셋별 형태 명세로 정의 — 창작물 특성상 최종 판정은 스크린샷 Read 검증(각 태스크에 의무화)이 담당.
- **타입 일관성**: art.draw* 시그니처가 Task 3 정의 = Task 4·5 사용 일치. Cutscene 메서드 = intro 사용 일치. particles 시그니처 = Task 4 사용 일치. fx.devAnim은 Task 4 정의 → Task 5 재사용.
