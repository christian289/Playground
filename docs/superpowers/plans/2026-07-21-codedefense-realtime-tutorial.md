# codedefense 실시간 코딩 개편 + 튜토리얼 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 준비 단계를 없애고 "카운트다운 → 멈추지 않는 전투 중 실시간 코딩(F5 저장 즉시 반영), `build()`가 유일한 설치 수단"으로 코어 루프를 개편하고, 스테이지 1~4에 단계별 가이드 오버레이 튜토리얼을 얹는다.

**Architecture:** 렌더링 없는 `src/battle.lua` 시뮬 코어에 스크립트 런타임(`setScript`/`buildTower`/돈 경제/카운트다운)을 넣고, prep/battle 두 상태를 단일 `states/play.lua`(전장 좌 + 에디터 우 상시 표시)로 대체한다. 튜토리얼은 `src/tutorial.lua` 위젯 + `data/curriculum/tutorial_N.lua` 데이터로 play 상태에 최소 침습 통합.

**Tech Stack:** LÖVE 11.5 (LuaJIT), 기존 모듈(classic, hump, csv/db/grid/sandbox/api/editor/progress) 재사용. 신규 외부 의존성 없음.

**Specs:**
- `docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md` (4.1/5.1 개정판)
- `docs/superpowers/specs/2026-07-21-codedefense-tutorial-design.md`

## Global Constraints

