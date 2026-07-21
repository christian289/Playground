# love2d-codedefense v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 코딩 교육용 타워디펜스 《Code Defense》의 첫 플레이어블 버전 — 플레이어가 Lua 코드로 타워를 조종해 위에서 내려오는 밈 몬스터를 막는 코어 루프 + 표본 스테이지 8개.

**Architecture:** 렌더링 없는 전투 시뮬레이션 코어(`src/battle.lua`)를 중심에 두고 상태(states)는 뷰/입력만 담당한다. 유저 코드는 `setfenv` 샌드박스에서 명령 예산과 함께 실행되며, 게임 데이터는 전부 CSV다. 테스트는 프로젝트 내 `tests/` LÖVE 하네스로 헤드리스 실행한다.

**Tech Stack:** LÖVE 11.5 (LuaJIT), classic(OOP), hump.gamestate, 나눔고딕(한글 UI). 신규 외부 의존성 없음.

**Spec:** `docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md`

## Global Constraints

- 모노레포 규칙: 새 최상위 폴더 `love2d-codedefense/`, 다른 프로젝트 참조 금지 (lib/폰트는 **복사**)
- 그리드 고정 가로 12 × 세로 16칸, 셀 32px (스펙 4.2)
- 일반 모드 전투 시간 총 300초 고정, `pause_at` 시점에 타이머 정지 + 준비 단계 (스펙 4.1)
- 수치 직접 대입 불가 — 코드는 판단만, 성능 변화는 오버클럭/차지샷 경유 (스펙 철학 4, 5.6)
- 스테이지는 결정론적 — 랜덤 스폰 금지 (스펙 철학 2)
- 유저 대면 텍스트는 전부 한글, 폰트는 `assets/fonts/NanumGothic-Regular.ttf` 로드 필수
- 표 데이터는 CSV (`;`로 셀 내 리스트), 다중 행 텍스트는 파일 경로 참조 (스펙 7.2)
- `lib/` 아래 파일 수정 금지
- 실행: 프로젝트 루트에서 `& "C:\Program Files\LOVE\lovec.exe" .` / 테스트: `& "C:\Program Files\LOVE\lovec.exe" tests`
- 커밋은 태스크마다, 브랜치 `feature/love2d-codedefense`
- **0.1 제외 (0.2+)**: 하드코어 모드, 공유 카드, 도감 UI, 진영 선택 UI, 멀티 언어

## File Structure

```
love2d-codedefense/
├─ main.lua              ← 폰트 로드, Gamestate 등록, title로 전환
├─ conf.lua              ← 960x640 창, LÖVE 11.5
├─ src/
│  ├─ csv.lua            ← CSV 파서 (따옴표 필드, ; 리스트)
│  ├─ db.lua             ← data/*.csv 로드 + 참조 무결성 검증
│  ├─ grid.lua           ← 미로 로드, BFS 플로우필드, 좌표 변환
│  ├─ sandbox.lua        ← setfenv 격리 + debug.sethook 명령 예산
│  ├─ api.lua            ← 타워 스크립트 env 구성 (self/world/아이템 해금)
│  ├─ enemy.lua          ← 적 (플로우필드 이동, 능력 태그)
│  ├─ tower.lua          ← 타워 (쿨다운, 오버클럭, 차지)
│  ├─ projectile.lua     ← 총알 (직선 추적, 크기 배율)
│  ├─ battle.lua         ← 전투 시뮬 코어 (타임라인, 10Hz 틱, 승패) — 렌더링 없음
│  ├─ editor.lua         ← 텍스트 에디터 위젯 + 스니펫 퀵바
│  ├─ fonts.lua          ← 나눔고딕 로드
│  └─ progress.lua       ← 저장/로드 (JSON 직렬화 직접 구현 아님 — Lua 직렬화)
├─ states/
│  ├─ title.lua / stageselect.lua / prep.lua / battle.lua / result.lua
├─ data/
│  ├─ towers.csv / enemies.csv / items.csv / stages.csv / timelines.csv
│  ├─ mazes/001.txt ... 008.txt
│  └─ curriculum/  (힌트 템플릿, 정답 코드)
├─ tests/
│  ├─ main.lua           ← 테스트 러너 (suite 로드, PASS/FAIL 출력, 종료코드)
│  ├─ conf.lua
│  └─ test_csv.lua / test_grid.lua / test_sandbox.lua / test_battle.lua / test_data.lua
└─ assets/fonts/NanumGothic-Regular.ttf
```

파일 읽기는 전부 `io.open` + `love.filesystem.getSource()` 기준 절대 경로를 쓴다
(LÖVE 파일시스템 샌드박스 때문에 tests/에서 상위 폴더를 읽으려면 io가 필요).
저장 파일만 `love.filesystem`(유저 폴더)을 쓴다.

---

### Task 1: 프로젝트 스캐폴딩과 부팅

**Files:**
- Create: `love2d-codedefense/conf.lua`, `love2d-codedefense/main.lua`, `love2d-codedefense/src/fonts.lua`
- Copy: `love2d-tetris/lib/classic.lua` → `love2d-codedefense/lib/classic.lua`, `love2d-tetris/lib/hump/` → `love2d-codedefense/lib/hump/`, `love2d-tetris/assets/fonts/NanumGothic-Regular.ttf` → `love2d-codedefense/assets/fonts/`

**Interfaces:**
- Produces: `require("src.fonts")` → `fonts.load()`, `fonts.ui`(18px), `fonts.small`(14px), `fonts.mono`(16px 기본폰트 아님 — 나눔고딕으로 통일), `fonts.big`(32px)

- [ ] **Step 1: 폴더 생성 + lib/폰트 복사**

```bash
cd /c/Users/chris/personal/Playground
mkdir -p love2d-codedefense/src love2d-codedefense/states love2d-codedefense/data/mazes \
  love2d-codedefense/data/curriculum love2d-codedefense/tests love2d-codedefense/assets/fonts love2d-codedefense/lib
cp love2d-tetris/lib/classic.lua love2d-codedefense/lib/
cp -r love2d-tetris/lib/hump love2d-codedefense/lib/
cp love2d-tetris/assets/fonts/NanumGothic-Regular.ttf love2d-codedefense/assets/fonts/
```

- [ ] **Step 2: conf.lua / fonts.lua / main.lua 작성**

`conf.lua`:
```lua
function love.conf(t)
    t.identity = "love2d-codedefense"
    t.version = "11.5"
    t.window.title = "Code Defense"
    t.window.width = 960
    t.window.height = 640
end
```

`src/fonts.lua`:
```lua
local fonts = {}
local PATH = "assets/fonts/NanumGothic-Regular.ttf"

function fonts.load()
    fonts.small = love.graphics.newFont(PATH, 14)
    fonts.ui = love.graphics.newFont(PATH, 18)
    fonts.mono = love.graphics.newFont(PATH, 16)
    fonts.big = love.graphics.newFont(PATH, 32)
end

return fonts
```

`main.lua` (임시 부팅 화면 — Task 9에서 상태 전환으로 교체):
```lua
local fonts = require("src.fonts")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    fonts.load()
end

function love.draw()
    love.graphics.setFont(fonts.big)
    love.graphics.printf("Code Defense 부팅 OK", 0, 300, 960, "center")
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end
```

- [ ] **Step 3: 부팅 확인**

```powershell
& "C:\Program Files\LOVE\lovec.exe" C:\Users\chris\personal\Playground\love2d-codedefense
```
Expected: 창이 뜨고 "Code Defense 부팅 OK" 한글 표시, 콘솔에 오류 없음. ESC로 종료.

- [ ] **Step 4: Commit** — `git add love2d-codedefense && git commit -m "codedefense: 스캐폴딩과 부팅 화면"`

---

### Task 2: 테스트 하네스 + CSV 파서

**Files:**
- Create: `love2d-codedefense/tests/conf.lua`, `love2d-codedefense/tests/main.lua`, `love2d-codedefense/tests/test_csv.lua`, `love2d-codedefense/src/csv.lua`

**Interfaces:**
- Produces: `csv.records(text)` → `{ {헤더명=값,...}, ... }`, `csv.list(cell)` → `;` 분리 배열, `csv.load(path)` → io로 읽어 records 반환. 테스트 러너: 각 `tests/test_*.lua`는 `function(t)`를 반환, `t.eq(actual, expected, label)` / `t.ok(cond, label)` 사용.

- [ ] **Step 1: 테스트 러너 작성**

`tests/conf.lua`:
```lua
function love.conf(t)
    t.version = "11.5"
    t.window = nil          -- 헤드리스
    t.modules.graphics = false
    t.modules.window = false
    t.modules.audio = false
end
```

`tests/main.lua`:
```lua
-- 프로젝트 루트를 package.path에 추가해 src.* 를 require 가능하게 한다
local ROOT = love.filesystem.getSource():gsub("[/\\]tests$", "")
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path
_G.PROJECT_ROOT = ROOT   -- 데이터 파일 io 접근용

local suites = { "test_csv", "test_grid", "test_sandbox", "test_battle", "test_data" }
local pass, fail = 0, 0

local t = {}
function t.ok(cond, label)
    if cond then pass = pass + 1; print("PASS " .. label)
    else fail = fail + 1; print("FAIL " .. label) end
end
function t.eq(a, b, label)
    if a == b then pass = pass + 1; print("PASS " .. label)
    else fail = fail + 1; print(("FAIL %s: got %s, want %s"):format(label, tostring(a), tostring(b))) end
end

function love.load()
    for _, name in ipairs(suites) do
        local path = ROOT .. "/tests/" .. name .. ".lua"
        local f = io.open(path, "rb")
        if f then
            f:close()
            print("== " .. name)
            local chunk = assert(loadfile(path))
            local okRun, err = pcall(chunk(), t)
            if not okRun then fail = fail + 1; print("FAIL (suite error) " .. tostring(err)) end
        end
    end
    print(("RESULT pass=%d fail=%d"):format(pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
end
```

- [ ] **Step 2: 실패하는 CSV 테스트 작성**

`tests/test_csv.lua`:
```lua
return function(t)
    local csv = require("src.csv")

    local recs = csv.records("id,name\n1,버그\n2,널포인터\n")
    t.eq(#recs, 2, "csv 레코드 수")
    t.eq(recs[1].id, "1", "csv 첫 행 id")
    t.eq(recs[2].name, "널포인터", "csv 한글 값")

    local q = csv.records('id,desc\n1,"쉼표, 포함"\n')
    t.eq(q[1].desc, "쉼표, 포함", "csv 따옴표 필드")

    local qq = csv.records('id,desc\n1,"안에 ""따옴표"""\n')
    t.eq(qq[1].desc, '안에 "따옴표"', "csv 이스케이프 따옴표")

    local crlf = csv.records("id,x\r\n1,a\r\n")
    t.eq(crlf[1].x, "a", "csv CRLF")

    t.eq(#csv.list(""), 0, "csv.list 빈 값")
    local l = csv.list("90;180")
    t.eq(l[1], "90", "csv.list 첫 항목")
    t.eq(l[2], "180", "csv.list 둘째 항목")

    local missing = csv.records("a,b,c\n1,2\n")
    t.eq(missing[1].c, "", "csv 모자란 셀은 빈 문자열")
end
```

