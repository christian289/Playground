# codedefense 3칼럼 레이아웃 + 함수 사전 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 오버레이(적 구성·로그)를 전용 정보 칼럼으로 옮기는 3칼럼 레이아웃(1280×640), build 기본 수록 + 에디터 클릭 펼침 함수 사전, 도감 "내 함수" 탭, 룩(Rook) 게임 심볼.

**Architecture:** 코어에는 `battle.userFuncs`(env diff)만 추가하고 나머지는 전부 뷰 재배치. 에디터 클릭 판정은 측정 함수 주입으로 헤드리스 테스트 가능하게. 사전·funcbook은 데이터 주도.

**Tech Stack:** LÖVE 11.5, 기존 모듈 재사용.

**Spec:** `docs/superpowers/specs/2026-07-22-codedefense-layout-funcdict-design.md`

## Global Constraints

- 창 1280×640 (conf.lua). play 레이아웃: 전장 x=8 w=384 / 정보 칼럼 x=400 w=240 / 에디터 x=656 w=610(h 기존 470 유지)
- 정보 칼럼 섹션 순서: 문제 요약 → 적 구성 → 함수 사전 → 전투 로그(8줄). 전장 오버레이(적 구성·로그) 전면 제거
- 함수 사전: 빌트인 `build` 문서 항목이 항상 첫 줄(시그니처 `build(종류, 행, 열, "이름")` + 멱등/예산/건설칸/테크/한글 별칭 규칙 + 예시), 이후 유저 함수 이름 정렬. 에디터에서 함수명 클릭 → 해당 항목 펼침(빌트인=문서, 유저=현재 스크립트 소스 발췌 최대 10줄+정의 줄 번호), 재클릭=접기, 다른 항목 클릭=교체. `local function` 미감지 안내 1줄
- `battle.userFuncs`: setScript 성공 시 env 키 diff로 새 함수 타입 전역 수집(이름 정렬 배열). 시뮬 로직 불변
- `progress.funcbook[이름] = { first = stageId, count = n }` — 저장 성공 시 뷰가 누적(같은 판 중복 없음: 판당 이름별 1회). 기존 세이브 보강
- 도감 3탭: [타워] [몬스터] [내 함수] — 내 함수 탭은 funcbook 목록("스테이지 N에서 처음 정의 · M회")
- 룩 심볼: art에 16×16 도트 룩(팔레트 green/cyan) + `art.rookIconData()`(32×32 ImageData) → main.lua `love.window.setIcon`, 타이틀 로고 위 심볼
- Editor 클릭 판정: `Editor:charAt(px, py, measure)`(measure(문자열)→픽셀폭 주입) + `Editor.tokenAt(line, charIdx)`(식별자 `[%a_][%w_]*` 추출, 순수 함수) — 헤드리스 테스트
- 중앙 정렬 화면들(intro/title/stageselect/result/codex)의 하드코딩 960 → `love.graphics.getWidth()` 기반
- 기존 테스트 194 무손상 + 신규(userFuncs/funcbook/charAt·tokenAt). 유저 텍스트 한글. 코어 시뮬·결정론·샌드박스 불변
- 검증: 전 화면 스크린샷(잘림·겹침) Read 검수 + `tools/package.ps1` 재실행·fused exe 부팅 재확인(창 캡처)
- 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` (PowerShell). 커밋은 태스크마다, 브랜치 `feature/codedefense-tutorial`

## File Structure

```
변경: conf.lua(1280), main.lua(setIcon), src/battle.lua(userFuncs diff), src/editor.lua(charAt/tokenAt),
      src/progress.lua(funcbook 보강), src/art.lua(룩 심볼), states/play.lua(3칼럼+사전 UI),
      states/{title,intro,stageselect,result,codex}.lua(getWidth+심볼+내 함수 탭)