- **게임은 절대 멈추지 않는다** — 준비 단계/pause_at 없음. 카운트다운(스테이지별, 기본 15초) 후 타임라인 진행, 총 300초 생존 = 클리어
- **코드가 타워를 설치하는 유일한 수단** — `build(type, r, c, name)` 멱등(같은 이름 존재 시 no-op). 커서/B 건설 UI 삭제
- **F5 = 저장·즉시 반영** — 최상위 재실행으로 build 반영 + on_tick 교체. 문법 오류 시 기존 코드 유지 + 한글 오류 표시
- **돈**: 시작 예산 + 적 처치 보상(enemies.csv reward) 누적. 설치 실패(잔액/벽/중복/테크)는 전투 로그에 한글 표시
- 버튼 구간(스테이지 1~2): 버튼 = 코드를 에디터에 자동 타이핑 + 자동 저장하는 생성기. 이 구간 에디터는 직접 편집 불가
- 배속은 **Ctrl+1/2/4** (에디터 숫자 입력과 충돌 방지). ESC 뒤로. Tab/그리드 커서/B/T/Space 키 삭제
- 튜토리얼: Enter 진행 / X 스킵, `progress.tutorial_done[stageId]` 저장, 안내 중에도 게임 시간은 흐름, ESC는 항상 통과
- 유저 대면 텍스트 전부 한글, 결정론(랜덤 금지), lib/ 수정 금지, 데이터 주도(CSV+커리큘럼 파일)
- 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` 전체 통과 유지 (배시 안 됨 — PowerShell)
- 커밋은 태스크마다, 브랜치 `feature/codedefense-tutorial`
- 스크립트 env는 전투당 하나(공유) — cache는 타워 간 공유 저장소가 됨 (그 자체로 "공유 캐시" 교육 소재)

## File Structure

```
변경:  src/battle.lua        ← +money/countdown/buildTower/setScript, -placements/pause/recompileTowers
변경:  src/api.lua           ← buildEnv(battle) 재작성 (build/아이템 API), refresh/snapshot 유지, +plainSnapshot
변경:  src/db.lua            ← stages 숫자 필드 countdown, validate에 tutorial/buttons 파일 검사
변경:  src/progress.lua      ← tutorial_done 기본값 보강
신규:  states/play.lua       ← 전장+에디터 동시 화면, F5 저장, 버튼 오토타이핑, 힌트바, 튜토리얼 훅
삭제:  states/prep.lua, states/battle.lua
변경:  main.lua              ← 상태 연결은 stageselect→play (stageselect.lua 한 줄 변경)
신규:  src/tutorial.lua      ← 말풍선/하이라이트/허용 키/진행 위젯
변경:  data/stages.csv       ← pause_at→countdown, +tutorial_file,+buttons_file
신규:  data/curriculum/buttons_1.lua, buttons_2.lua, tutorial_1.lua ~ tutorial_4.lua
변경:  data/curriculum/*_solution.lua, *_hints.lua ← build() 포함 통합 스크립트로
변경:  tests/test_battle.lua ← setScript 모델로 전면 재작성
변경:  tests/test_data.lua   ← countdown/신규 열 검증
신규:  tests/test_tutorial.lua
변경:  tests/main.lua        ← suites에 "test_tutorial" 추가
변경:  CLAUDE.md, README.md  ← 새 조작·규칙
```

---

### Task 1: 데이터 스키마 개편 (countdown·tutorial_file·buttons_file)

**Files:**
- Modify: `love2d-codedefense/data/stages.csv`, `love2d-codedefense/src/db.lua`, `love2d-codedefense/tests/test_data.lua`, `love2d-codedefense/tests/fixtures/baddata/data/stages.csv`

**Interfaces:**
- Produces: `d.stages[id].countdown`(number), `.tutorial_file`/`.buttons_file`(string, 빈 값 ""). validate()가 두 파일 열의 실재를 검사(빈 값은 스킵). 이후 태스크는 이 필드명을 그대로 쓴다.

- [ ] **Step 1: stages.csv 교체** — 헤더에서 `pause_at` 제거, `countdown,tutorial_file,buttons_file` 추가. 튜토리얼/버튼 파일은 Task 4·5에서 생성되므로 **이 시점에는 빈 값**으로 둔다 (validate가 빈 값을 스킵하므로 안전):

```csv
id,mode,concept,ui,maze_file,budget,languages,countdown,wave_clock,hints_file,solution_file,reward_item,tutorial_file,buttons_file
1,normal,첫 타워,button,mazes/001.txt,200,lua,20,,,curriculum/001_solution.lua,,,
2,normal,전략 바꾸기,button,mazes/002.txt,200,lua,15,,,curriculum/002_solution.lua,,,
3,normal,따라 치기,hint,mazes/003.txt,220,lua,25,,curriculum/003_hints.lua,curriculum/003_solution.lua,,,
4,normal,빈칸 채우기,hint,mazes/004.txt,220,lua,25,,curriculum/004_hints.lua,curriculum/004_solution.lua,cache,,
5,normal,변수,free,mazes/005.txt,240,lua,25,,curriculum/005_hints.lua,curriculum/005_solution.lua,,,
6,normal,조건문,free,mazes/006.txt,260,lua,25,,curriculum/006_hints.lua,curriculum/006_solution.lua,webhook,,
7,normal,반복문,free,mazes/007.txt,280,lua,25,,curriculum/007_hints.lua,curriculum/007_solution.lua,,,
8,normal,함수,free,mazes/008.txt,300,lua,30,,curriculum/008_hints.lua,curriculum/008_solution.lua,,,
```

baddata 픽스처의 stages.csv도 같은 헤더로 갱신 (기존 두 행에 `,15,,`류 값 보정 — 기존 오류 유발 구성은 유지).

- [ ] **Step 2: 실패하는 테스트** — `tests/test_data.lua`에서 `pause_at` 관련 assert를 삭제하고 추가:

```lua
    t.eq(d.stages[1].countdown, 20, "countdown 숫자 변환")
    t.eq(d.stages[1].tutorial_file, "", "tutorial_file 빈 값")
    t.eq(d.stages[1].buttons_file, "", "buttons_file 빈 값")
```

또한 baddata에 없는 파일을 참조하는 검사용으로, 픽스처 stages.csv 첫 행의 `tutorial_file` 셀에 `curriculum/none.lua`를 넣고:

```lua
    t.ok(table.concat(baderrs, "/"):find("튜토리얼"), "없는 tutorial_file 감지")
```

- [ ] **Step 3: 실패 확인** — 실행 시 countdown nil 등으로 FAIL 확인

- [ ] **Step 4: db.lua 수정** — `index(... {"budget","wave_clock"})` → `{"budget","wave_clock","countdown"}`. stages 후처리에서 pause_at 리스트 변환 블록 삭제. validate()에 추가:

```lua
        for id, s in pairs(d.stages) do
            if s.tutorial_file ~= "" and not fileExists(s.tutorial_file) then
                errs[#errs + 1] = ("stages %s: 튜토리얼 파일 없음 %s"):format(id, s.tutorial_file)
            end
            if s.buttons_file ~= "" and not fileExists(s.buttons_file) then
                errs[#errs + 1] = ("stages %s: 버튼 파일 없음 %s"):format(id, s.buttons_file)
            end
        end
```

(참고: 이 시점에 test_battle이 pause_at을 참조해 깨질 수 있음 — Task 2에서 전면 재작성하므로, 이 태스크에서는 test_battle의 pause 자동 재개 줄(`if b.status == "prep" then b:start() end`)은 그대로 두어도 무해. 스위트가 깨지면 원인이 pause_at 삭제인지 확인하고 해당 참조만 임시 제거.)

- [ ] **Step 5: 통과 확인** → **Step 6: Commit** `codedefense: 스테이지 스키마 countdown·tutorial·buttons 열`

---

### Task 2: Battle 코어 개편 — 스크립트 런타임

**Files:**
- Modify: `love2d-codedefense/src/battle.lua`, `love2d-codedefense/src/api.lua`, `love2d-codedefense/tests/test_battle.lua`

**Interfaces:**
- Consumes: sandbox.compile/call, grid, db (Task 1의 countdown)
- Produces (이후 태스크가 그대로 사용):
  - `Battle(d, stageId, opts)` — opts = `{ items = {"cache","webhook"} }` (보유 아이템). **placements 파라미터 삭제**
  - `battle.money`(현재 잔액), `battle.clock`(카운트다운 동안 음수), `battle.countdown`
  - `battle:buildTower(typeId, r, c, name) → ok, err한글` — 멱등(이름 존재 시 true, no-op)
  - `battle:setScript(code) → ok, err한글` — 성공 시 env 교체+타워 크래시 리셋, 실패 시 기존 유지
  - `battle.script`(현재 적용된 코드 문자열), `battle.scriptError`(마지막 저장 실패 메시지 또는 nil)
  - on_spawn 계약: **`fn(enemySnapshot)`** — snapshot은 `{id,hp,max_hp,x,y,speed,type}` (dist 없음). 오류는 로그만
  - `api.buildEnv(battle) → env`, `api.plainSnapshot(e)`, `api.refresh(env, tower, enemies)` (기존 유지)

- [ ] **Step 1: test_battle.lua 전면 재작성** — placements/pause 기반 테스트 전부 삭제하고 아래로 교체. `readSolution`은 유지하되 회귀 루프는 Task 4에서 갱신하므로 **이 태스크에서는 스테이지 1 단일 회귀만** 남긴다:

```lua
return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local d = db.load(PROJECT_ROOT)

    local ATK = [[
build("printer", 3, 10, "a")
build("printer", 11, 3, "b")
function on_tick(self, world)
  self:attack(world.nearest())
end
]]

    local function run(b, seconds)
        local dt = 1 / 30
        for _ = 1, math.floor(seconds / dt) do
            if b.status ~= "running" then break end
            b:update(dt)
        end
        return b
    end

    -- 스크립트 없이 방치 → 패배
    local b0 = Battle(d, 1, {})
    b0:start()
    run(b0, 400)
    t.eq(b0.status, "defeat", "무방비 시 패배")

    -- 카운트다운: clock<0 동안 스폰 없음
    local bc = Battle(d, 1, {})
    bc:start()
    t.ok(bc.clock < 0, "카운트다운 동안 clock 음수")
    run(bc, d.stages[1].countdown - 2)
    t.eq(#bc.enemies, 0, "카운트다운 동안 스폰 없음")

    -- 정답 스크립트 → 클리어 (스테이지 1)
    local b1 = Battle(d, 1, {})
    t.ok(b1:setScript(ATK), "setScript 성공")
    b1:start()
    run(b1, 400)
    t.eq(b1.status, "clear", "스테이지1 스크립트 클리어")

    -- build 멱등: 같은 스크립트 재저장해도 타워 수/돈 불변
    local b2 = Battle(d, 1, {})
    b2:setScript(ATK)
    local n, m = #b2.towers, b2.money
    t.ok(b2:setScript(ATK), "재저장 성공")
    t.eq(#b2.towers, n, "멱등: 타워 수 불변")
    t.eq(b2.money, m, "멱등: 돈 불변")

    -- 예산 부족: 3번째 설치 실패, 로그에 예산
    local b3 = Battle(d, 1, {})
    b3:setScript(ATK .. '\nbuild("printer", 7, 3, "c")')
    t.eq(#b3.towers, 2, "예산 부족 설치 실패")
    t.ok(table.concat(b3.log, "/"):find("예산"), "예산 부족 로그")

    -- 킬 보상: 클리어한 b1의 돈이 (시작예산-설치비)보다 큼
    t.ok(b1.money > d.stages[1].budget - 200, "처치 보상 누적")

    -- 문법 오류 저장 → 기존 코드 유지
    local b4 = Battle(d, 1, {})
    b4:setScript(ATK)
    local ok4, err4 = b4:setScript("function on_tick( broken")
    t.ok(not ok4 and err4 ~= nil, "문법 오류 저장 거부")
    t.ok(b4.env ~= nil and b4.env.on_tick ~= nil, "기존 on_tick 유지")

    -- 테크 의존성: compiler 없이 sniper → 실패 로그, compiler 후 성공
    local b5 = Battle(d, 1, {})
    b5:setScript('build("sniper", 3, 10, "s")')
    t.eq(#b5.towers, 0, "테크 미충족 설치 실패")
    b5:setScript('build("compiler", 3, 10, "c")\nbuild("sniper", 11, 3, "s")')
    t.eq(#b5.towers, 2, "컴파일러 후 스나이퍼 설치")

    -- 장애 격리: 이름 분기 오류는 그 타워만 크래시
    local b6 = Battle(d, 1, {})
    b6:setScript(ATK .. [[

function on_tick(self, world)
  if self.name == "a" then local x = nil; return x.y end
  self:attack(world.nearest())
end
]])
    b6:start()
    run(b6, 2)
    local a6 = nil
    for _, tw in ipairs(b6.towers) do if tw.name == "a" then a6 = tw end end
    t.ok(a6.crashed > 0 or a6.disabled, "a 타워만 크래시")

    -- 아이템 게이팅: cache는 opts.items에 있을 때만
    local CACHE = 'build("printer", 3, 10, "a")\nfunction on_tick(self, world)\n  cache.set("n", (cache.get("n") or 0) + 1)\nend'
    local b7 = Battle(d, 1, { items = { "cache" } })
    t.ok(b7:setScript(CACHE), "cache 장착 시 컴파일")
    b7:start()
    run(b7, 1)
    local a7 = b7.towers[1]
    t.eq(a7.crashed, 0, "cache 사용 정상")
    local b8 = Battle(d, 1, {})
    b8:setScript(CACHE)
    b8:start()
    run(b8, 1)
    t.ok(b8.towers[1].crashed > 0, "cache 미보유 시 크래시")

    -- on_spawn: fn(enemy) 계약, cache에 기록
    local HOOK = [[
build("printer", 3, 10, "a")
on_spawn(function(e)
  cache.set("last", e.type)
end)
function on_tick(self, world) self:attack(world.nearest()) end
]]
    local b9 = Battle(d, 1, { items = { "cache", "webhook" } })
    t.ok(b9:setScript(HOOK), "webhook 스크립트 컴파일")
    b9:start()
    run(b9, d.stages[1].countdown + 10)
    t.eq(b9.env.cache.get("last"), "bug", "on_spawn이 적 스냅샷 수신")
end
```

- [ ] **Step 2: 실패 확인** — `setScript` 미정의로 FAIL

- [ ] **Step 3: api.lua 재작성** — `buildEnv(tower, itemsById)` → `buildEnv(battle)`:

```lua
local sandbox = require("src.sandbox")
local api = {}

local function snapshot(e, tower)
    local dx, dy = e.x - tower.x, e.y - tower.y
    return { id = e.id, hp = e.hp, max_hp = e.max_hp, x = e.x, y = e.y,
        speed = e.def.speed, type = e.def.id, dist = math.sqrt(dx * dx + dy * dy) }
end

function api.plainSnapshot(e)
    return { id = e.id, hp = e.hp, max_hp = e.max_hp, x = e.x, y = e.y,
        speed = e.def.speed, type = e.def.id }
end

-- 전투당 하나의 스크립트 env. build/아이템 API 노출
function api.buildEnv(battle)
    local env = sandbox.baseEnv()
    env.build = function(typeId, r, c, name)
        local ok, err = battle:buildTower(typeId, r, c, name)
        if not ok then battle:say("[설치 실패] " .. tostring(err)) end
        return ok
    end
    for _, it in ipairs(battle.items) do
        if it == "cache" then
            local store = {}
            env.cache = { get = function(k) return store[k] end,
                          set = function(k, v) store[k] = v end }
        elseif it == "webhook" then
            env.on_spawn = function(fn)
                if type(fn) == "function" then env._spawnFn = fn end
            end
        end
    end
    local selfApi = {}
    function selfApi.attack(s, target)
        if type(target) == "table" and target.id and env._tower then
            env._tower.pendingTarget = target.id
        end
    end
    env._selfApi = selfApi
    return env
end

-- 틱 직전: env.self/world를 현재 타워 기준으로 갱신
function api.refresh(env, tower, enemies)
    local snaps = {}
    for _, e in ipairs(enemies) do
        if not e.dead and not e.reached then snaps[#snaps + 1] = snapshot(e, tower) end
    end
    table.sort(snaps, function(a, b) return a.dist < b.dist end)
    local world = {}
    function world.enemies() return snaps end
    function world.nearest() return snaps[1] end
    function world.weakest()
        local best
        for _, s in ipairs(snaps) do if not best or s.hp < best.hp then best = s end end
        return best
    end
    function world.fastest()
        local best
        for _, s in ipairs(snaps) do if not best or s.speed > best.speed then best = s end end
        return best
    end
    env.world = world
    env._tower = tower
    local selfApi = env._selfApi
    selfApi.name = tower.name
    selfApi.x, selfApi.y = tower.x, tower.y
    selfApi.range, selfApi.damage = tower.def.range, tower.def.damage
    selfApi.charge, selfApi.overclock = tower.charge, tower.overclock
    selfApi.ready = tower.cd <= 0
    env.self = selfApi
    return selfApi, world
end

return api
```

- [ ] **Step 4: battle.lua 개편** — 기존 파일에서 다음을 수행. **삭제**: placements 처리 전체, pause_at/pauseIdx, `recompileTowers`, 기존 스폰 시 per-tower handler 블록. **유지**: TICK/BUDGET/TOTAL/WATCHDOG/CHARGE_MAX 상수, 워치독 백오프(disabled), resolveAttack, 오버클럭/차지, split/crash_tower 능력, 정리 루프. **추가/변경**:

```lua
function Battle:new(d, stageId, opts)
    opts = opts or {}
    self.d = d
    self.stage = assert(d.stages[stageId], "없는 스테이지: " .. tostring(stageId))
    self.grid = grid.load(d.root .. "/data/" .. self.stage.maze_file)
    self.timeline = d.timeline(stageId)
    self.spawned = {}
    self.countdown = self.stage.countdown or 15
    self.clock = -self.countdown
    self.tickAcc = 0
    self.serverHP = 10
    self.money = self.stage.budget
    self.items = opts.items or {}
    self.status = "prep"           -- start() 전 상태 (테스트 호환)
    self.enemies, self.towers, self.projectiles, self.log = {}, {}, {}, {}
    self.towersByName = {}
    self.nextEnemyId = 1
    self.env = nil
    self.script = nil
    self.scriptError = nil
end

function Battle:buildTower(typeId, r, c, name)
    if type(name) ~= "string" or name == "" then return false, "타워 이름(4번째 인자)이 필요합니다" end
    if self.towersByName[name] then return true end          -- 멱등
    local def = self.d.towers[typeId]
    if not def then return false, ("없는 타워 종류: %s"):format(tostring(typeId)) end
    if def.requires and def.requires ~= "" then
        local has = false
        for _, tw in ipairs(self.towers) do
            if tw.def.id == def.requires then has = true end
        end
        if not has then
            return false, ("'%s' 건설에는 '%s' 타워가 먼저 필요합니다")
                :format(def.name, self.d.towers[def.requires].name)
        end
    end
    r, c = tonumber(r), tonumber(c)
    if not (r and c and self.grid.build[r] and self.grid.build[r][c]) then
        return false, ("(%s,%s)는 건설칸이 아닙니다"):format(tostring(r), tostring(c))
    end
    for _, tw in ipairs(self.towers) do
        if tw.r == r and tw.c == c then return false, ("(%d,%d)에는 이미 타워가 있습니다"):format(r, c) end
    end
    if self.money < def.cost then
        return false, ("예산 부족: %s는 %d 필요 (잔액 %d)"):format(def.name, def.cost, self.money)
    end
    self.money = self.money - def.cost
    local tw = Tower(def, r, c, {})
    tw.name = name
    self.towersByName[name] = tw
    self.towers[#self.towers + 1] = tw
    self:say(("[설치] %s → \"%s\" (%d,%d)"):format(def.name, name, r, c))
    return true
end

function Battle:setScript(code)
    local env = api.buildEnv(self)
    local compiled, err = sandbox.compile(code, env, "script")
    if not compiled then
        self.scriptError = tostring(err)
        return false, self.scriptError
    end
    self.env = env
    self.script = code
    self.scriptError = nil
    for _, tw in ipairs(self.towers) do
        tw.crashed, tw.disabled, tw.recovering, tw.lastError = 0, nil, nil, nil
    end
    return true
end
```

`update(dt)`: pause 분기 삭제, `self.clock = self.clock + dt` 후 `if self.clock >= 0 then self:spawnFromTimeline() end`. `runTick`: `for _, tw in ipairs(self.towers)` 루프에서 `self.env and self.env.on_tick and tw.crashed <= 0 and not tw.disabled`일 때 `api.refresh(self.env, tw, self.enemies)` + `sandbox.call(self.env.on_tick, BUDGET, self.env.self, self.env.world)`. 스폰 시 on_spawn:

```lua
    if self.env and self.env._spawnFn then
        local snap = api.plainSnapshot(e)
        local ok, herr = sandbox.call(function() self.env._spawnFn(snap) end, BUDGET)
        if not ok then self:say("[웹훅 오류] " .. tostring(herr)) end
    end
```

- [ ] **Step 5: 통과 확인** — test_battle 신규 전 항목 + 기존 스위트(sandbox/grid/csv/data/editor/progress) 통과. 스테이지 1이 ATK 스크립트로 안 깨지면 timelines의 스테이지 1 수치를 미세 조정(결정론 유지)하고 기록.

- [ ] **Step 6: Commit** `codedefense: 전투 코어를 실시간 스크립트 런타임으로 개편`

---

### Task 3: play 상태 — 전장+에디터 동시 화면

**Files:**
- Create: `love2d-codedefense/states/play.lua`
- Delete: `love2d-codedefense/states/prep.lua`, `love2d-codedefense/states/battle.lua`
- Modify: `love2d-codedefense/states/stageselect.lua` (prep→play 한 줄), `love2d-codedefense/states/result.lua` (ctx 필드 확인)

**Interfaces:**
- Consumes: `Battle(d, stageId, {items=p.items})`, `battle:setScript/:start/:update`, `Editor`, `progress`, Task 1의 `stage.ui/buttons_file/tutorial_file`
- Produces: `play:enter(prev, d, stageId, p)`; 클리어/패배 시 `Gamestate.switch(result, status, { d=d, stageId=stageId, p=p })` (result.lua의 기존 시그니처 유지). Task 5가 쓸 훅 지점: `self.tut` nil 필드, `keypressed`/`textinput` 최상단 게이팅 주석, `notify` 지점(`built`/`saved`/`speed_changed`/`gap`)

- [ ] **Step 1: play.lua 작성**

```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")
local Editor = require("src.editor")
local Battle = require("src.battle")
local progress = require("src.progress")

local GRID_X, GRID_Y = 8, 48
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
    self.tut = nil                      -- Task 5에서 튜토리얼 주입
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
end

function play:isButtonStage() return self.stage.ui == "button" end

function play:save()
    local code = self.editor:getText()
    local ok = self.battle:setScript(code)
    if ok then
        self.p.codes[self.stageId] = code
        progress.save(self.p)
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
            at.pos = want
        end
        if at.pos >= #at.target then
            self.autotype = nil
            self.editor:setText(at.target)
            self:save()
        end
    end

    local before = self.battle.clock
    self.battle:update(dt * self.speed)
    -- 웨이브 틈 감지: 화면에 적이 없고 전투 중이면 gap 알림 (튜토리얼용, 1회성은 tutorial이 관리)
    if self.tut and self.battle.clock > 0 and #self.battle.enemies == 0 then
        self.tut:notify("gap")
    end

    if self.battle.status == "clear" or self.battle.status == "defeat" then
        Gamestate.switch(require("states.result"), self.battle.status,
            { d = self.d, stageId = self.stageId, p = self.p })
    end
end

function play:draw()
    local b = self.battle
    -- 상단 바
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    local clockText = b.clock < 0
        and ("전투 시작까지 %d초 — 코드를 준비하세요!"):format(math.ceil(-b.clock))
        or ("%.0f / 300초"):format(b.clock)
    love.graphics.print(("%s   서버 HP %d   잔액 %d   배속 x%d"):format(clockText, b.serverHP, b.money, self.speed), 8, 12)

    -- 전장
    for r = 1, grid.ROWS do
        for c = 1, grid.COLS do
            local x, y = grid.toXY(r, c)
            x, y = x + GRID_X, y + GRID_Y
            if b.grid.build[r][c] then love.graphics.setColor(0.2, 0.3, 0.2)
            elseif b.grid.walls[r][c] then love.graphics.setColor(0.22, 0.24, 0.3)
            else love.graphics.setColor(0.12, 0.13, 0.17) end
            love.graphics.rectangle("fill", x, y, grid.CELL - 1, grid.CELL - 1)
        end
    end
    -- 행·열 좌표 라벨 (코드로 좌표를 지정하므로 상시 표기)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 0.55, 0.6)
    for c = 1, grid.COLS do love.graphics.print(tostring(c), GRID_X + (c - 1) * grid.CELL + 10, GRID_Y - 16) end
    for r = 1, grid.ROWS do love.graphics.print(tostring(r), GRID_X - 6 - fonts.small:getWidth(tostring(r)) + 4, GRID_Y + (r - 1) * grid.CELL + 8) end
    -- 서버라인
    love.graphics.setColor(0.3, 0.7, 1, 0.6)
    love.graphics.rectangle("fill", GRID_X, GRID_Y + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, 4)
    -- 타워/적/총알 (기존 states/battle.lua 렌더 블록 재사용: 색상 파싱, 크래시 라벨, HP바)
    for _, tw in ipairs(b.towers) do
        local rgb = {}
        for v in tw.def.color:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        if tw.crashed > 0 or tw.disabled then love.graphics.setColor(0.4, 0.4, 0.4)
        else love.graphics.setColor(rgb[1], rgb[2], rgb[3]) end
        love.graphics.rectangle("fill", GRID_X + tw.x - 12, GRID_Y + tw.y - 12, 24, 24)
        love.graphics.setColor(0.8, 0.85, 0.9)
        love.graphics.print(tw.name or "", GRID_X + tw.x - 10, GRID_Y + tw.y - 26)
    end
    for _, e in ipairs(b.enemies) do
        local rgb = {}
        for v in e.def.color:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        love.graphics.setColor(rgb[1], rgb[2], rgb[3])
        love.graphics.circle("fill", GRID_X + e.x, GRID_Y + e.y, 9)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", GRID_X + e.x - 10, GRID_Y + e.y - 16, 20, 3)
        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.rectangle("fill", GRID_X + e.x - 10, GRID_Y + e.y - 16, 20 * e.hp / e.max_hp, 3)
    end
    love.graphics.setColor(1, 0.95, 0.6)
    for _, pr in ipairs(b.projectiles) do
        love.graphics.circle("fill", GRID_X + pr.x, GRID_Y + pr.y, pr.size)
    end

    -- 에디터 또는 버튼 패널
    if self:isButtonStage() then
        self.editor:draw(fonts, false)
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.95, 0.85, 0.4)
        love.graphics.print("버튼을 누르면 코드가 자동으로 입력·실행됩니다:", 400, 530)
        love.graphics.setFont(fonts.small)
        for i, btn in ipairs(self.buttons) do
            love.graphics.setColor(0.85, 0.88, 0.92)
            love.graphics.print(("[%d] %s"):format(i, btn.label), 400, 550 + (i - 1) * 20)
        end
    else
        self.editor:draw(fonts, true)
    end

    -- 전투 로그 (전장 아래)
    love.graphics.setFont(fonts.small)
    for i, msg in ipairs(b.log) do
        love.graphics.setColor(0.8, 0.82, 0.86, 1 - (#b.log - i) * 0.1)
        love.graphics.print(msg, 8, GRID_Y + grid.ROWS * grid.CELL + 12 + (i - 1) * 18)
    end
    -- 저장 오류
    if b.scriptError then
        love.graphics.setColor(1, 0.45, 0.4)
        love.graphics.printf("저장 실패 — " .. b.scriptError, 400, 545, 552, "left")
    end
    -- 힌트바
    love.graphics.setColor(0.6, 0.65, 0.7)
    local hint = self:isButtonStage()
        and "숫자키 버튼 실행 · Ctrl+1/2/4 배속 · ESC 나가기"
        or "F5 저장·반영 · F1~F4 스니펫 · Ctrl+1/2/4 배속 · ESC 나가기"
    love.graphics.printf(hint, 0, 620, 960, "center")

    if self.tut then self.tut:draw(fonts, GRID_X, GRID_Y) end
end

function play:keypressed(key)
    if self.tut and not self.tut:done() then
        if not self.tut:allows(key) then return end
        self.tut:keypressed(key)
    end
    if key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
        return
    end
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
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
    if self.tut and not self.tut:done() and not self.tut:allowsText() then return end
    if self:isButtonStage() or self.autotype then return end
    self.editor:textinput(ch)
end

return play
```

주의: `self.tut:allowsText()`는 Task 5에서 구현 — 이 태스크에서는 `self.tut`이 항상 nil이므로 호출되지 않는다. `notify("built")`는 Battle:buildTower가 아니라 play:save 성공 후 `#self.battle.towers` 증가를 비교해 호출한다 (save 직전 타워 수 기억 → 증가 시 `self.tut:notify("built")`). save()에 그 3줄을 포함할 것.

- [ ] **Step 2: 상태 연결** — `states/stageselect.lua`의 `Gamestate.switch(require("states.prep"), ...)` → `require("states.play")`. prep.lua/battle.lua 삭제 (`git rm`). result.lua는 ctx 시그니처 동일하므로 무변경 확인만.

- [ ] **Step 3: 검증** — 전체 스위트 통과(상태는 유닛테스트 없음) + 부팅 스모크(6초 타임아웃, 오류 0) + 스크래치패드 헤드리스 상태 체크(states/play.lua require, enter/draw/keypressed/textinput/update 존재 assert).

- [ ] **Step 4: Commit** `codedefense: play 상태 — 전장·에디터 동시 실시간 화면`

---

### Task 4: 스테이지 콘텐츠 갱신 (정답·버튼·힌트·회귀)

**Files:**
- Modify: `data/curriculum/001~008_solution.lua`, `003~008_hints.lua`, `data/stages.csv`(buttons_file 값 채움), `data/timelines.csv`(필요 시 미세 조정), `tests/test_battle.lua`(회귀 루프)
- Create: `data/curriculum/buttons_1.lua`, `data/curriculum/buttons_2.lua`

**Interfaces:**
- Consumes: Task 2의 setScript 회귀 방식, 기존 검증 좌표 (교체 전 tests/test_battle.lua의 배치 표를 먼저 읽어 스테이지별 좌표를 확보할 것: 1=(3,10),(11,3) 등)
- Produces: 전 정답이 `build(...)` 포함 통합 스크립트; buttons 파일 형식 `return { { label = "...", script = "..." }, ... }`

- [ ] **Step 1: 정답 갱신** — 각 스테이지 정답 상단에 기존 검증 좌표의 build 줄 추가 (개수 = floor(budget/100), 스테이지 8은 3기). 예: `001_solution.lua`:

```lua
-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 10, "a")
build("printer", 11, 3, "b")

function on_tick(self, world)
  self:attack(world.nearest())
end
```

002~008도 동일 패턴 (기존 on_tick 로직·한글 주석 유지, build 줄만 얹음). 힌트 파일도 build 줄이 이미 포함된 형태로 갱신 (3: 전체 따라치기 대상에 build 포함, 4~8: build 줄은 완성 제공 + 기존 빈칸 유지).

- [ ] **Step 2: 버튼 파일 작성** — `buttons_1.lua`:

```lua
-- 스테이지 1 버튼: 누르면 이 스크립트가 에디터에 자동 타이핑된 뒤 저장된다
return {
  { label = "프린터 설치 (3,10)", script = 'build("printer", 3, 10, "a")\n\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend\n' },
  { label = "프린터 추가 (11,3)", script = 'build("printer", 3, 10, "a")\nbuild("printer", 11, 3, "b")\n\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend\n' },
}
```

`buttons_2.lua`: 위 2버튼 + 3번 버튼 "전략: 약한 적 우선" (`world.weakest()` 버전 전체 스크립트). stages.csv의 1·2행 `buttons_file` 셀에 경로 기입.

- [ ] **Step 3: 회귀 루프 교체** — test_battle.lua 끝에:

```lua
    -- 전 스테이지 정답 회귀 (그 시점 보유 아이템으로)
    local owned = {}
    for stageId = 1, 8 do
        local sol = readSolution(stageId)
        local b = Battle(d, stageId, { items = owned })
        t.ok(b:setScript(sol), ("스테이지 %d 정답 컴파일"):format(stageId))
        b:start()
        run(b, 420)
        t.eq(b.status, "clear", ("스테이지 %d 정답 클리어"):format(stageId))
        local reward = d.stages[stageId].reward_item
        if reward ~= "" then owned[#owned + 1] = reward end
    end
```

- [ ] **Step 4: 실행·밸런스** — 전 스테이지 클리어까지 timelines 수치만 조정 (결정론 유지, count=0 금지, 스폰 열 규칙 준수). 조정 내역 기록.

- [ ] **Step 5: 수동 플레이** — 스테이지 1(버튼)과 3(따라치기)을 실제 부팅해 확인.

- [ ] **Step 6: Commit** `codedefense: 스테이지 콘텐츠를 통합 스크립트로 갱신`

---

### Task 5: 튜토리얼 모듈 + 데이터 + 통합

**Files:**
- Create: `src/tutorial.lua`, `data/curriculum/tutorial_1.lua`~`tutorial_4.lua`, `tests/test_tutorial.lua`
- Modify: `states/play.lua`(주입·notify), `src/progress.lua`(tutorial_done 보강), `data/stages.csv`(tutorial_file 채움), `tests/main.lua`(suites)

**Interfaces:**
- Consumes: 튜토리얼 설계서 4.1의 스텝 스키마·메서드 계약 (그 문서가 스키마의 원본)
- Produces: `Tutorial.load(path) → tut|nil` (io.open+loadstring, 실패 시 nil+콘솔 경고), `tut:allows(key)`, `tut:allowsText()`, `tut:keypressed(key)`, `tut:notify(event)`, `tut:draw(fonts, gx, gy)`, `tut:done()`, `tut.skipped`

- [ ] **Step 1: 실패하는 테스트** — `tests/test_tutorial.lua`:

```lua
return function(t)
    local Tutorial = require("src.tutorial")

    local steps = {
        { text = "안내1", advance = { on = "enter" } },
        { text = "버튼", allow = { "1" }, advance = { on = "event", event = "built" } },
        { text = "저장", allow = { "f5", "textinput" }, advance = { on = "key", key = "f5" } },
    }
    local tut = Tutorial(steps)

    t.ok(tut:allows("enter"), "Enter 항상 통과")
    t.ok(tut:allows("escape"), "ESC 항상 통과")
    t.ok(tut:allows("anything"), "allow 없는 스텝은 전부 허용")
    tut:keypressed("return")
    t.ok(tut:allows("1") and not tut:allows("f5"), "allow 게이팅")
    t.ok(not tut:allowsText(), "textinput 토큰 없으면 문자 차단")
    tut:notify("built")
    t.ok(tut:allowsText(), "textinput 토큰 허용")
    tut:keypressed("f5")
    t.ok(tut:done(), "전 스텝 소진")

    local tut2 = Tutorial(steps)
    tut2:keypressed("x")
    t.ok(tut2:done() and tut2.skipped, "X 스킵")

    t.ok(Tutorial.load(PROJECT_ROOT .. "/data/curriculum/tutorial_1.lua") ~= nil, "스텝 파일 로드")
    t.ok(Tutorial.load(PROJECT_ROOT .. "/없는파일.lua") == nil, "없는 파일 nil")
end
```

- [ ] **Step 2: 실패 확인** (suites에 "test_tutorial" 추가 후) → **Step 3: tutorial.lua 구현**

```lua
local Object = require("lib.classic")

local Tutorial = Object:extend()

function Tutorial:new(steps)
    self.steps = steps or {}
    self.idx = 1
    self.skipped = false
end

function Tutorial.load(path)
    local f = io.open(path, "rb")
    if not f then print("[튜토리얼] 파일 없음: " .. path) return nil end
    local src = f:read("*a"); f:close()
    local chunk = loadstring(src)
    if not chunk then print("[튜토리얼] 로드 실패: " .. path) return nil end
    local ok, steps = pcall(chunk)
    if not ok or type(steps) ~= "table" then print("[튜토리얼] 실행 실패: " .. path) return nil end
    return Tutorial(steps)
end

function Tutorial:current() return self.steps[self.idx] end
function Tutorial:done() return self.skipped or self.idx > #self.steps end

function Tutorial:allows(key)
    if self:done() then return true end
    if key == "return" or key == "x" or key == "escape" then return true end
    local step = self:current()
    if not step.allow then return true end
    for _, k in ipairs(step.allow) do if k == key then return true end end
    return false
end

function Tutorial:allowsText()
    if self:done() then return true end
    local step = self:current()
    if not step.allow then return true end
    for _, k in ipairs(step.allow) do if k == "textinput" then return true end end
    return false
end

function Tutorial:advance() self.idx = self.idx + 1 end

function Tutorial:keypressed(key)
    if self:done() then return end
    if key == "x" then self.skipped = true return end
    local adv = self:current().advance
    if key == "return" and adv.on == "enter" then self:advance()
    elseif adv.on == "key" and adv.key == key then self:advance() end
end

function Tutorial:notify(event)
    if self:done() then return end
    local adv = self:current().advance
    if adv.on == "event" and adv.event == event then self:advance() end
end

function Tutorial:draw(fonts, gx, gy)
    if self:done() then return end
    local grid = require("src.grid")
    local step = self:current()
    -- 앵커 하이라이트 (깜빡임)
    local a = step.anchor
    if a and a.type == "cell" and (love.timer.getTime() * 3) % 2 < 1.2 then
        local x, y = grid.toXY(a.r, a.c)
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", gx + x, gy + y, grid.CELL - 1, grid.CELL - 1)
        love.graphics.setLineWidth(1)
    elseif a and a.type == "ui" and a.id == "editor" then
        love.graphics.setColor(1, 0.85, 0.3, 0.8)
        love.graphics.rectangle("line", 398, 46, 556, 474)
    end
    -- 말풍선 (하단 고정)
    love.graphics.setColor(0.1, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", 120, 555, 720, 58, 8)
    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.rectangle("line", 120, 555, 720, 58, 8)
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.92, 0.94, 0.97)
    love.graphics.printf(step.text, 132, 562, 696, "left")
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    local guide = step.advance.on == "enter" and "Enter 다음 · X 건너뛰기" or "X 건너뛰기"
    love.graphics.printf(guide, 132, 596, 690, "right")
end

return Tutorial
```

- [ ] **Step 4: 스텝 데이터 4개 작성** — 튜토리얼 설계서 3장의 시나리오 그대로. 예 `tutorial_1.lua`:

```lua
return {
  { text = "버그들이 위에서 내려와요. 바닥의 파란 서버라인에 닿으면 서버가 다쳐요!",
    anchor = { type = "ui", id = "serverline" }, advance = { on = "enter" } },
  { text = "카운트다운 동안 첫 타워를 준비해요. 이 게임에서 타워는 오직 코드로만 지을 수 있어요.",
    advance = { on = "enter" } },
  { text = "[1] 버튼을 눌러보세요 — 코드가 자동으로 타이핑되고 저장되는 걸 지켜보세요!",
    anchor = { type = "cell", r = 3, c = 10 }, allow = { "1" },
    advance = { on = "event", event = "built" } },
  { text = "예산이 남았어요. [2] 버튼으로 한 기 더!",
    anchor = { type = "cell", r = 11, c = 3 }, allow = { "2" },
    advance = { on = "event", event = "built" } },
  { text = "Ctrl+1/2/4 키로 배속을 조절할 수 있어요.",
    advance = { on = "event", event = "speed_changed" } },
  { text = "적이 잠깐 끊겼어요. 이 틈에 코드를 다듬는 게 이 게임의 리듬이에요.",
    advance = { on = "enter" } },
}
```

tutorial_2(전략 버튼 유도 1스텝), tutorial_3(설계서의 4스텝 — 마지막은 `saved` 이벤트), tutorial_4(2스텝, quickbar 앵커). serverline ui 앵커의 draw 지원은 tutorial.lua의 ui 분기에 `a.id == "serverline"`이면 서버라인 좌표에 테두리 추가 (`gy + 16*32` 위치, 폭 `12*32`). stages.csv 1~4행 `tutorial_file` 셀 기입.

- [ ] **Step 5: play 통합** — play:enter 끝에:

```lua
    if self.stage.tutorial_file ~= "" and not p.tutorial_done[stageId] then
        self.tut = require("src.tutorial").load(d.root .. "/data/" .. self.stage.tutorial_file)
    end
```

update에서 `if self.tut and self.tut:done() and not self.tutSaved then self.tutSaved = true; p.tutorial_done[stageId] = true; progress.save(p) end`. progress.lua load()에 `p.tutorial_done = p.tutorial_done or {}` 보강. (keypressed/textinput 게이팅과 notify 지점은 Task 3에서 이미 배선됨.)

- [ ] **Step 6: 통과 확인** (스위트 + validate가 tutorial_file 실재 검사 통과) → 수동으로 새 저장 상태에서 스테이지 1 튜토리얼 완주 확인 → **Step 7: Commit** `codedefense: 스테이지 1~4 가이드 튜토리얼`

---

### Task 6: 문서 갱신 + 최종 검증

**Files:**
- Modify: `love2d-codedefense/CLAUDE.md`, `love2d-codedefense/README.md`

- [ ] **Step 1: 문서 개정** — 조작 표(F5 저장, Ctrl+1/2/4, 숫자키 버튼, F1~F4, ESC — Tab/B/T/Space 삭제), 코어 루프(카운트다운→실시간→300초 생존), 통합 스크립트 규칙(build 멱등·돈 경제·문법 오류 시 기존 유지), 튜토리얼(Enter/X, 저장됨), 구조(states play/tutorial 반영, prep/battle 삭제), 스테이지 추가 절차에 tutorial_file/buttons_file 포함.
- [ ] **Step 2: 최종 검증** — 전체 스위트 통과 + 부팅 스모크 + 새 저장으로 스테이지 1 수동 완주.
- [ ] **Step 3: Commit** `codedefense: 실시간 개편·튜토리얼 문서화`

---

## Self-Review 결과

- **스펙 커버리지**: 본편 4.1(카운트다운/무정지/F5/5분)·5.1(build 멱등/돈/오류 유지/버튼 생성기/좌표 표기) → Task 1~4. 튜토리얼 설계서 3~6장 → Task 5. 문서 → Task 6. 하드코어·sell·리셋 메뉴는 스펙에서 명시 이연.
- **플레이스홀더**: 코드 블록 전부 실코드. buttons_2·tutorial_2~4는 형식+시나리오 원문(설계서 3장) 참조로 명세 — 설계서가 스텝 텍스트의 원본이므로 이중 기재 생략.
- **타입 일관성**: `Battle(d, stageId, opts)`/`setScript`/`buildTower`/`plainSnapshot`/`Tutorial.load` 시그니처가 Task 2~5에서 동일. play:enter 시그니처가 stageselect 호출과 일치. result ctx 시그니처 기존 유지 확인.