- [ ] **Step 3: 실패 확인** — `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` → Expected: `module 'src.csv' not found`로 suite error FAIL

- [ ] **Step 4: csv.lua 구현**

`src/csv.lua`:
```lua
local csv = {}

-- 문자 단위 파서: 따옴표 필드, 필드 내 쉼표/줄바꿈/이스케이프("") 지원
function csv.parse(text)
    local rows, row, field = {}, {}, {}
    local i, len, inq = 1, #text, false
    while i <= len do
        local c = text:sub(i, i)
        if inq then
            if c == '"' then
                if text:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1
                else inq = false end
            else field[#field + 1] = c end
        elseif c == '"' then inq = true
        elseif c == ',' then row[#row + 1] = table.concat(field); field = {}
        elseif c == '\n' then
            row[#row + 1] = table.concat(field); field = {}
            rows[#rows + 1] = row; row = {}
        elseif c ~= '\r' then field[#field + 1] = c end
        i = i + 1
    end
    if #field > 0 or #row > 0 then
        row[#row + 1] = table.concat(field)
        rows[#rows + 1] = row
    end
    return rows
end

-- 첫 행을 헤더로 쓰는 레코드 배열. 모자란 셀은 ""
function csv.records(text)
    local rows = csv.parse(text)
    local header = table.remove(rows, 1) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local rec = {}
        for ci, name in ipairs(header) do rec[name] = r[ci] or "" end
        out[#out + 1] = rec
    end
    return out
end

-- "90;180" → {"90","180"} / "" → {}
function csv.list(cell)
    local out = {}
    for item in tostring(cell or ""):gmatch("[^;]+") do out[#out + 1] = item end
    return out
end

function csv.load(path)
    local f = assert(io.open(path, "rb"), "CSV 파일을 열 수 없음: " .. path)
    local text = f:read("*a")
    f:close()
    return csv.records(text)
end

return csv
```

- [ ] **Step 5: 통과 확인** — 같은 명령 재실행, Expected: `RESULT pass=10 fail=0`

- [ ] **Step 6: Commit** — `git add love2d-codedefense/tests love2d-codedefense/src/csv.lua && git commit -m "codedefense: 테스트 하네스와 CSV 파서"`

---

### Task 3: 게임 데이터 CSV + db 로더 + 무결성 검사

**Files:**
- Create: `data/towers.csv`, `data/enemies.csv`, `data/items.csv`, `data/stages.csv`, `data/timelines.csv`, `src/db.lua`, `tests/test_data.lua`
- (스테이지 상세 행·미로·커리큘럼 파일은 Task 10에서 채운다 — 여기서는 스키마와 스테이지 1개)

**Interfaces:**
- Produces: `db.load(root)` → `{ towers={id→rec}, enemies={id→rec}, items={id→rec}, stages={id→rec}, timeline(stageId)→정렬된 이벤트 배열, validate()→오류배열 }`. 숫자 필드는 로드 시 `tonumber` 변환: towers(cost,damage,range,cooldown,bullet_speed), enemies(hp,speed,reward), stages(budget,wave_clock), timelines(at,count,interval,col).

- [ ] **Step 1: 초기 CSV 작성**

`data/towers.csv` — `requires`가 테크 의존성 (스펙 4.3):
```csv
id,name,cost,damage,range,cooldown,bullet_speed,requires,color,desc
printer,프린터,100,10,120,1.0,300,,0.3;0.8;0.4,기본 발사기. print()가 그렇듯 어디서나 쓴다
compiler,컴파일러,150,0,0,0,0,,0.8;0.7;0.3,공격하지 않는 테크 타워. 고급 타워 건설을 해금한다
sniper,스나이퍼,220,40,240,2.5,600,compiler,0.4;0.5,0.9,장거리 저격. 컴파일러가 필드에 있어야 건설 가능
```
주의: sniper의 color 셀은 `0.4;0.5;0.9`다 (위 표기 오타 아님 — 실제 파일은 세미콜론).

`data/enemies.csv` — abilities는 `;` 리스트, 0.1 구현 능력은 `crash_tower`(널포인터), `split`(concat) 두 가지:
```csv
id,name,hp,speed,reward,abilities,color,desc
bug,버그,30,40,10,,0.9;0.3;0.3,평범한 버그. 어디에나 있다
null-ptr,널 포인터,20,60,15,crash_tower,0.6;0.3;0.9,맞은 타워의 다음 판단을 nil로 만든다
concat-nil,attempt to concatenate a nil value,50,30,20,split,0.9;0.6;0.2,죽으면 둘로 이어붙는다..
```

`data/items.csv` — api 셀이 해금되는 전역 이름:
```csv
id,name,api,desc
cache,캐시,cache,cache.get(k)/cache.set(k*v) 사용 가능. 계산 결과를 저장해 재사용한다
webhook,웹훅,on_spawn,on_spawn(fn) 사용 가능. 적이 등장하는 순간 fn(enemy)가 호출된다
```

`data/stages.csv` (스테이지 1 한 줄 — 나머지는 Task 10):
```csv
id,mode,concept,ui,maze_file,budget,languages,pause_at,wave_clock,hints_file,solution_file,reward_item
1,normal,첫 타워,button,mazes/001.txt,200,lua,60;150,,,curriculum/001_solution.lua,
```

`data/timelines.csv` (스테이지 1: 300초 결정론 스케줄, col=스폰 열):
```csv
stage_id,at,spawn,count,interval,col
1,5,bug,5,3,6
1,70,bug,8,2.5,6
1,160,bug,10,2,4
1,240,bug,12,1.5,8
```

`data/mazes/001.txt` (12열×16행, `#`=벽, `.`=통로, `B`=건설칸) 와
`data/curriculum/001_solution.lua`:
```
###.####.###
#..........#
#.B......B.#
#..........#
###.####.###
#..........#
#.B......B.#
#..........#
#.####.###.#
#..........#
#.B......B.#
#..........#
###.####.###
#..........#
#.B......B.#
....########
```
```lua
-- 001_solution.lua: 버튼 모드 생성 코드와 동일
function on_tick(self, world)
    self:attack(world.nearest())
end
```

- [ ] **Step 2: 실패하는 데이터 테스트 작성**

`tests/test_data.lua`:
```lua
return function(t)
    local db = require("src.db")
    local d = db.load(PROJECT_ROOT)

    t.ok(d.towers.printer, "towers.csv 로드")
    t.eq(d.towers.printer.cost, 100, "타워 cost 숫자 변환")
    t.eq(d.towers.sniper.requires, "compiler", "테크 의존성 파싱")
    t.ok(d.enemies["null-ptr"], "enemies.csv 로드")
    t.eq(d.stages[1].budget, 200, "stages.csv budget 숫자 변환")
    t.eq(d.stages[1].pause_at[1], 60, "pause_at 리스트 숫자 변환")

    local tl = d.timeline(1)
    t.ok(#tl >= 4, "타임라인 이벤트 존재")
    t.eq(tl[1].spawn, "bug", "타임라인 첫 이벤트")
    t.ok(tl[1].at <= tl[#tl].at, "타임라인 시각 정렬")

    local errs = d.validate()
    t.eq(#errs, 0, "참조 무결성 (오류 0건): " .. table.concat(errs, " / "))
end
```

- [ ] **Step 3: 실패 확인** — 테스트 실행, Expected: `module 'src.db' not found`

- [ ] **Step 4: db.lua 구현**

`src/db.lua`:
```lua
local csv = require("src.csv")
local db = {}

local function index(recs, numfields)
    local out = {}
    for _, r in ipairs(recs) do
        for _, f in ipairs(numfields) do
            r[f] = (r[f] ~= "" and tonumber(r[f])) or (r[f] == "" and nil or r[f])
        end
        local id = tonumber(r.id) or r.id
        r.id = id
        out[id] = r
    end
    return out
end

function db.load(root)
    local d = { root = root }
    d.towers = index(csv.load(root .. "/data/towers.csv"),
        { "cost", "damage", "range", "cooldown", "bullet_speed" })
    d.enemies = index(csv.load(root .. "/data/enemies.csv"), { "hp", "speed", "reward" })
    d.items = index(csv.load(root .. "/data/items.csv"), {})
    d.stages = index(csv.load(root .. "/data/stages.csv"), { "budget", "wave_clock" })
    for _, s in pairs(d.stages) do
        local pauses = {}
        for _, v in ipairs(csv.list(s.pause_at)) do pauses[#pauses + 1] = tonumber(v) end
        s.pause_at = pauses
    end

    local events = csv.load(root .. "/data/timelines.csv")
    for _, e in ipairs(events) do
        e.stage_id = tonumber(e.stage_id)
        e.at, e.count, e.interval, e.col =
            tonumber(e.at), tonumber(e.count), tonumber(e.interval) or 0, tonumber(e.col)
    end
    function d.timeline(stageId)
        local out = {}
        for _, e in ipairs(events) do
            if e.stage_id == stageId then out[#out + 1] = e end
        end
        table.sort(out, function(a, b) return a.at < b.at end)
        return out
    end

    function d.validate()
        local errs = {}
        local function fileExists(rel)
            local f = io.open(root .. "/data/" .. rel, "rb")
            if f then f:close(); return true end
            return false
        end
        for _, e in ipairs(events) do
            if not d.enemies[e.spawn] then
                errs[#errs + 1] = ("timelines: 스테이지 %s의 spawn '%s'가 enemies.csv에 없음")
                    :format(tostring(e.stage_id), tostring(e.spawn))
            end
            if not d.stages[e.stage_id] then
                errs[#errs + 1] = "timelines: 없는 스테이지 " .. tostring(e.stage_id)
            end
        end
        for id, s in pairs(d.stages) do
            if not fileExists(s.maze_file) then
                errs[#errs + 1] = ("stages %s: 미로 파일 없음 %s"):format(id, s.maze_file)
            end
            if s.solution_file ~= "" and not fileExists(s.solution_file) then
                errs[#errs + 1] = ("stages %s: 정답 파일 없음 %s"):format(id, s.solution_file)
            end
            if s.hints_file ~= "" and not fileExists(s.hints_file) then
                errs[#errs + 1] = ("stages %s: 힌트 파일 없음 %s"):format(id, s.hints_file)
            end
            if s.reward_item ~= "" and not d.items[s.reward_item] then
                errs[#errs + 1] = ("stages %s: 없는 보상 아이템 %s"):format(id, s.reward_item)
            end
        end
        for id, tw in pairs(d.towers) do
            if tw.requires ~= "" and not d.towers[tw.requires] then
                errs[#errs + 1] = ("towers %s: 없는 requires %s"):format(id, tw.requires)
            end
        end
        return errs
    end
    return d
end

return db
```