신규: tests/test_editor 확장, test_battle 확장(userFuncs), test_progress 확장(funcbook)
```

---

### Task 1: 코어 — userFuncs 수집 + Editor 클릭 판정 + funcbook 저장

**Files:**
- Modify: `src/battle.lua`, `src/editor.lua`, `src/progress.lua`, `tests/test_battle.lua`, `tests/test_editor.lua`, `tests/test_progress.lua`

**Interfaces (이후 태스크가 그대로 사용):**
- `battle.userFuncs` — setScript 성공 후 이름 정렬 배열(예: `{"helper", "on_tick"}`). 구현: setScript에서 compile 직전 `local known = {}; for k in pairs(env) do known[k] = true end`, 성공 후 `for k, v in pairs(env) do if not known[k] and type(v) == "function" then ... end` 수집·정렬. 실패 시 기존 userFuncs 유지
- `Editor:charAt(px, py, measure) → line, charIdx | nil` — 에디터 내부 좌표(px, py는 에디터 원점 기준)를 (줄, 글자 인덱스)로. 줄 = `floor(py / lineHeight)+1+scroll` (lineHeight는 인자 `lineH`로 주입: `charAt(px, py, lineH, measure)`), 글자 = 좌측부터 measure 누적으로 판정 (줄 번호 여백 40px 제외). 존재하지 않는 줄이면 nil; **줄 끝을 넘는 x는 (줄, 마지막글자+1) 반환** (표준 에디터 동작 — tokenAt과 결합 시 그 위치는 항상 nil 토큰이라 안전. 컨트롤러 판정으로 확정)
- `Editor.tokenAt(lineText, charIdx) → tokenString | nil` — 해당 위치를 포함하는 식별자 `[%a_][%w_]*` (순수 static 함수)
- `progress.load()`에 `p.funcbook = p.funcbook or {}` 보강. funcbook 갱신은 Task 3의 play가 수행

- [ ] **Step 1: 실패하는 테스트 3종**

test_battle 추가:
```lua
    local FN = 'build("printer", 3, 10, "a")\nfunction helper(w) return w.nearest() end\nfunction on_tick(self, world)\n  self:attack(helper(world))\nend'
    local bf = Battle(d, 1, {})
    t.ok(bf:setScript(FN), "userFuncs 스크립트 컴파일")
    t.eq(#bf.userFuncs, 2, "새 함수 2개 수집")
    t.eq(bf.userFuncs[1], "helper", "정렬 첫 항목")
    t.eq(bf.userFuncs[2], "on_tick", "정렬 둘째 항목")
    bf:setScript("function on_tick( broken")
    t.eq(#bf.userFuncs, 2, "실패 저장 시 기존 목록 유지")
```

test_editor 추가 (measure는 글자당 10px 가짜 모노스페이스):
```lua
    local mono = function(s) local n = 0; for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end return n * 10 end
    local ed2 = Editor(0, 0, 400, 300)
    ed2:setText("build(1)\nlocal x = helper(w)")
    local ln, ci = ed2:charAt(40 + 25, 5, 18, mono)   -- 40px 여백 + 2.5글자 → 3번째 글자
    t.eq(ln, 1, "charAt 줄"); t.eq(ci, 3, "charAt 글자")
    t.eq(Editor.tokenAt("build(1)", 3), "build", "tokenAt 식별자")
    t.eq(Editor.tokenAt("local x = helper(w)", 12), "helper", "tokenAt 중간 위치")
    t.eq(Editor.tokenAt("build(1)", 6), nil, "괄호 위치는 nil")
```

test_progress 추가:
```lua
    local pf = progress.load()
    pf.funcbook = { on_tick = { first = 3, count = 5 } }
    progress.save(pf)
    t.eq(progress.load().funcbook.on_tick.count, 5, "funcbook 왕복")
    t.ok(type(progress.load().funcbook) == "table", "funcbook 기본값 보강")
```

- [ ] **Step 2: RED 확인 → 구현 → GREEN** (전 스위트 194 + 신규). tokenAt 주의: charIdx가 토큰 문자 위(끝 괄호 등 제외)일 때만 매치 — `%f` frontier 또는 수동 스캔으로 시작·끝 범위 판정.
- [ ] **Step 3: Commit** `codedefense: userFuncs 수집·에디터 클릭 판정·funcbook 기반`

---

### Task 2: 3칼럼 레이아웃 (창 1280 + play 재배치)

**Files:**
- Modify: `conf.lua`, `states/play.lua`

**Interfaces:**
- Consumes: 기존 stageinfo/art/particles. 정보 칼럼 좌표 상수: `INFO_X=400, INFO_W=240` (play 상단 local)
- Produces: 정보 칼럼 4섹션 그리기(문제 요약/적 구성/함수 사전 자리(placeholder 함수 `drawFuncDict` — Task 3이 구현)/로그 8줄), 전장 오버레이 제거, 에디터 `Editor(656, 48, 610, 470)`, 퀵바·버튼 패널·힌트바·scriptError·튜토리얼 말풍선·문제 카드 좌표 재조정 (말풍선 폭 1264, 문제 카드는 전장+정보 영역 중앙 x≈320)

- [ ] **Step 1:** conf.lua 1280. play.lua 재배치 — 오버레이 블록(적 구성·로그) 제거, 정보 칼럼 섹션 렌더(패널 배경 art.pal.panel, 섹션 제목 fonts.small green), 로그는 최근 8줄(페이드 유지). 진행 바·HUD·전장은 기존 위치 유지.
- [ ] **Step 2:** 스위트 194 무손상 + 부팅 스모크 + 스크린샷(전투 중 1280 레이아웃) Read 검수 — 겹침·잘림 반복 개선.
- [ ] **Step 3: Commit** `codedefense: 3칼럼 레이아웃 (정보 칼럼 신설)`

---

### Task 3: 함수 사전 UI + 에디터 클릭 연동 + funcbook 누적

**Files:**
- Modify: `states/play.lua`

**Interfaces:**
- Consumes: battle.userFuncs, Editor:charAt/tokenAt(Task 1), 정보 칼럼 자리(Task 2)
- Produces: 사전 데이터 `local BUILTIN_DOCS = { build = { sig = 'build(종류, 행, 열, "이름")', lines = { "타워를 짓는 유일한 수단", "같은 이름 재호출은 무시(멱등)", "예산 차감 · 건설칸(B) 전용", "스나이퍼는 컴파일러 필요", '한글 별칭: build("구구클래스", ...)' }, example = 'build("printer", 3, 10, "a")' } }`; `self.dictOpen = nil | "build" | 함수명`; `play:mousepressed(x, y, button)` — 에디터 영역이면 charAt(실폰트 measure = `function(s) return fonts.mono:getWidth(s) end`, lineH = fonts.mono:getHeight()+4)→tokenAt→사전 수록명이면 토글/교체
- 유저 함수 소스 발췌: 현재 에디터 텍스트에서 `^%s*function%s+이름%s*%(` 또는 `^function%s+이름` 줄부터 키워드 카운팅(function/if/for/while/do +1, end −1)으로 대응 end까지, 최대 10줄+"…", 시작 줄 번호 표기

- [ ] **Step 1:** 사전 섹션 렌더 — 접힘: `> build`(빌트인 표식) + 유저 함수 목록 + (없으면 "F5로 저장하면 함수가 등록됩니다") + local 안내 1줄. 펼침: 해당 항목 카드(빌트인 문서/유저 소스 발췌). funcbook 누적: save 성공 시 `for _, name in ipairs(battle.userFuncs)` — 이번 판 최초 이름만 `funcbook[name]` 갱신(first 없으면 현 스테이지, count는 판당 1회 가드 `self.fx.funcCounted` 테이블) 후 progress.save 통합.
- [ ] **Step 2:** 스위트 무손상 + 스크린샷(사전 목록/`build` 펼침/유저 함수 펼침 3장) Read 검수.
- [ ] **Step 3: Commit** `codedefense: 함수 사전 (build 문서·클릭 펼침·영구 수집)`

---

### Task 4: 나머지 화면 폭 대응 + 도감 [내 함수] 탭 + 룩 심볼

**Files:**
- Modify: `states/{title,intro,stageselect,result,codex}.lua`, `src/art.lua`, `main.lua`

**Interfaces:**
- `art.drawRook(x, y, scale, t)`(16×16 도트 룩 — 총안(crenellation) 3개 + 몸통 + 받침, green/cyan) 및 `art.rookIconData() → ImageData(32×32)`; main.lua `love.window.setIcon(art.rookIconData())` (art.load 후)
- codex 3탭: [타워] [몬스터] [내 함수] — 내 함수 탭 목록 `이름 — 스테이지 N에서 처음 정의 · M회` (funcbook, 없으면 "아직 수집된 함수가 없습니다")

- [ ] **Step 1:** 각 화면의 960 하드코딩을 `local W = love.graphics.getWidth()` 기반으로 (printf 폭·중앙 정렬·말풍선·카드). 타이틀 로고 위에 drawRook(scale 4) 심볼. 도감 탭 확장(←/→ 순환 3탭).
- [ ] **Step 1.5 마우스 지원 (스펙 §2.6):** title에 `mousemoved(x, y)`(항목 영역 호버 시 cursor 이동 — 메뉴 항목 y 범위 계산 헬퍼)와 `mousepressed`(좌클릭 = 해당 항목 선택 실행); intro에 `mousepressed` 좌클릭 = `cs:press()` 경로(Enter 동일); result에 `mousepressed` 좌클릭 = Enter 동일. 키보드 조작은 전부 유지. 안내 문구에 클릭 병기(타이틀 "↑↓/마우스 이동 · Enter/클릭 선택", 인트로 "Enter/클릭 다음 · ESC 건너뛰기").
- [ ] **Step 2:** 스위트 무손상 + 전 화면 스크린샷(타이틀 심볼/인트로/선택/결과/도감 3탭) Read 검수 + 창 아이콘 확인(작업표시줄은 캡처 어려우면 setIcon 호출 성공만 확인).
- [ ] **Step 3: Commit** `codedefense: 1280 폭 대응·도감 내 함수 탭·룩 심볼`

---

### Task 5: 검증·패키징·문서

**Files:**
- Modify: `love2d-codedefense/CLAUDE.md`, `README.md`

- [ ] **Step 1:** 문서 — 1280 레이아웃, 정보 칼럼 구성, 함수 사전(빌트인 build·클릭 펼침·local 한계), funcbook·도감 3탭, 룩 심볼, 마우스 조작 추가.
- [ ] **Step 2:** 전 스위트 + `tools/package.ps1` 재실행 + fused exe 부팅 창 캡처(1280 창) Read 확인.
- [ ] **Step 3: Commit** `codedefense: 레이아웃·함수 사전 문서화`

---

## Self-Review 결과

- **스펙 커버리지**: §1(Task 2·4), §2(Task 1·3), §2.5(Task 4), §3(Task 1 테스트), §4(Task 2~5 검증). 범위 제외 준수.
- **플레이스홀더 없음**: 좌표·시그니처·테스트 코드 명시. 사전 문서 문구는 BUILTIN_DOCS에 리터럴로 제시.
- **타입 일관성**: battle.userFuncs/charAt(px,py,lineH,measure)/tokenAt(line,charIdx)/funcbook 스키마가 Task 1 정의 = Task 3·4 사용 일치. drawFuncDict 자리(Task 2) → Task 3 구현.
