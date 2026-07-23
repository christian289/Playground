# Code Defense Wave A(플레이어빌리티) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 승인된 Wave A 스펙(2026-07-23-codedefense-playability-design.md)의 8개 항목 구현 — 슬로우 모드, demolish, 별점, 위기 경고, 웨이브 예고 색상, 프로필 탭, 패배 코칭, 스테이지 네러티브+포스트모템.

**Architecture:** 코어(src/battle.lua, src/api.lua, src/db.lua)는 헤드리스 테스트 동반 변경, 뷰(states/)는 오토플레이 스크린샷 검증. 데이터는 CSV 칼럼 추가 + data/lore/ 신규 12파일.

**Tech Stack:** LÖVE 11.5 / LuaJIT. 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` (현재 208 pass 기준).

## Global Constraints

- 모든 사용자 향 문구·오류·로그는 한글.
- 코어(src/)는 love API 사용 금지(순수 Lua) — 뷰 의존 없음.
- 스테이지 결정론 유지: 새 기능이 시뮬 결과를 바꾸면 안 됨 (demolish는 유저 호출 시에만).
- 별점 산식 고정: 클리어 시 잔존 HP ≥8 → ★3, ≥4 → ★2, 그 외 클리어 → ★1. 저장 필드 추가 없이 records[id].bestHP에서 계산.
- demolish 환불 = floor(cost × 0.5). 로그 형식 `[철거] <타워명> → "<이름>" · +<환불> 환불`, 실패 `[오류] 철거 실패 — "<이름>" 타워가 없습니다`.
- 슬로우 모드 키 Ctrl+5 → speed 0.5. HUD 표기 `배속 x%g`.
- 기존 테스트 208개 전체 통과 유지. 커밋마다 스위트 실행.
- 폰트 글리프 주의: NanumGothic에 ✓·九 없음 전례. ★/☆는 구현 중 렌더 확인, 없으면 '*'/'-' 대체.
- 스크린샷 검증은 captureScreenshot(callback)+io로 스크래치패드에 저장 후 Read 판독(파일명 문자열 형태 금지 — %APPDATA%로 감).

---

### Task 1: 코어 — demolishTower + reachedByType + demolish API

**Files:**
- Modify: `love2d-codedefense/src/battle.lua`
- Modify: `love2d-codedefense/src/api.lua`
- Test: `love2d-codedefense/tests/test_demolish.lua` (신규), 기존 스위트 등록 방식은 tests/main.lua 참조

**Interfaces:**
- Consumes: Battle(d, stageId, opts), battle:buildTower(typeId, r, c, name), buildEnv(battle)
- Produces: `Battle:demolishTower(name)` → bool, `battle.reachedByType` = { [enemyId] = n }, `env.demolish(name)` — Task 2·5가 사용

- [ ] **Step 1: 실패 테스트 작성** — test_demolish.lua: ① build 후 demolish → towers 수 0, money가 환불만큼 증가(floor(cost*0.5)), 점유 해제되어 같은 칸 build 재성공 ② 미존재 이름 demolish → false + 로그에 "철거 실패" 포함 ③ setScript 안 on_tick에서 demolish 호출 → 다음 틱 반영·크래시 없음 ④ demolish 후 같은 이름 build → 타워 재생성(멱등 캐시가 막지 않음) ⑤ 적이 서버라인 도달 시 battle.reachedByType[적id] 증가(도달 이벤트는 기존 serverHP 감소 경로에서 확인)
- [ ] **Step 2: 실행해 실패 확인** — 신규 스위트가 fail 하는지
- [ ] **Step 3: 구현** — battle.lua: demolishTower(이름 검색→towers 제거→occupied 해제→환불 money 가산→로그, Global Constraints의 로그 형식 그대로). 멱등 빌드 캐시(builtByName 등 — 실제 필드명은 파일에서 확인)에서 해당 이름 제거. 적 도달 처리 지점에 `self.reachedByType[e.def.id] = (self.reachedByType[e.def.id] or 0) + 1` (생성자에서 `self.reachedByType = {}`). api.lua: `env.demolish = function(name) return battle:demolishTower(name) end` + 실패 시에도 battle 로그가 이미 남으므로 추가 처리 없음. BUILTIN_DOCS는 Task 5에서.
- [ ] **Step 4: 전체 스위트 통과 확인** — 208 + 신규 ≥5 pass
- [ ] **Step 5: 커밋** — `codedefense: demolish API + 도달 집계(코어)`

### Task 2: 뷰 소품 팩 — 슬로우 모드·위기 경고·눈금 색상·별점 표시·패배 코칭

**Files:**
- Modify: `love2d-codedefense/states/play.lua`, `love2d-codedefense/states/result.lua`, `love2d-codedefense/states/stageselect.lua`
- Create: `love2d-codedefense/src/stars.lua` (별점 산식 순수 모듈)
- Test: `love2d-codedefense/tests/test_stars.lua` (신규)

**Interfaces:**
- Consumes: battle.reachedByType(Task 1), records[id].bestHP, self.speed, 진행 바 draw 블록(play.lua ~407행), d.enemies[id].color
- Produces: `stars.of(hp)` → 0~3 (0=미클리어 의미 없음, 클리어 전제) — Task 3 프로필이 사용

- [ ] **Step 1: stars 테스트** — stars.of(10)=3, of(8)=3, of(7)=2, of(4)=2, of(3)=1, of(1)=1 단언 후 실패 확인
- [ ] **Step 2: src/stars.lua 구현** (순수 모듈, 스펙 산식) → 테스트 통과
- [ ] **Step 3: 슬로우 모드** — play.lua 배속 분기 `key == "5"` 추가 → speed 0.5, HUD `x%d`→`x%g`, 힌트바 두 문구 "Ctrl+1/2/4 배속"→"Ctrl+5/1/2/4 배속"
- [ ] **Step 4: 위기 경고** — serverHP ≤3 && status running: 전장 가장자리 붉은 비네트(테두리 4겹 rectangle 알파 그라데이션, 사인 펄스 주기 1.2s 원시 dt 누적 타이머) + HUD "서버 HP n" 부분 빨간색(문자열 분리 출력)
- [ ] **Step 5: 눈금 색상** — 진행 바 스폰 눈금을 d.enemies[ev.spawn].color로, 지나간 눈금 알파 0.35
- [ ] **Step 6: 별점 표시** — stageselect 기록 텍스트 `[★★☆ · HP n · 구]` (stars.of(bestHP), ☆=미달 칸). ★ 렌더 확인: 하네스 스크린샷에서 글리프 보이는지 Read로 확인, 미표시 시 '*' 대체하고 계획서에 기록. result 클리어 화면에 `이번 ★n (최고 ★m)` 한 줄
- [ ] **Step 7: 패배 코칭** — result 패배 화면 "버틴 시간" 아래: ctx.reached(play가 battle.reachedByType 전달하도록 switch ctx에 추가)에서 최다 도달 종 1개 `가장 많이 도달: <이름> <n>기` (동률 시 먼저 스폰된 종 — d 타임라인 순). 도달 0이면 줄 생략
- [ ] **Step 8: 스위트 + 오토플레이 스크린샷 검증** (슬로우 HUD·비네트·눈금·별점·코칭 각 1장, Read 판독) 후 커밋 — `codedefense: 슬로우 모드·위기 경고·별점 표시·패배 코칭(뷰)`

### Task 3: 도감 프로필 탭

**Files:**
- Modify: `love2d-codedefense/states/codex.lua`

**Interfaces:**
- Consumes: p.records, p.funcbook, p.gugu_found, stars.of(Task 2), d.stages
- Produces: 도감 4번째 탭 [프로필]

- [ ] **Step 1: 탭 추가** — 기존 3탭 페이지네이션에 [프로필] 추가(탭 전환 시 cursor=1 리셋 패턴 유지). 내용: 총 배포(Σ tries) / 클리어 스테이지 수 / 별 합계(Σ stars.of(bestHP), 클리어만) / 등록 함수 수 / 구구 발견("???" 또는 "발견") / 스테이지별 한 줄 `1. 첫 타워 — 시도 3 · ★★★`(미클리어는 `— 미클리어`). 긴 목록은 기존 도감 스크롤 패턴 재사용
- [ ] **Step 2: 스위트(회귀) + 스크린샷 검증 후 커밋** — `codedefense: 도감 프로필 탭`

### Task 4: 네러티브 데이터 — lore 스키마 + 12편 집필 + origin

**Files:**
- Modify: `love2d-codedefense/data/stages.csv` (lore_file 칼럼), `love2d-codedefense/data/enemies.csv` (origin 칼럼), `love2d-codedefense/src/db.lua` (칼럼 로드 + validate lore_file 존재 검사)
- Create: `love2d-codedefense/data/lore/001.lua` ~ `012.lua`
- Test: `love2d-codedefense/tests/test_db.lua` 기존 스위트에 검사 추가(방식은 파일 참조)

**Interfaces:**
- Produces: `d.stages[id].lore_file`, `d.enemies[id].origin`, lore 파일 스키마 `return { briefing = "...", postmortem = "..." }` — Task 5가 사용

- [ ] **Step 1: 테스트** — validate: 존재하지 않는 lore_file → 오류 메시지, 빈 칼럼 → 통과. enemies origin 로드 확인. 실패 확인 후 구현
- [ ] **Step 2: enemies.csv origin 집필** (칼럼 추가, 한글 그대로):
  - bug: `1947년 그레이스 호퍼의 팀이 Mark II 릴레이에서 진짜 나방을 꺼내 로그에 붙였다 — "버그가 실제로 발견된 최초의 사례"`
  - null-ptr: `1965년 토니 호어가 ALGOL W에 널 참조를 넣었고, 훗날 스스로 "10억 달러짜리 실수"라 사과했다`
  - concat-nil: `Lua 런타임 오류 메시지 그대로다. 모든 Lua 개발자가 반드시 한 번은 만난다`
- [ ] **Step 3: lore 12편 작성** — 각 파일은 스키마 그대로, 아래 전문을 그대로 사용한다:
  - 001: briefing `첫 출근. 사수가 남긴 메모에는 "서버라인만 지키면 된다"고 적혀 있다. 모니터에 첫 알람이 떴다 — 버그다. 어디에나 있다더니, 정말 첫날부터 온다.` / postmortem `버그는 박멸하는 것이 아니라 관리하는 것이다 — 1947년 호퍼의 나방 이후 변한 적 없는 진실. 실무의 해법: 테스트와 모니터링으로 조기에 발견하기. 이 판의 해법: 길목에 첫 프린터를 세우고 서버라인 앞에서 잡아냈다.`
  - 002: briefing `버그가 빨라졌다. 어제의 배치로는 못 잡는다. 사수의 메모 2장: "같은 대응을 반복하는 건 대응이 아니다."` / postmortem `이슈 트리아지의 기본 — 우선순위는 상황이 바꾼다. 실무의 해법: 심각도에 따라 대응 순서를 재조정. 이 판의 해법: 전략 버튼으로 대응 우선순위를 바꿔 빠른 적부터 끊었다.`
  - 003: briefing `선배의 코드가 위키에 남아 있다. "이해 못 해도 좋다. 일단 그대로 쳐라." 손이 코드를 기억할 때까지.` / postmortem `필사(사경)는 가장 오래된 코딩 학습법이다 — 손으로 문법을 익히면 눈이 구조를 본다. 실무의 해법: 좋은 코드를 읽고 따라 쓰기. 이 판의 해법: 예제를 그대로 입력해 방어선을 재현했다.`
  - 004: briefing `인수인계 문서에 구멍이 났다. 빈칸 앞뒤로 코드는 멀쩡하다. 무엇이 들어가야 하는지, 문맥이 말해주고 있다.` / postmortem `코드 리뷰의 절반은 빈칸 메우기다 — 전체를 다 알지 못해도 문맥으로 부분을 추론한다. 실무의 해법: 주변 코드의 의도를 읽기. 이 판의 해법: 빈칸에 들어갈 표적 지정을 채워 가장 가까운 적을 잡았다. 보상으로 받은 캐시는 아껴 쓰자.`
  - 005: briefing `같은 값을 매번 다시 계산하는 코드를 발견했다. 서버가 아깝다. 한 번 찾고, 담아두고, 재사용하라.` / postmortem `DRY — 같은 것을 두 번 쓰지 마라. 변수는 가장 작은 캐시다. 실무의 해법: 반복 계산을 변수에 담아 재사용. 이 판의 해법: nearest()를 변수에 담아 매 틱 재사용했다.`
  - 006: briefing `새벽 3시, 알람이 로그를 가리킨다 — 널 포인터 러시다. 프린터 화력으로는 역부족. 위층의 전문가(스나이퍼)를 불러야 하는데, 그 전에 컴파일러부터 세워야 한다.` / postmortem `토니 호어의 "10억 달러짜리 실수" — 널은 조건문으로 막는 것이 정석이다. 실무의 해법: 가드절, 널 체크. 이 판의 해법: 컴파일러로 테크를 열고 스나이퍼로 길목을 끊었다. 조건문은 널을 거르는 체와 같다.`
  - 007: briefing `적이 흩어져 온다. 하나만 보고 있으면 나머지를 놓친다. 전부 살펴야 한다 — 하나도 빠짐없이, 매 틱.` / postmortem `순회는 전수 점검이다 — O(n)의 정직함. 실무의 해법: 루프로 모든 케이스를 훑고 최적 대상을 고르기. 이 판의 해법: for로 전 적을 순회해 최적 표적을 골랐다.`
  - 008: briefing `on_tick이 스파게티가 됐다. 사수의 마지막 메모: "함수로 쪼개라. 이름이 곧 문서다."` / postmortem `작은 함수, 한 가지 일 — 관심사 분리의 시작. 실무의 해법: 로직을 이름 있는 함수로 추출해 재사용. 이 판의 해법: 표적 선정을 함수로 분리해 on_tick을 한 줄로 만들었다. 함수 사전에 네 이름이 남는다.`
  - 009: briefing `이번 미로는 유효 사거리가 좁다. 아무 데나 세우면 화력이 샌다. 제약이 심할수록, 자리 하나가 승부를 가른다.` / postmortem `제약 하 최적화 — 자원이 부족할 땐 병목에 집중한다. 실무의 해법: 프로파일링으로 병목을 찾아 화력을 모으기. 이 판의 해법: 반복과 조건으로 소수의 명당에서 최대 화력을 냈다.`
  - 010: briefing `스쳐 간 적을 또 처음부터 계산하고 있다. 기록이 필요하다 — 상태를 남기는 자가 흐름을 지배한다.` / postmortem `자료구조는 기억이다 — 테이블에 남긴 상태가 다음 판단을 빠르게 한다. 실무의 해법: 캐시·로그·상태 테이블. 이 판의 해법: 테이블로 표적 상태를 기록하며 중복 계산을 없앴다.`
  - 011: briefing `온콜 야간 근무. 배운 것 전부가 한꺼번에 필요한 밤이다. 변수, 조건, 반복, 함수, 테이블 — 도구는 다 있다.` / postmortem `종합 대응 — 실무 장애에는 단일 정답이 없고, 배운 도구의 조합이 있을 뿐이다. 실무의 해법: 기본기의 조합. 이 판의 해법: 지금까지의 모든 개념을 엮어 밀려드는 조각을 처리했다.`
  - 012: briefing `최종 시험. 분할 지점이 여러 곳이다 — 하나라도 비우면 뚫린다. 이 방을 지켜낸 기록이 곧 네 포트폴리오다.` / postmortem `장애는 끝이 아니라 문서의 시작이다 — 포스트모템 문화는 같은 사고를 두 번 겪지 않기 위해 존재한다. 실무의 해법: 회고를 남기고 시스템을 고친다. 이 판의 해법: 모든 분할 지점을 덮는 배치. 수고했다, 이제 서버는 네가 지킨다.`
- [ ] **Step 4: stages.csv lore_file 칼럼 연결(12행), db.lua 로드+validate, 스위트 통과 후 커밋** — `codedefense: 스테이지 lore 데이터 12편 + 적 유래`

### Task 5: 네러티브 뷰 — 브리핑 문단·포스트모템 카드·도감 유래·문서

**Files:**
- Modify: `love2d-codedefense/states/play.lua` (브리핑 카드 + BUILTIN_DOCS demolish), `love2d-codedefense/states/result.lua` (포스트모템), `love2d-codedefense/states/codex.lua` (origin 줄), `love2d-codedefense/README.md`, `love2d-codedefense/CLAUDE.md`

**Interfaces:**
- Consumes: d.stages[id].lore_file 로드 결과(play enter 시 dofile 아닌 love 없는 io 로드 — db 로드 방식과 동일하게), ctx(result), Task 1 demolish
- Produces: 완성된 Wave A

- [ ] **Step 1: 브리핑 문단** — 문제 카드 상단에 briefing(회색 서사체, printf 줄바꿈, 카드 높이 +필요분). lore 없으면 기존 그대로
- [ ] **Step 2: 포스트모템 카드** — result 클리어 화면에서 Enter 1회차: 포스트모템 카드 표시(제목 "포스트모템 #스테이지번호", 본문 postmortem, "Enter 닫기"), Enter 2회차: 기존 동작(스테이지 선택). R 재도전은 카드 열림 여부와 무관하게 동작. 패배 시 카드 없음. lore 없으면 바로 기존 동작
- [ ] **Step 3: 도감 origin** — 몬스터 카드 desc 아래 `유래: ...` (회색, printf)
- [ ] **Step 4: BUILTIN_DOCS demolish 카드** — 시그니처 `demolish("이름")`, 환불 50%, "스크립트에 build가 남아 있으면 다음 저장 때 재건설된다" 함정 명시
- [ ] **Step 5: README/CLAUDE.md 갱신** — 새 조작(Ctrl+5, demolish, R 재도전, Ctrl+L 등 이번 회차 전체)과 별점·포스트모템 설명. 구구 스포일러 금지 규칙 준수(README에 구구 상세 금지)
- [ ] **Step 6: 스위트 + 스크린샷(브리핑·포스트모템·origin·demolish 카드) 검증 후 커밋** — `codedefense: 네러티브 표시 + 문서 갱신`

### 마무리

- [ ] 전 스위트 + 데이터 회귀(전 스테이지 솔루션 클리어) 확인
- [ ] fable 최종 리뷰(브랜치 diff) → 수정 웨이브 → 재리뷰
- [ ] tools/package.ps1 재실행으로 dist 갱신