- [ ] **Step 5: 통과 확인** — Expected: test_data 전부 PASS (`RESULT`에 fail=0)

- [ ] **Step 6: Commit** — `git commit -m "codedefense: CSV 게임 데이터와 무결성 검사 로더"`

---

### Task 4: grid.lua — 미로와 플로우필드

**Files:**
- Create: `src/grid.lua`, `tests/test_grid.lua`

**Interfaces:**
- Produces: `grid.COLS=12, grid.ROWS=16, grid.CELL=32`; `grid.load(path)` → `g` (`g.walls[r][c]`bool, `g.build[r][c]`bool, `g.flow[r][c]={dr,dc}|nil`, `g.dist[r][c]`); `grid.toXY(r,c)` → 픽셀 좌상단. 적은 flow를 따라 맨 아랫줄 통로 칸에 도달한 뒤 화면 밖으로 나가면 서버라인 도달로 친다.

- [ ] **Step 1: 실패하는 테스트**

`tests/test_grid.lua`:
```lua
return function(t)
    local grid = require("src.grid")
    local g = grid.load(PROJECT_ROOT .. "/data/mazes/001.txt")

    t.eq(grid.COLS, 12, "그리드 열 수")
    t.eq(grid.ROWS, 16, "그리드 행 수")
    t.ok(g.walls[1][1], "1행1열은 벽(#)")
    t.ok(not g.walls[2][2], "2행2열은 통로")
    t.ok(g.build[3][3], "3행3열은 건설칸(B)")
    t.ok(g.walls[3][3], "건설칸은 적이 못 지나감")

    -- 플로우필드: 위쪽 통로에서 아래로 향하는 경로가 존재
    t.ok(g.flow[2][2] ~= nil, "통로 칸에 플로우 존재")
    t.ok(g.dist[2][2] > 0, "위쪽 통로의 거리 > 0")
    t.eq(g.dist[16][1], 0, "맨 아랫줄 통로 거리 0")

    -- 플로우를 따라가면 반드시 아랫줄에 도달 (막힌 미로 감지)
    local r, c, steps = 2, 2, 0
    while g.dist[r][c] ~= 0 and steps < 500 do
        local d = g.flow[r][c]
        r, c, steps = r + d[1], c + d[2], steps + 1
    end
    t.eq(g.dist[r][c], 0, "플로우 추적이 서버라인 도달")

    local x, y = grid.toXY(1, 1)
    t.eq(x, 0, "toXY x"); t.eq(y, 0, "toXY y")
end
```

- [ ] **Step 2: 실패 확인** — Expected: `module 'src.grid' not found`

- [ ] **Step 3: grid.lua 구현**

```lua
local grid = {}
grid.COLS, grid.ROWS, grid.CELL = 12, 16, 32

local DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

-- 미로 파일: ROWS줄 × COLS문자. '#'=벽, '.'=통로, 'B'=건설칸(벽 취급)
function grid.load(path)
    local f = assert(io.open(path, "rb"), "미로 파일 없음: " .. path)
    local g = { walls = {}, build = {} }
    local r = 0
    for line in f:lines() do
        line = line:gsub("[\r%s]+$", "")
        if line ~= "" then
            r = r + 1
            assert(#line == grid.COLS,
                ("%s %d행 길이 %d ~= %d"):format(path, r, #line, grid.COLS))
            g.walls[r], g.build[r] = {}, {}
            for c = 1, grid.COLS do
                local ch = line:sub(c, c)
                g.walls[r][c] = (ch == "#" or ch == "B")
                g.build[r][c] = (ch == "B")
            end
        end
    end
    f:close()
    assert(r == grid.ROWS, ("%s: 행 수 %d ~= %d"):format(path, r, grid.ROWS))
    grid.computeFlow(g)
    return g
end

-- BFS: 맨 아랫줄 통로들로부터의 거리 → 각 통로 칸의 다음 이동 방향
function grid.computeFlow(g)
    local dist, queue, head = {}, {}, 1
    for r = 1, grid.ROWS do dist[r] = {} end
    for c = 1, grid.COLS do
        if not g.walls[grid.ROWS][c] then
            dist[grid.ROWS][c] = 0
            queue[#queue + 1] = { grid.ROWS, c }
        end
    end
    while head <= #queue do
        local r, c = queue[head][1], queue[head][2]
        head = head + 1
        for _, d in ipairs(DIRS) do
            local nr, nc = r + d[1], c + d[2]
            if nr >= 1 and nr <= grid.ROWS and nc >= 1 and nc <= grid.COLS
                and not g.walls[nr][nc] and dist[nr][nc] == nil then
                dist[nr][nc] = dist[r][c] + 1
                queue[#queue + 1] = { nr, nc }
            end
        end
    end
    local flow = {}
    for r = 1, grid.ROWS do
        flow[r] = {}
        for c = 1, grid.COLS do
            local d0 = dist[r][c]
            if d0 and d0 > 0 then
                for _, d in ipairs(DIRS) do
                    local nr, nc = r + d[1], c + d[2]
                    if nr >= 1 and nr <= grid.ROWS and nc >= 1 and nc <= grid.COLS
                        and dist[nr][nc] and dist[nr][nc] < d0 then
                        flow[r][c] = d
                        break
                    end
                end
            end
        end
    end
    g.dist, g.flow = dist, flow
end

function grid.toXY(r, c)
    return (c - 1) * grid.CELL, (r - 1) * grid.CELL
end

return grid
```

- [ ] **Step 4: 통과 확인** → **Step 5: Commit** `"codedefense: 미로 그리드와 플로우필드"`

---

### Task 5: sandbox.lua — 격리 실행과 명령 예산

**Files:**
- Create: `src/sandbox.lua`, `tests/test_sandbox.lua`

**Interfaces:**
- Produces: `sandbox.baseEnv()` → 화이트리스트 env; `sandbox.compile(source, env, name)` → `env|nil, err`(정의 실행까지); `sandbox.call(fn, budget, ...)` → `ok, err, usedInstr`(대략값). `sandbox.QUANTUM=50`. 이후 태스크는 `usedInstr`로 오버클럭을 계산한다.

- [ ] **Step 1: 실패하는 테스트**

`tests/test_sandbox.lua`:
```lua
return function(t)
    local sb = require("src.sandbox")

    -- 정상 실행
    local env = sb.baseEnv()
    local ok = sb.compile("function on_tick() return math.max(1, 2) end", env, "t1")
    t.ok(ok, "compile 성공")
    local ok2, _, used = sb.call(env.on_tick, 10000)
    t.ok(ok2, "call 성공")
    t.ok(used >= 0, "명령 수 반환")

    -- 문법 오류
    local bad, err = sb.compile("function on_tick( return end", sb.baseEnv(), "t2")
    t.ok(bad == nil and err ~= nil, "문법 오류 감지")

    -- 샌드박스 탈출 차단
    local esc = sb.baseEnv()
    t.ok(esc.io == nil and esc.os == nil and esc.love == nil and esc.debug == nil
        and esc.loadstring == nil and esc.getfenv == nil and esc.setfenv == nil
        and esc.rawset == nil and esc._G == nil,
        "io/os/love/debug/loadstring/_G 차단")

    -- 전역 오염 차단: 유저 코드의 전역은 env에만 남는다
    local iso = sb.baseEnv()
    sb.compile("leaked = 123", iso, "t3")
    t.ok(_G.leaked == nil and iso.leaked == 123, "전역 오염 격리")

    -- 무한 루프 → 예산 초과 오류
    local loopEnv = sb.baseEnv()
    sb.compile("function on_tick() while true do end end", loopEnv, "t4")
    local ok3, err3 = sb.call(loopEnv.on_tick, 5000)
    t.ok(not ok3, "무한 루프 중단")
    t.ok(tostring(err3):find("예산"), "예산 초과 메시지")

    -- 런타임 오류가 pcall로 격리
    local errEnv = sb.baseEnv()
    sb.compile("function on_tick() local x = nil; return x.y end", errEnv, "t5")
    local ok4, err4 = sb.call(errEnv.on_tick, 5000)
    t.ok(not ok4 and err4 ~= nil, "런타임 오류 격리")
end
```

- [ ] **Step 2: 실패 확인** — Expected: `module 'src.sandbox' not found`

- [ ] **Step 3: sandbox.lua 구현**

```lua
local sandbox = {}
sandbox.QUANTUM = 50  -- 훅 1회 = 50 명령

local function copyTable(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
end

-- 유저 코드에 보이는 전역: 순수 함수만. love/io/os/debug 없음
function sandbox.baseEnv()
    return {
        math = copyTable(math), string = copyTable(string), table = copyTable(table),
        pairs = pairs, ipairs = ipairs, select = select, next = next,
        tostring = tostring, tonumber = tonumber, type = type, unpack = unpack,
    }
end

-- source의 최상위(함수 정의부)를 env에서 실행. 성공 시 env 반환
function sandbox.compile(source, env, name)
    local chunk, err = loadstring(source, "@" .. (name or "tower"))
    if not chunk then return nil, err end
    if jit then jit.off(chunk, true) end  -- count 훅이 JIT 코드에서 무시되는 것 방지
    setfenv(chunk, env)
    local ok, rerr = pcall(chunk)
    if not ok then return nil, rerr end
    return env
end

-- fn을 명령 예산 안에서 실행. return ok, err, usedInstr(QUANTUM 배수 근사)
function sandbox.call(fn, budget, ...)
    local used, limit = 0, math.ceil(budget / sandbox.QUANTUM)
    debug.sethook(function()
        used = used + 1
        if used >= limit then
            debug.sethook()
            error("명령 예산 초과 (무한 루프?)", 2)
        end
    end, "", sandbox.QUANTUM)
    local ok, err = pcall(fn, ...)
    debug.sethook()
    return ok, ok and nil or err, used * sandbox.QUANTUM
end

return sandbox
```

- [ ] **Step 4: 통과 확인** → **Step 5: Commit** `"codedefense: Lua 샌드박스 (명령 예산·격리)"`

주의: `compile`이 만든 `env.on_tick`도 chunk 내부 정의라 `jit.off(chunk, true)`의 재귀 플래그로 함께 JIT 제외된다. 테스트 t4가 이를 검증한다.

---

### Task 6: battle.lua 코어 + 엔티티 + api.lua (전투 시뮬레이션)

**Files:**
- Create: `src/enemy.lua`, `src/tower.lua`, `src/projectile.lua`, `src/api.lua`, `src/battle.lua`, `tests/test_battle.lua`

**Interfaces:**
- Consumes: `db.load`, `grid.load`, `sandbox.*`
- Produces:
  - `Battle(d, stageId, placements)` — placements = `{ {r=, c=, tower="printer", code="...", items={"cache"}} , ...}`
  - `battle:update(dt)`; `battle.status` ∈ `"prep"|"running"|"clear"|"defeat"`; `battle:start()` (prep→running)
  - `battle.clock`(전투 경과초), `battle.serverHP`(시작 10), `battle.enemies/towers/projectiles/log`
  - 타워 필드: `t.crashed`(워치독 남은 초), `t.overclock`(0..1), `t.charge`(초), `t.cd`(남은 쿨다운)
  - 규칙: 10Hz 틱마다 `on_tick(selfApi, worldApi)` 실행. `self:attack(target)`은 사거리/쿨다운 검증 후 발사. 차지: ready 상태로 공격 안 하면 `charge += 0.1/틱`(최대 3초), 발사 시 데미지·총알크기 ×(1+charge×0.5), 차지 리셋. 오버클럭: `usedInstr`가 예산(3000)의 절반 미만이면 쿨다운 ×0.7. 런타임 오류 → `crashed=3`(3초 후 자동 복구). `pause_at` 도달 → `status="prep"`, `battle:start()`로 재개. 300초 도달 → `"clear"`, `serverHP<=0` → `"defeat"`.

- [ ] **Step 1: 실패하는 테스트**

`tests/test_battle.lua`:
```lua
return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local d = db.load(PROJECT_ROOT)

    local function readSolution(stageId)
        local s = d.stages[stageId]
        local f = assert(io.open(PROJECT_ROOT .. "/data/" .. s.solution_file, "rb"))
        local code = f:read("*a"); f:close()
        return code
    end

    local function run(placements, code, seconds)
        local b = Battle(d, 1, placements)
        b:start()
        local dt = 1 / 60
        for _ = 1, math.floor(seconds / dt) do
            if b.status == "prep" then b:start() end     -- 준비 단계 자동 재개
            if b.status == "clear" or b.status == "defeat" then break end
            b:update(dt)
        end
        return b
    end

    -- 타워 없이 방치 → 서버 HP 깎여 패배
    local b0 = run({}, nil, 300)
    t.eq(b0.status, "defeat", "무방비 시 패배")

    -- 정답 코드 배치 → 클리어
    local code = readSolution(1)
    local placements = {
        { r = 3, c = 3, tower = "printer", code = code, items = {} },
        { r = 3, c = 10, tower = "printer", code = code, items = {} },
        { r = 7, c = 3, tower = "printer", code = code, items = {} },
        { r = 7, c = 10, tower = "printer", code = code, items = {} },
    }
    local b1 = run(placements, code, 400)
    t.eq(b1.status, "clear", "스테이지1 정답 코드 클리어")
    t.ok(b1.serverHP > 0, "클리어 시 서버 생존")

    -- 오류 코드 → 타워 크래시 후 워치독 복구, 전투는 계속
    local crashCode = "function on_tick(self, world)\n  local x = nil\n  return x.y\nend"
    local b2 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = crashCode, items = {} } })
    b2:start()
    for _ = 1, 60 do b2:update(1 / 60) end
    t.ok(b2.towers[1].crashed > 0, "런타임 오류로 크래시 상태")
    for _ = 1, 240 do b2:update(1 / 60) end
    t.ok(b2.towers[1].crashed == 0, "워치독 3초 후 복구")

    -- 무한 루프 코드 → 타임아웃 (크래시 취급), 게임은 멈추지 않음
    local loopCode = "function on_tick(self, world)\n  while true do end\nend"
    local b3 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = loopCode, items = {} } })
    b3:start()
    for _ = 1, 30 do b3:update(1 / 60) end
    t.ok(b3.towers[1].crashed > 0, "무한 루프 타임아웃 크래시")

    -- 테크 의존성: compiler 없이 sniper 배치 시도 → 오류
    local ok = pcall(Battle, d, 1, { { r = 3, c = 3, tower = "sniper", code = code, items = {} } })
    t.ok(not ok, "requires 미충족 배치는 오류")

    -- 아이템 해금: cache 장착 시에만 env에 cache 존재
    local cacheCode = "function on_tick(self, world)\n  cache.set('n', (cache.get('n') or 0) + 1)\nend"
    local b4 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = cacheCode, items = { "cache" } } })
    b4:start()
    for _ = 1, 30 do b4:update(1 / 60) end
    t.eq(b4.towers[1].crashed, 0, "cache 장착 시 사용 가능")
    local b5 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = cacheCode, items = {} } })
    b5:start()
    for _ = 1, 30 do b5:update(1 / 60) end
    t.ok(b5.towers[1].crashed > 0, "cache 미장착 시 크래시")
end
```

- [ ] **Step 2: 실패 확인** — Expected: `module 'src.battle' not found`

- [ ] **Step 3: 엔티티 구현**

`src/enemy.lua`:
```lua
local Object = require("lib.classic")
local grid = require("src.grid")

local Enemy = Object:extend()

function Enemy:new(def, r, c)
    self.def = def
    self.id = nil          -- battle이 부여
    self.hp, self.max_hp = def.hp, def.hp
    self.r, self.c = r, c
    self.x, self.y = grid.toXY(r, c)
    self.x = self.x + grid.CELL / 2
    self.y = self.y + grid.CELL / 2
    self.dead, self.reached = false, false
end

-- 플로우필드를 따라 칸 중심에서 칸 중심으로 이동
function Enemy:update(dt, g)
    local tx, ty = grid.toXY(self.r, self.c)
    tx, ty = tx + grid.CELL / 2, ty + grid.CELL / 2
    local dx, dy = tx - self.x, ty - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.def.speed * dt
    if dist <= step then
        self.x, self.y = tx, ty
        if g.dist[self.r][self.c] == 0 then
            self.reached = true              -- 서버라인 도달
            return
        end
        local f = g.flow[self.r][self.c]
        if f then self.r, self.c = self.r + f[1], self.c + f[2] end
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Enemy
```

`src/tower.lua`:
```lua
local Object = require("lib.classic")
local grid = require("src.grid")

local Tower = Object:extend()

function Tower:new(def, r, c, items)
    self.def = def
    self.r, self.c = r, c
    self.x, self.y = grid.toXY(r, c)
    self.x = self.x + grid.CELL / 2
    self.y = self.y + grid.CELL / 2
    self.items = items or {}
    self.cd = 0            -- 남은 쿨다운(초)
    self.charge = 0        -- 차지샷 누적(초, 최대 3)
    self.overclock = 0     -- 0..1 (직전 틱 효율)
    self.crashed = 0       -- 워치독 남은 초
    self.env = nil         -- battle이 샌드박스 env 부여
    self.pendingTarget = nil
    self.lastError = nil
end

function Tower:effectiveCooldown()
    return self.def.cooldown * (1 - 0.3 * self.overclock)
end

return Tower
```

`src/projectile.lua`:
```lua
local Object = require("lib.classic")

local Projectile = Object:extend()

function Projectile:new(x, y, target, damage, speed, size)
    self.x, self.y = x, y
    self.target = target       -- Enemy 참조 (죽으면 소멸)
    self.damage, self.speed, self.size = damage, speed, size
    self.done = false
end

function Projectile:update(dt)
    if self.target.dead or self.target.reached then self.done = true return end
    local dx, dy = self.target.x - self.x, self.target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.speed * dt
    if dist <= step then
        self.target.hp = self.target.hp - self.damage
        self.done = true
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Projectile
```

- [ ] **Step 4: api.lua 구현**

```lua
-- 타워 스크립트 env에 self/world/아이템 API를 구성한다
local sandbox = require("src.sandbox")

local api = {}

local function snapshot(e, tower)
    local dx, dy = e.x - tower.x, e.y - tower.y
    return {
        id = e.id, hp = e.hp, max_hp = e.max_hp, x = e.x, y = e.y,
        speed = e.def.speed, type = e.def.id,
        dist = math.sqrt(dx * dx + dy * dy),
    }
end

-- battle이 틱마다 호출: env에 최신 world/self를 주입
function api.buildEnv(tower, itemsById)
    local env = sandbox.baseEnv()

    -- 읽기 전용 self + attack 명령 (실제 발사는 battle이 검증 후 수행)
    local selfApi = {}
    function selfApi.attack(_, target)
        if type(target) == "table" and target.id then
            tower.pendingTarget = target.id
        end
    end
    env._selfApi = selfApi

    -- 아이템 해금 API
    for _, itemId in ipairs(tower.items) do
        if itemId == "cache" then
            local store = {}
            env.cache = {
                get = function(k) return store[k] end,
                set = function(k, v) store[k] = v end,
            }
        elseif itemId == "webhook" then
            env.on_spawn = function(fn)
                if type(fn) == "function" then tower.spawnHandler = fn end
            end
        end
    end
    return env
end

-- 틱 직전 world 스냅샷 갱신 (env 재사용, 상태 유지)
function api.refresh(env, tower, enemies)
    local snaps = {}
    for _, e in ipairs(enemies) do
        if not e.dead and not e.reached then
            snaps[#snaps + 1] = snapshot(e, tower)
        end
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

    local selfApi = env._selfApi
    selfApi.x, selfApi.y = tower.x, tower.y
    selfApi.range, selfApi.damage = tower.def.range, tower.def.damage
    selfApi.charge, selfApi.overclock = tower.charge, tower.overclock
    selfApi.ready = tower.cd <= 0
    env.self = selfApi
    return env.self, world
end

return api
```

- [ ] **Step 5: battle.lua 구현**

```lua
local Object = require("lib.classic")
local grid = require("src.grid")
local sandbox = require("src.sandbox")
local api = require("src.api")
local Enemy = require("src.enemy")
local Tower = require("src.tower")
local Projectile = require("src.projectile")

local TICK = 0.1            -- 10Hz 의사결정
local BUDGET = 3000         -- 틱당 명령 예산
local TOTAL = 300           -- 일반 모드 전투 총 시간(초)
local WATCHDOG = 3          -- 크래시 후 재시작(초)
local CHARGE_MAX = 3

local Battle = Object:extend()

function Battle:new(d, stageId, placements)
    self.d = d
    self.stage = assert(d.stages[stageId], "없는 스테이지: " .. tostring(stageId))
    self.grid = grid.load(d.root .. "/data/" .. self.stage.maze_file)
    self.timeline = d.timeline(stageId)
    self.spawned = {}          -- timeline 이벤트별 스폰한 수
    self.clock, self.tickAcc = 0, 0
    self.serverHP = 10
    self.status = "prep"
    self.pauseIdx = 1          -- 다음 pause_at 인덱스
    self.enemies, self.towers, self.projectiles, self.log = {}, {}, {}, {}
    self.nextEnemyId = 1

    -- 배치 (테크 의존성 검증 포함)
    local placed = {}
    for _, p in ipairs(placements) do placed[p.tower] = true end
    for _, p in ipairs(placements) do
        local def = assert(d.towers[p.tower], "없는 타워: " .. tostring(p.tower))
        if def.requires ~= "" then
            assert(placed[def.requires],
                ("'%s' 건설에는 '%s' 타워가 필요합니다"):format(def.name, def.requires))
        end
        assert(self.grid.build[p.r] and self.grid.build[p.r][p.c],
            ("(%d,%d)는 건설칸이 아닙니다"):format(p.r, p.c))
        local tw = Tower(def, p.r, p.c, p.items)
        if p.code and p.code ~= "" and def.damage > 0 then
            local env = api.buildEnv(tw, d.items)
            local ok, err = sandbox.compile(p.code, env, def.id)
            if ok then tw.env = env
            else tw.crashed = WATCHDOG; tw.lastError = err end
        end
        self.towers[#self.towers + 1] = tw
    end
end

function Battle:start()
    if self.status == "prep" then self.status = "running" end
end

function Battle:say(msg)
    self.log[#self.log + 1] = msg
    if #self.log > 8 then table.remove(self.log, 1) end
end

function Battle:spawnFromTimeline()
    for i, ev in ipairs(self.timeline) do
        local n = self.spawned[i] or 0
        while n < ev.count and self.clock >= ev.at + n * ev.interval do
            local def = self.d.enemies[ev.spawn]
            local e = Enemy(def, 1, ev.col)
            e.id = self.nextEnemyId
            self.nextEnemyId = self.nextEnemyId + 1
            self.enemies[#self.enemies + 1] = e
            n = n + 1
            -- 웹훅(on_spawn) 아이템: 등장 즉시 핸들러 호출
            for _, tw in ipairs(self.towers) do
                if tw.spawnHandler and tw.crashed <= 0 and tw.env then
                    local selfApi = select(1, api.refresh(tw.env, tw, self.enemies))
                    sandbox.call(function() tw.spawnHandler(selfApi) end, BUDGET)
                end
            end
        end
        self.spawned[i] = n
    end
end

function Battle:runTick()
    for _, tw in ipairs(self.towers) do
        if tw.env and tw.crashed <= 0 and tw.env.on_tick then
            local selfApi, world = api.refresh(tw.env, tw, self.enemies)
            tw.pendingTarget = nil
            local ok, err, used = sandbox.call(tw.env.on_tick, BUDGET, selfApi, world)
            if not ok then
                tw.crashed = WATCHDOG
                tw.lastError = tostring(err)
                self:say(("[크래시] %s: %s"):format(tw.def.name, tostring(err)))
            else
                -- 오버클럭: 예산을 절반 미만으로 쓰면 효율 1.0에 수렴
                tw.overclock = math.max(0, 1 - (used / (BUDGET / 2)))
                self:resolveAttack(tw)
            end
        end
    end
end

function Battle:resolveAttack(tw)
    if tw.cd > 0 then return end
    -- 공격 안 함 → 차지 누적
    if not tw.pendingTarget then
        tw.charge = math.min(CHARGE_MAX, tw.charge + TICK)
        return
    end
    local target
    for _, e in ipairs(self.enemies) do
        if e.id == tw.pendingTarget and not e.dead and not e.reached then target = e break end
    end
    if not target then return end
    local dx, dy = target.x - tw.x, target.y - tw.y
    if dx * dx + dy * dy > tw.def.range * tw.def.range then return end
    local mult = 1 + tw.charge * 0.5
    self.projectiles[#self.projectiles + 1] =
        Projectile(tw.x, tw.y, target, tw.def.damage * mult, tw.def.bullet_speed, 4 * mult)
    tw.charge = 0
    tw.cd = tw:effectiveCooldown()
end

function Battle:update(dt)
    if self.status ~= "running" then return end

    -- pause_at 도달 → 준비 단계
    local nextPause = self.stage.pause_at[self.pauseIdx]
    if nextPause and self.clock >= nextPause then
        self.pauseIdx = self.pauseIdx + 1
        self.status = "prep"
        return
    end

    self.clock = self.clock + dt
    self:spawnFromTimeline()

    self.tickAcc = self.tickAcc + dt
    while self.tickAcc >= TICK do
        self.tickAcc = self.tickAcc - TICK
        self:runTick()
    end

    for _, tw in ipairs(self.towers) do
        tw.cd = math.max(0, tw.cd - dt)
        if tw.crashed > 0 then
            tw.crashed = math.max(0, tw.crashed - dt)
            if tw.crashed == 0 then self:say(("[워치독] %s 재시작"):format(tw.def.name)) end
        end
    end

    for _, e in ipairs(self.enemies) do
        if not e.dead and not e.reached then e:update(dt, self.grid) end
    end
    for _, p in ipairs(self.projectiles) do
        if not p.done then p:update(dt) end
    end

    -- 정리: 죽음/도달 처리
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        if e.hp <= 0 and not e.dead then
            e.dead = true
            -- split 능력: 죽으면 절반 체력 둘로
            if e.def.abilities:find("split") and not e.isSplit then
                for k = -1, 1, 2 do
                    local child = Enemy(e.def, e.r, e.c)
                    child.hp = math.floor(e.max_hp / 2)
                    child.max_hp = child.hp
                    child.x = e.x + k * 8
                    child.isSplit = true
                    child.id = self.nextEnemyId
                    self.nextEnemyId = self.nextEnemyId + 1
                    self.enemies[#self.enemies + 1] = child
                end
            end
        end
        if e.reached and not e.counted then
            e.counted = true
            self.serverHP = self.serverHP - 1
            -- crash_tower 능력: 도달 시 최근접 타워 크래시
            if e.def.abilities:find("crash_tower") then
                local best, bd
                for _, tw in ipairs(self.towers) do
                    local dx, dy = tw.x - e.x, tw.y - e.y
                    local dd = dx * dx + dy * dy
                    if not bd or dd < bd then bd, best = dd, tw end
                end
                if best then
                    best.crashed = WATCHDOG
                    self:say(("[널 포인터] %s 크래시!"):format(best.def.name))
                end
            end
        end
        if e.dead or e.counted then table.remove(self.enemies, i) end
    end
    for i = #self.projectiles, 1, -1 do
        if self.projectiles[i].done then table.remove(self.projectiles, i) end
    end

    if self.serverHP <= 0 then self.status = "defeat" return end
    if self.clock >= TOTAL then self.status = "clear" end
end

return Battle
```

- [ ] **Step 6: 통과 확인** — Expected: test_battle 전 항목 PASS. 실패하면 스테이지1 밸런스(타이밍/예산)를 조정하되 결정론 유지.

- [ ] **Step 7: Commit** `"codedefense: 전투 시뮬 코어 (틱·오버클럭·차지·워치독·테크·아이템)"`

---

### Task 7: editor.lua — 텍스트 에디터 + 스니펫 퀵바

**Files:**
- Create: `src/editor.lua`
- (자동 테스트는 커서 로직만 — 뷰는 Task 9 이후 스크린샷으로 확인)
- Create: `tests/test_editor.lua` 후 `tests/main.lua`의 suites에 `"test_editor"` 추가

**Interfaces:**
- Produces: `Editor(x, y, w, h)` 위젯. 메서드: `:setText(s)`, `:getText()`, `:textinput(ch)`, `:keypressed(key)`(left/right/up/down/home/end/backspace/delete/return/tab), `:insert(s)`(퀵바용 — 커서 위치 삽입, `${1}` 마커가 있으면 거기로 커서 점프), `:draw(fonts, focused)`, `:setQuickbar({{key="f1", label="함수", text="function on_tick(self, world)\n  ${1}\nend"}, ...})`, `:quickbarPressed(key)` → bool. 상태 필드: `.lines`(배열), `.cr/.cc`(커서 행/열, 1-기반).

- [ ] **Step 1: 실패하는 테스트**

`tests/test_editor.lua`:
```lua
return function(t)
    local Editor = require("src.editor")
    local ed = Editor(0, 0, 400, 300)

    ed:setText("abc")
    t.eq(ed:getText(), "abc", "setText/getText")
    t.eq(ed.cr, 1, "커서 행 초기화")

    ed:keypressed("end"); ed:textinput("d")
    t.eq(ed:getText(), "abcd", "textinput 삽입")

    ed:keypressed("return"); ed:textinput("x")
    t.eq(ed:getText(), "abcd\nx", "엔터 줄바꿈")
    t.eq(ed.cr, 2, "엔터 후 커서 행")

    ed:keypressed("backspace")
    t.eq(ed:getText(), "abcd\n", "백스페이스")
    ed:keypressed("backspace")
    t.eq(ed:getText(), "abcd", "줄 병합 백스페이스")

    ed:setText("한글 주석")
    ed:keypressed("end"); ed:textinput("!")
    t.eq(ed:getText(), "한글 주석!", "UTF-8 한글 뒤 삽입")
    ed:keypressed("backspace"); ed:keypressed("backspace")
    t.eq(ed:getText(), "한글 주", "UTF-8 한글 백스페이스(글자 단위)")

    ed:setText(""); ed:insert("function on_tick(self, world)\n  ${1}\nend")
    t.eq(ed:getText(), "function on_tick(self, world)\n  \nend", "insert가 ${1} 제거")
    t.eq(ed.cr, 2, "insert 후 커서가 ${1} 위치")

    ed:setQuickbar({ { key = "f1", label = "공격", text = "self:attack(world.nearest())" } })
    ed:setText("")
    t.ok(ed:quickbarPressed("f1"), "퀵바 f1 처리")
    t.eq(ed:getText(), "self:attack(world.nearest())", "퀵바 삽입")
    t.ok(not ed:quickbarPressed("f9"), "빈 슬롯은 false")
end
```

- [ ] **Step 2: 실패 확인** → **Step 3: editor.lua 구현**

```lua
local Object = require("lib.classic")
local utf8 = require("utf8")

local Editor = Object:extend()

function Editor:new(x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
    self.lines = { "" }
    self.cr, self.cc = 1, 1     -- cc는 바이트 오프셋이 아니라 "글자" 인덱스
    self.scroll = 0
    self.quickbar = {}
end

-- 글자 배열 유틸 (UTF-8 안전)
local function chars(s)
    local out = {}
    for _, cp in utf8.codes(s) do out[#out + 1] = utf8.char(cp) end
    return out
end
local function joinRange(cs, a, b)
    return table.concat(cs, "", a, b)
end

function Editor:setText(s)
    self.lines = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do self.lines[#self.lines + 1] = line end
    if #self.lines == 0 then self.lines = { "" } end
    self.cr, self.cc = 1, 1
end

function Editor:getText()
    return table.concat(self.lines, "\n")
end

function Editor:textinput(ch)
    local cs = chars(self.lines[self.cr])
    table.insert(cs, self.cc, ch)
    self.lines[self.cr] = table.concat(cs)
    self.cc = self.cc + 1
end

function Editor:insert(s)
    -- 여러 줄 삽입 + ${1} 커서 마커
    local markR, markC
    local first = true
    for line in (s .. "\n"):gmatch("(.-)\n") do
        local m = line:find("%${1}", 1, false)
        if m then
            local before = line:sub(1, m - 1)
            markC = #chars(before) + 1
            line = line:gsub("%${1}", "", 1)
        end
        if first then
            local cs = chars(self.lines[self.cr])
            local left = joinRange(cs, 1, self.cc - 1)
            local right = joinRange(cs, self.cc, #cs)
            self.lines[self.cr] = left .. line
            self._tail = right
            if markC then markR, markC = self.cr, #chars(left) + markC end
            first = false
        else
            self.cr = self.cr + 1
            table.insert(self.lines, self.cr, line)
            if markC and not markR then markR = self.cr end
        end
    end
    self.lines[self.cr] = self.lines[self.cr] .. (self._tail or "")
    self._tail = nil
    if markR then self.cr, self.cc = markR, markC
    else self.cc = #chars(self.lines[self.cr]) + 1 end
end

function Editor:keypressed(key)
    local cs = chars(self.lines[self.cr])
    if key == "left" then
        if self.cc > 1 then self.cc = self.cc - 1
        elseif self.cr > 1 then self.cr = self.cr - 1; self.cc = #chars(self.lines[self.cr]) + 1 end
    elseif key == "right" then
        if self.cc <= #cs then self.cc = self.cc + 1
        elseif self.cr < #self.lines then self.cr = self.cr + 1; self.cc = 1 end
    elseif key == "up" and self.cr > 1 then
        self.cr = self.cr - 1
        self.cc = math.min(self.cc, #chars(self.lines[self.cr]) + 1)
    elseif key == "down" and self.cr < #self.lines then
        self.cr = self.cr + 1
        self.cc = math.min(self.cc, #chars(self.lines[self.cr]) + 1)
    elseif key == "home" then self.cc = 1
    elseif key == "end" then self.cc = #cs + 1
    elseif key == "return" then
        local left = joinRange(cs, 1, self.cc - 1)
        local right = joinRange(cs, self.cc, #cs)
        self.lines[self.cr] = left
        table.insert(self.lines, self.cr + 1, right)
        self.cr, self.cc = self.cr + 1, 1
    elseif key == "tab" then
        self:textinput(" "); self:textinput(" ")
    elseif key == "backspace" then
        if self.cc > 1 then
            table.remove(cs, self.cc - 1)
            self.lines[self.cr] = table.concat(cs)
            self.cc = self.cc - 1
        elseif self.cr > 1 then
            local prev = chars(self.lines[self.cr - 1])
            local newCc = #prev + 1
            self.lines[self.cr - 1] = self.lines[self.cr - 1] .. self.lines[self.cr]
            table.remove(self.lines, self.cr)
            self.cr, self.cc = self.cr - 1, newCc
        end
    elseif key == "delete" then
        if self.cc <= #cs then
            table.remove(cs, self.cc)
            self.lines[self.cr] = table.concat(cs)
        elseif self.cr < #self.lines then
            self.lines[self.cr] = self.lines[self.cr] .. self.lines[self.cr + 1]
            table.remove(self.lines, self.cr + 1)
        end
    end
end

function Editor:setQuickbar(slots) self.quickbar = slots end

function Editor:quickbarPressed(key)
    for _, slot in ipairs(self.quickbar) do
        if slot.key == key then self:insert(slot.text) return true end
    end
    return false
end

local KEYWORDS = { ["function"] = true, ["end"] = true, ["if"] = true, ["then"] = true,
    ["else"] = true, ["elseif"] = true, ["for"] = true, ["while"] = true, ["do"] = true,
    ["local"] = true, ["return"] = true, ["and"] = true, ["or"] = true, ["not"] = true }

function Editor:draw(fonts, focused)
    local lh = fonts.mono:getHeight() + 4
    local visible = math.floor(self.h / lh)
    if self.cr - 1 < self.scroll then self.scroll = self.cr - 1 end
    if self.cr > self.scroll + visible then self.scroll = self.cr - visible end

    love.graphics.setColor(0.08, 0.09, 0.12)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setFont(fonts.mono)
    love.graphics.setScissor(self.x, self.y, self.w, self.h)
    for i = 1, visible do
        local li = i + self.scroll
        local line = self.lines[li]
        if not line then break end
        local ly = self.y + (i - 1) * lh + 2
        love.graphics.setColor(0.4, 0.45, 0.5)
        love.graphics.print(("%3d"):format(li), self.x + 4, ly)
        -- 단순 하이라이트: 키워드만 색 구분
        local lx = self.x + 40
        for token, sep in line:gmatch("([^%s]*)(%s*)") do
            if token ~= "" then
                if KEYWORDS[token] then love.graphics.setColor(0.9, 0.55, 0.4)
                else love.graphics.setColor(0.85, 0.88, 0.92) end
                love.graphics.print(token, lx, ly)
                lx = lx + fonts.mono:getWidth(token)
            end
            lx = lx + fonts.mono:getWidth(sep)
        end
        -- 커서
        if focused and li == self.cr and (love.timer.getTime() * 2) % 2 < 1 then
            local cs = chars(line)
            local cx = self.x + 40 + fonts.mono:getWidth(joinRange(cs, 1, self.cc - 1))
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", cx, ly, 2, lh - 4)
        end
    end
    love.graphics.setScissor()

    -- 퀵바
    local qy = self.y + self.h + 6
    for i, slot in ipairs(self.quickbar) do
        local qx = self.x + (i - 1) * 92
        love.graphics.setColor(0.16, 0.18, 0.24)
        love.graphics.rectangle("fill", qx, qy, 86, 26, 4)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.95, 0.8, 0.4)
        love.graphics.print(slot.key:upper(), qx + 5, qy + 5)
        love.graphics.setColor(0.85, 0.88, 0.92)
        love.graphics.print(slot.label, qx + 30, qy + 5)
    end
end

return Editor
```

- [ ] **Step 4: `tests/main.lua`의 suites에 `"test_editor"` 추가 후 통과 확인**

주의: test 하네스는 `t.modules.graphics=false`라 `Editor:draw`는 테스트에서 호출하지 않는다. `require("utf8")`은 LÖVE 내장이므로 헤드리스에서도 동작한다.

- [ ] **Step 5: Commit** `"codedefense: 코드 에디터와 스니펫 퀵바"`

---

### Task 8: progress.lua — 저장/로드

**Files:**
- Create: `src/progress.lua`
- 테스트: 하네스가 헤드리스(`love.filesystem` 사용 가능)이므로 `tests/test_progress.lua` 추가, suites에 등록

**Interfaces:**
- Produces: `progress.load()` → `p` = `{ cleared = {[stageId]=true}, items = {"cache", ...}, codes = {[stageId]="소스"}, snippets = nil|배열 }`; `progress.save(p)`. 직렬화는 단순 Lua 리터럴 문자열 생성 + `loadstring` 복원 (JSON 라이브러리 불필요).

- [ ] **Step 1: 실패하는 테스트**

`tests/test_progress.lua`:
```lua
return function(t)
    local progress = require("src.progress")
    local p = { cleared = { [1] = true, [2] = true }, items = { "cache" },
        codes = { [1] = 'function on_tick(self, world)\n  self:attack(world.nearest())\nend' } }
    progress.save(p)
    local q = progress.load()
    t.ok(q.cleared[1] and q.cleared[2], "클리어 저장/복원")
    t.eq(q.items[1], "cache", "아이템 저장/복원")
    t.ok(q.codes[1]:find("on_tick"), "코드 저장/복원")
    local empty = progress.load("없는파일.lua")
    t.ok(type(empty.cleared) == "table" and next(empty.cleared) == nil, "빈 진행도 기본값")
end
```

- [ ] **Step 2: 실패 확인** → **Step 3: 구현**

`src/progress.lua`:
```lua
local progress = {}
local FILE = "progress.lua"

local function serialize(v, out)
    local ty = type(v)
    if ty == "number" or ty == "boolean" then out[#out + 1] = tostring(v)
    elseif ty == "string" then out[#out + 1] = ("%q"):format(v)
    elseif ty == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            out[#out + 1] = "["
            serialize(k, out)
            out[#out + 1] = "]="
            serialize(val, out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    end
end

function progress.save(p)
    local out = { "return " }
    serialize(p, out)
    love.filesystem.write(FILE, table.concat(out))
end

function progress.load(file)
    file = file or FILE
    local data = love.filesystem.read(file)
    if data then
        local chunk = loadstring(data)
        if chunk then
            local ok, p = pcall(chunk)
            if ok and type(p) == "table" then
                p.cleared = p.cleared or {}
                p.items = p.items or {}
                p.codes = p.codes or {}
                return p
            end
        end
    end
    return { cleared = {}, items = {}, codes = {} }
end

return progress
```

- [ ] **Step 4: suites 등록 + 통과 확인** → **Step 5: Commit** `"codedefense: 진행도 저장/로드"`

---

### Task 9: 상태 머신 — title / stageselect / prep / battle / result

**Files:**
- Create: `states/title.lua`, `states/stageselect.lua`, `states/prep.lua`, `states/battle.lua`, `states/result.lua`
- Modify: `main.lua` (Gamestate 연결)

**Interfaces:**
- Consumes: `Battle`, `Editor`, `db`, `progress`, `fonts`
- Produces: 상태 전환 흐름 `title →(enter) stageselect →(스테이지 선택) prep →(F5) battle →(pause_at) prep … →(클리어/패배) result →(enter) stageselect`. `prep:enter(prev, d, stageId, p)` / `battle state:enter(prev, battleObj, ctx)` / `result:enter(prev, ctx)` 시그니처는 아래 코드 그대로.

- [ ] **Step 1: main.lua 교체**

```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local db = require("src.db")
local progress = require("src.progress")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setKeyRepeat(true)
    fonts.load()
    local root = love.filesystem.getSource()
    local d = db.load(root)
    local errs = d.validate()
    if #errs > 0 then
        error("데이터 무결성 오류:\n" .. table.concat(errs, "\n"))
    end
    Gamestate.registerEvents()
    Gamestate.switch(require("states.title"), d, progress.load())
end
```

- [ ] **Step 2: title.lua / stageselect.lua**

`states/title.lua`:
```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local title = {}

function title:enter(_, d, p)
    self.d, self.p = d, p
end

function title:draw()
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.setFont(fonts.big)
    love.graphics.printf("Code Defense", 0, 180, 960, "center")
    love.graphics.setFont(fonts.ui)
    love.graphics.printf("코드로 타워를 조종해 서버를 지켜라", 0, 240, 960, "center")
    love.graphics.printf("Enter 키를 눌러 시작", 0, 380, 960, "center")
    love.graphics.setFont(fonts.small)
    love.graphics.printf("ESC 종료", 0, 420, 960, "center")
end

function title:keypressed(key)
    if key == "return" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
    elseif key == "escape" then
        love.event.quit()
    end
end

return title
```

`states/stageselect.lua` (잠금: 이전 스테이지 클리어 시 다음 오픈):
```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")

local sel = {}

function sel:enter(_, d, p)
    self.d, self.p = d, p
    self.ids = {}
    for id, s in pairs(d.stages) do
        if s.mode == "normal" then self.ids[#self.ids + 1] = id end
    end
    table.sort(self.ids)
    self.cursor = 1
end

function sel:unlocked(id)
    return id == self.ids[1] or self.p.cleared[id - 1]
end

function sel:draw()
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.printf("스테이지 선택", 0, 40, 960, "center")
    love.graphics.setFont(fonts.ui)
    for i, id in ipairs(self.ids) do
        local s = self.d.stages[id]
        local y = 110 + (i - 1) * 40
        local locked = not self:unlocked(id)
        if i == self.cursor then love.graphics.setColor(1, 0.85, 0.3)
        elseif locked then love.graphics.setColor(0.35, 0.38, 0.42)
        else love.graphics.setColor(0.85, 0.88, 0.92) end
        local mark = self.p.cleared[id] and " [클리어]" or (locked and " [잠김]" or "")
        love.graphics.printf(("%d. %s%s"):format(id, s.concept, mark), 0, y, 960, "center")
    end
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("↑↓ 이동 · Enter 선택 · ESC 타이틀", 0, 600, 960, "center")
end

function sel:keypressed(key)
    if key == "up" then self.cursor = math.max(1, self.cursor - 1)
    elseif key == "down" then self.cursor = math.min(#self.ids, self.cursor + 1)
    elseif key == "return" then
        local id = self.ids[self.cursor]
        if self:unlocked(id) then
            Gamestate.switch(require("states.prep"), self.d, id, self.p)
        end
    elseif key == "escape" then
        Gamestate.switch(require("states.title"), self.d, self.p)
    end
end

return sel
```

- [ ] **Step 3: prep.lua** — 배치 + 코딩(모드별 UI: button/hint/free) + 전투 시작

```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")
local Editor = require("src.editor")
local Battle = require("src.battle")

local GRID_X, GRID_Y = 20, 60
local STRATEGIES = {
    { label = "가까운 적", code = "function on_tick(self, world)\n  self:attack(world.nearest())\nend" },
    { label = "약한 적", code = "function on_tick(self, world)\n  self:attack(world.weakest())\nend" },
    { label = "빠른 적", code = "function on_tick(self, world)\n  self:attack(world.fastest())\nend" },
}

local prep = {}

function prep:enter(prev, d, stageId, p, resume)
    self.d, self.stageId, self.p = d, stageId, p
    self.stage = d.stages[stageId]
    if resume then
        -- 전투 중 pause_at으로 돌아온 경우: battle 유지
        self.battle = resume.battle
        self.money = resume.money
    else
        self.battle = nil
        self.money = self.stage.budget
        self.placements = {}
    end
    self.g = grid.load(d.root .. "/data/" .. self.stage.maze_file)
    self.cursorR, self.cursorC = 3, 3
    self.selTower = "printer"
    self.stratIdx = 1
    self.focus = "grid"          -- "grid" | "editor"
    self.editor = Editor(480, 60, 460, 420)
    self.editor:setQuickbar({
        { key = "f1", label = "on_tick", text = "function on_tick(self, world)\n  ${1}\nend" },
        { key = "f2", label = "공격", text = "self:attack(world.nearest())" },
        { key = "f3", label = "if", text = "if ${1} then\nend" },
        { key = "f4", label = "for", text = "for i, e in ipairs(world.enemies()) do\n  ${1}\nend" },
    })
    -- 코드 초기값: 저장된 코드 > 힌트 템플릿 > 빈 화면
    if self.stage.ui ~= "button" then
        local saved = p.codes[stageId]
        if saved then self.editor:setText(saved)
        elseif self.stage.hints_file ~= "" then
            local f = io.open(d.root .. "/data/" .. self.stage.hints_file, "rb")
            if f then self.editor:setText(f:read("*a")); f:close() end
        end
    end
end

function prep:currentCode()
    if self.stage.ui == "button" then
        return STRATEGIES[self.stratIdx].code
    end
    return self.editor:getText()
end

function prep:draw()
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.print(("스테이지 %d — %s   예산 %d"):format(self.stageId, self.stage.concept, self.money), 20, 16)

    -- 그리드
    for r = 1, grid.ROWS do
        for c = 1, grid.COLS do
            local x, y = grid.toXY(r, c)
            x, y = x + GRID_X, y + GRID_Y
            if self.g.build[r][c] then love.graphics.setColor(0.2, 0.3, 0.2)
            elseif self.g.walls[r][c] then love.graphics.setColor(0.22, 0.24, 0.3)
            else love.graphics.setColor(0.12, 0.13, 0.17) end
            love.graphics.rectangle("fill", x, y, grid.CELL - 1, grid.CELL - 1)
        end
    end
    -- 배치된 타워
    for _, pl in ipairs(self.placements or {}) do
        local x, y = grid.toXY(pl.r, pl.c)
        local col = self.d.towers[pl.tower].color
        local rgb = {}
        for v in col:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        love.graphics.setColor(rgb[1], rgb[2], rgb[3])
        love.graphics.rectangle("fill", x + GRID_X + 4, y + GRID_Y + 4, grid.CELL - 9, grid.CELL - 9)
    end
    -- 커서
    if self.focus == "grid" then
        local x, y = grid.toXY(self.cursorR, self.cursorC)
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.rectangle("line", x + GRID_X, y + GRID_Y, grid.CELL - 1, grid.CELL - 1)
    end

    -- 우측 패널
    if self.stage.ui == "button" then
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.9, 0.92, 0.95)
        love.graphics.print("타겟 전략 (Space로 변경):", 480, 60)
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.print("< " .. STRATEGIES[self.stratIdx].label .. " >", 480, 90)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.6, 0.65, 0.7)
        love.graphics.print("이 버튼은 사실 이 코드입니다:", 480, 140)
        love.graphics.setColor(0.5, 0.8, 0.6)
        love.graphics.print(STRATEGIES[self.stratIdx].code, 480, 165)
    else
        self.editor:draw(fonts, self.focus == "editor")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("화살표 배치커서 · B 건설(" .. self.selTower .. ") · T 타워종류 · Tab 에디터/그리드 · F5 전투 시작 · ESC 나가기",
        20, 600, 920, "left")
end

function prep:keypressed(key)
    if key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
        return
    end
    if key == "f5" then self:startBattle() return end
    if key == "tab" and self.stage.ui ~= "button" then
        self.focus = (self.focus == "grid") and "editor" or "grid"
        return
    end
    if self.focus == "editor" then
        if not self.editor:quickbarPressed(key) then self.editor:keypressed(key) end
        return
    end
    -- 그리드 조작
    if key == "up" then self.cursorR = math.max(1, self.cursorR - 1)
    elseif key == "down" then self.cursorR = math.min(grid.ROWS, self.cursorR + 1)
    elseif key == "left" then self.cursorC = math.max(1, self.cursorC - 1)
    elseif key == "right" then self.cursorC = math.min(grid.COLS, self.cursorC + 1)
    elseif key == "space" and self.stage.ui == "button" then
        self.stratIdx = self.stratIdx % #STRATEGIES + 1
    elseif key == "t" then
        local order = { "printer", "compiler", "sniper" }
        for i, id in ipairs(order) do
            if id == self.selTower then self.selTower = order[i % #order + 1] break end
        end
    elseif key == "b" then
        self:tryBuild()
    end
end

function prep:tryBuild()
    local def = self.d.towers[self.selTower]
    if not self.g.build[self.cursorR][self.cursorC] then return end
    for _, pl in ipairs(self.placements) do
        if pl.r == self.cursorR and pl.c == self.cursorC then return end
    end
    if self.money < def.cost then return end
    if def.requires ~= "" then
        local has = false
        for _, pl in ipairs(self.placements) do
            if pl.tower == def.requires then has = true end
        end
        if not has then return end
    end
    self.money = self.money - def.cost
    self.placements[#self.placements + 1] =
        { r = self.cursorR, c = self.cursorC, tower = self.selTower, items = {} }
end

function prep:textinput(ch)
    if self.focus == "editor" then self.editor:textinput(ch) end
end

function prep:startBattle()
    local code = self:currentCode()
    if self.stage.ui ~= "button" then
        self.p.codes[self.stageId] = code
        require("src.progress").save(self.p)
    end
    for _, pl in ipairs(self.placements) do pl.code = code end
    if not self.battle then
        local ok, battleOrErr = pcall(Battle, self.d, self.stageId, self.placements)
        if not ok then return end
        self.battle = battleOrErr
    end
    -- 문법 오류가 있는 타워가 있으면 시작 막기 (교육: 시작 전 진단)
    for _, tw in ipairs(self.battle.towers) do
        if tw.lastError and tw.env == nil then return end
    end
    self.battle:start()
    Gamestate.switch(require("states.battle"), self.battle,
        { d = self.d, stageId = self.stageId, p = self.p, prepState = self })
end

return prep
```

- [ ] **Step 4: battle 뷰 상태 + result**

`states/battle.lua`:
```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")

local GRID_X, GRID_Y = 20, 60
local view = {}

function view:enter(_, battle, ctx)
    self.b, self.ctx = battle, ctx
    self.speed = 1
end

function view:update(dt)
    self.b:update(dt * self.speed)
    if self.b.status == "prep" then
        Gamestate.switch(require("states.prep"), self.ctx.d, self.ctx.stageId, self.ctx.p,
            { battle = self.b, money = 0 })
    elseif self.b.status == "clear" or self.b.status == "defeat" then
        Gamestate.switch(require("states.result"), self.b.status, self.ctx)
    end
end

function view:draw()
    local b = self.b
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.print(("%.0f초 / 300초   서버 HP %d   배속 x%d (1/2/4)"):format(b.clock, b.serverHP, self.speed), 20, 16)

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
    -- 서버라인
    love.graphics.setColor(0.3, 0.7, 1, 0.6)
    love.graphics.rectangle("fill", GRID_X, GRID_Y + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, 4)

    for _, tw in ipairs(b.towers) do
        local rgb = {}
        for v in tw.def.color:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        if tw.crashed > 0 then love.graphics.setColor(0.4, 0.4, 0.4)
        else love.graphics.setColor(rgb[1], rgb[2], rgb[3]) end
        love.graphics.rectangle("fill", GRID_X + tw.x - 12, GRID_Y + tw.y - 12, 24, 24)
        if tw.crashed > 0 then
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 0.4, 0.3)
            love.graphics.print("크래시", GRID_X + tw.x - 14, GRID_Y + tw.y - 28)
        end
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

    -- 전투 로그
    love.graphics.setFont(fonts.small)
    for i, msg in ipairs(b.log) do
        love.graphics.setColor(0.8, 0.82, 0.86, 1 - (#b.log - i) * 0.1)
        love.graphics.print(msg, 480, 60 + (i - 1) * 20)
    end
end

function view:keypressed(key)
    if key == "1" then self.speed = 1
    elseif key == "2" then self.speed = 2
    elseif key == "4" then self.speed = 4
    elseif key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
    end
end

return view
```

`states/result.lua`:
```lua
local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local progress = require("src.progress")

local result = {}

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
        progress.save(ctx.p)
    end
end

function result:draw()
    love.graphics.setFont(fonts.big)
    if self.status == "clear" then
        love.graphics.setColor(0.4, 0.9, 0.5)
        love.graphics.printf("스테이지 클리어!", 0, 240, 960, "center")
        local reward = self.ctx.d.stages[self.ctx.stageId].reward_item
        if reward ~= "" then
            love.graphics.setFont(fonts.ui)
            love.graphics.setColor(1, 0.85, 0.3)
            love.graphics.printf("아이템 획득: " .. self.ctx.d.items[reward].name, 0, 300, 960, "center")
        end
    else
        love.graphics.setColor(0.95, 0.4, 0.35)
        love.graphics.printf("서버 다운...", 0, 240, 960, "center")
    end
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.85, 0.88, 0.92)
    love.graphics.printf("Enter 스테이지 선택으로", 0, 380, 960, "center")
end

function result:keypressed(key)
    if key == "return" or key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
    end
end

return result
```

- [ ] **Step 5: 수동 부팅 확인** — 게임 실행 → 타이틀 → 스테이지1 (버튼 모드) → 전략 선택 → 타워 2~4개 배치 → F5 → 전투 진행 확인. 콘솔 오류 0.

- [ ] **Step 6: Commit** `"codedefense: 상태 머신과 코어 루프 연결"`

---

### Task 10: 표본 스테이지 1~8 + 회귀 테스트

**Files:**
- Modify: `data/stages.csv`, `data/timelines.csv`
- Create: `data/mazes/002.txt`~`008.txt`, `data/curriculum/` 힌트·정답 파일들
- Modify: `tests/test_battle.lua` — 전 스테이지 정답 클리어 회귀 루프 추가

**스테이지 커리큘럼** (스펙 3.1의 구간 표본):

| id | ui | concept | 가르치는 것 | 보상 |
|----|----|---------|------------|------|
| 1 | button | 첫 타워 | 배치와 전략 버튼 | |
| 2 | button | 전략 바꾸기 | weakest가 유리한 적 구성 | |
| 3 | hint | 따라 치기 | on_tick 뼈대 그대로 타이핑 | |
| 4 | hint | 빈칸 채우기 | `world.____()` 빈칸 | cache |
| 5 | free | 변수 | `local t = world.nearest()` | |
| 6 | free | 조건문 | hp 조건 분기 (null-ptr 우선 처리) | webhook |
| 7 | free | 반복문 | enemies() 순회 + 조건 선택 | |
| 8 | free | 함수 | 보조 함수 정의 (concat-nil 분열 대응) | |

- [ ] **Step 1: stages.csv 전체 교체**

```csv
id,mode,concept,ui,maze_file,budget,languages,pause_at,wave_clock,hints_file,solution_file,reward_item
1,normal,첫 타워,button,mazes/001.txt,200,lua,60;150,,,curriculum/001_solution.lua,
2,normal,전략 바꾸기,button,mazes/002.txt,200,lua,60;150,,,curriculum/002_solution.lua,
3,normal,따라 치기,hint,mazes/003.txt,220,lua,60;150,,curriculum/003_hints.lua,curriculum/003_solution.lua,
4,normal,빈칸 채우기,hint,mazes/004.txt,220,lua,60;150,,curriculum/004_hints.lua,curriculum/004_solution.lua,cache
5,normal,변수,free,mazes/005.txt,240,lua,60;150;240,,curriculum/005_hints.lua,curriculum/005_solution.lua,
6,normal,조건문,free,mazes/006.txt,260,lua,60;150;240,,curriculum/006_hints.lua,curriculum/006_solution.lua,webhook
7,normal,반복문,free,mazes/007.txt,280,lua,60;150;240,,curriculum/007_hints.lua,curriculum/007_solution.lua,
8,normal,함수,free,mazes/008.txt,300,lua,60;150;240,,curriculum/008_hints.lua,curriculum/008_solution.lua,
```

- [ ] **Step 2: timelines.csv 추가 행** (전부 결정론, 스테이지가 오를수록 밀도 증가; null-ptr는 6부터, concat-nil은 8부터)

```csv
2,5,bug,6,3,6
2,40,null-ptr,0,0,6
2,70,bug,10,2.5,4
2,160,bug,12,2,8
2,240,bug,14,1.5,6
3,5,bug,6,3,6
3,80,bug,10,2.5,4
3,170,bug,12,2,8
3,245,bug,15,1.5,6
4,5,bug,8,2.5,6
4,80,bug,12,2,4
4,170,bug,14,1.8,8
4,245,bug,16,1.4,6
5,5,bug,8,2.5,4
5,70,bug,12,2,8
5,160,bug,16,1.6,6
5,245,bug,18,1.3,4
6,5,bug,8,2.5,6
6,60,null-ptr,4,6,4
6,150,bug,14,1.8,8
6,200,null-ptr,6,5,6
6,250,bug,18,1.3,4
7,5,bug,10,2.2,6
7,70,null-ptr,5,5,4
7,160,bug,18,1.5,8
7,240,null-ptr,8,4,6
8,5,bug,10,2.2,6
8,60,concat-nil,4,8,4
8,150,null-ptr,6,5,8
8,220,concat-nil,6,6,6
8,260,bug,20,1.2,4
```
(주의: 2행의 `2,40,null-ptr,0,0,6`은 넣지 않는다 — count 0 이벤트 금지. 위 블록에서 해당 줄은 제외하고 작성.)

- [ ] **Step 3: 미로 002~008 작성** — 001을 기본으로 스테이지마다 통로를 1~2곳 비틀어 변형. 각 파일은 12×16, 맨 아랫줄에 통로 ≥1, 모든 위쪽 통로에서 아랫줄 도달 가능(테스트가 검증). 예: `002.txt`는 001에서 9행을 `#.####.###.#` → `#.#######..#`로 변경하는 식으로 7개 변형 생성.

- [ ] **Step 4: 커리큘럼 파일** — 대표 예시 (전체 8쌍 동일 패턴):

`curriculum/003_hints.lua` (따라 치기 — 주석에 원본 제시):
```lua
-- 아래 코드를 그대로 타이핑하세요:
-- function on_tick(self, world)
--   self:attack(world.nearest())
-- end

```

`curriculum/004_hints.lua` (빈칸):
```lua
function on_tick(self, world)
  -- 빈칸을 채우세요: 가장 가까운 적을 공격합니다
  self:attack(world.______())
end
```

`curriculum/006_solution.lua` (조건문 — null-ptr 우선):
```lua
function on_tick(self, world)
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "null-ptr" then danger = e end
  end
  if danger then
    self:attack(danger)
  else
    self:attack(world.nearest())
  end
end
```

`curriculum/008_solution.lua` (함수 — 분열 대응: 체력 낮은 것부터 정리):
```lua
local function pick(world)
  local best = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "concat-nil" then
      if not best or e.hp < best.hp then best = e end
    end
  end
  return best or world.nearest()
end

function on_tick(self, world)
  self:attack(pick(world))
end
```

001/002/005/007 정답은 각각 nearest/weakest/변수 대입 후 공격/ipairs 순회이며 위와 같은 형태로 작성한다.

- [ ] **Step 5: 회귀 테스트 추가** — `tests/test_battle.lua` 끝에:

```lua
    -- 전 스테이지 정답 코드 회귀: 4타워 표준 배치로 클리어 가능해야 한다
    for stageId = 1, 8 do
        local s = d.stages[stageId]
        local sol = readSolution(stageId)
        local g = require("src.grid").load(PROJECT_ROOT .. "/data/" .. s.maze_file)
        local spots = {}
        for r = 1, 16 do
            for c = 1, 12 do
                if g.build[r][c] and #spots < 6 then spots[#spots + 1] = { r = r, c = c } end
            end
        end
        local placements = {}
        for i = 1, math.min(4, #spots) do
            placements[i] = { r = spots[i].r, c = spots[i].c, tower = "printer", code = sol, items = { "cache", "webhook" } }
        end
        local b = Battle(d, stageId, placements)
        b:start()
        local dt = 1 / 30
        for _ = 1, math.floor(400 / dt) do
            if b.status == "prep" then b:start() end
            if b.status ~= "running" and b.status ~= "prep" then break end
            b:update(dt)
        end
        t.eq(b.status, "clear", ("스테이지 %d 정답 클리어"):format(stageId))
    end
```

- [ ] **Step 6: 테스트 실행, 밸런스 조정** — 실패하는 스테이지는 timelines의 count/interval 또는 towers.csv 수치를 조정해 전 스테이지 PASS로. 조정 후에도 데이터는 결정론 유지.

- [ ] **Step 7: 수동 플레이** — 게임 부팅, 스테이지 1~4를 실제로 플레이 (버튼/따라치기/빈칸 UX 확인), 6에서 webhook 보상 아이템 획득 확인.

- [ ] **Step 8: Commit** `"codedefense: 표본 스테이지 8종과 정답 회귀 테스트"`

---

### Task 11: 문서화와 마무리

**Files:**
- Create: `love2d-codedefense/CLAUDE.md`, `love2d-codedefense/README.md`

- [ ] **Step 1: CLAUDE.md 작성** — 기존 love2d-tetris/CLAUDE.md 형식을 따라: 실행 방법(lovec), 구조, 코딩 규칙(전투 로직은 src/battle.lua 코어에 — states는 뷰만, lib 수정 금지, 스테이지는 CSV+파일 데이터로만 추가, 결정론 원칙), 테스트 방법(`lovec tests`, 스테이지 추가 시 solution 필수), 0.2 이후 로드맵(하드코어, 도감 UI, 공유 카드, 진영). 설계서 경로 링크 포함.

- [ ] **Step 2: README.md 작성** — 게임 소개, 요구사항(LÖVE 11.5), 실행법, 조작키 표(화살표/B/T/Tab/F1~F4/F5/1·2·4/ESC), 스테이지 구성 표, 사용 라이브러리 표(classic/hump, MIT), 폰트 고지(나눔고딕 OFL).

- [ ] **Step 3: 전체 검증** — `lovec tests` 전부 PASS + 게임 부팅 + 스테이지1 클리어 스모크. 콘솔 오류 0.

- [ ] **Step 4: Commit** `"codedefense: 0.1 문서화"` — 이후 사용자에게 0.1 완료 보고.

---

## Self-Review 결과

- **스펙 커버리지**: 0.1 범위(코어 루프·샌드박스·에디터·퀵바·아이템 해금·테크·코드 크래프트·CSV·표본 스테이지)는 Task 1~11이 커버. 하드코어/도감/공유/진영 UI는 계획 헤더에 0.2+로 명시 (스펙 9장의 v1 전체 범위 중 일부를 의도적으로 후속 이관).
- **플레이스홀더**: 미로 002~008과 커리큘럼 4쌍은 생성 규칙+대표 예시로 명세 (실행자가 규칙대로 7개 변형 생성— 테스트가 유효성을 기계 검증하므로 안전).
- **타입 일관성**: `Battle(d, stageId, placements)` / `Editor` 메서드 / `db.load` 반환 구조가 Task 6~10에서 동일 시그니처로 사용됨을 확인. `prep→battle→prep` 재개 시 placements 재사용 흐름 일치 확인.
