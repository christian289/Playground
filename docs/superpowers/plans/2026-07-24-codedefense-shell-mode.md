# Code Defense Wave D(셸 진영) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 승인된 Wave D 스펙(2026-07-23-codedefense-shell-mode-design.md) 구현 — 별도 셸 진영(진영 선택 화면), 터미널 패널, 셸 명령 9종+ps1 별칭, 타워 표적 전략 4종(autoAttack), cron 결정론 자동화, 셸 스테이지 101~106, 외부 제어를 위한 순수 파서 분리.

**Architecture:** `src/shell.lua` 신규 순수 모듈("문자열 in → 문자열 out", love 금지)이 명령을 해석해 battle API를 호출. battle은 `opts.autoAttack`+표적 전략으로 확장(Lua 진영 경로 불변). 뷰는 `ui == "shell"`일 때 에디터 대신 터미널 패널. 스테이지는 CSV 데이터로만(101~106), 솔루션은 `.sh` 명령 시퀀스를 회귀 러너가 시작 시 한 줄씩 exec.

**Tech Stack:** LÖVE 11.5 / LuaJIT. 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` (현재 523 pass 기준).

## Global Constraints

- 모든 사용자 향 문구·오류·로그는 한글(명령어 자체는 bash 어휘 — `command not found` 등 셸 밈 관용구는 예외로 영문 유지 가능하되 설명부는 한글).
- `src/shell.lua`·battle 확장은 순수 Lua — love API/love.timer 금지. 시간은 battle clock.
- **Lua 진영 시뮬 결과 불변**: autoAttack은 `opts.autoAttack == true`(셸 스테이지)에서만. 전 스테이지(1~20) solution/naive 회귀가 증명.
- **결정론**: cron `nextAt = 등록 clock + interval` 산술(등록 시각 기준), 실행 순서는 등록 id 순. 전략 타이브레이크는 항상 "먼저 스폰된 적"(스폰 순 인덱스). 은신(phase) 적은 모든 전략에서 제외(기존 스냅샷 규칙과 동일).
- 표적 전략 정의: `nearest`=거리 최소 / `oldest`=age 최대 / `strongest`=현재 hp 최대 / `first`=서버라인 진행도 최대(플로우 필드상 잔여 거리 최소). 셸 타워 기본 전략 `nearest`.
- 명령 오류 형식: 미지 명령 `command not found: <입력>` + 레벤슈타인 거리 1 이내 후보가 있으면 ` — '<후보>'를 의미했나요?` 붙임. 인자 오류 `usage: build <타워> <행> <열> <이름>` 식(명령별 usage 문자열).
- cron 최소 간격 1.0초(미만 입력 시 `[오류] 간격은 1초 이상이어야 합니다`). 터미널 출력 버퍼 상한 200줄, 명령당 출력 20줄 초과 시 `…외 n건` 절단.
- 진영 선택·스테이지 언락: 셸 진영 언락은 **진영 내 이전 스테이지** 클리어 기준(전역 id-1 참조 금지 — 101이 영구 잠기는 기존 위험, stageselect 언락 로직을 진영 목록 순서 기준으로 정리하고 Lua 진영 동작 불변 확인).
- 기존 테스트 523개 전체 통과 유지. 커밋마다 스위트 실행. 폰트 글리프 주의(`$` 프롬프트 등 렌더 확인).
- 스크린샷: captureScreenshot(callback)+io 절대경로(스크래치패드) 후 Read 판독.

---

### Task 1: 코어 — 표적 전략 + autoAttack (battle 확장)

**Files:**
- Modify: `love2d-codedefense/src/battle.lua`, `love2d-codedefense/src/api.lua`(필요 시 스냅샷 헬퍼 재사용)
- Test: `love2d-codedefense/tests/test_shell.lua` (신규, tests/main.lua 등록 — 이 태스크에선 전략/autoAttack 부분만)

**Interfaces:**
- Consumes: 기존 Battle(d, stageId, opts), 타워 사거리/쿨다운/resolveAttack, phase 은신 규칙(isPhased).
- Produces: `Battle:setTargetStrategy(name, strat)` → bool(타워 없으면 false+한글 로그 `[오류] 타워가 없습니다 — "<이름>"`), `tw.strategy` 필드(기본 "nearest"), `opts.autoAttack = true`면 스크립트 없이 매 틱 각 타워가 전략대로 기본 공격 — Task 2 shell·Task 4 러너가 사용

- [ ] **Step 1: 실패 테스트 작성** — test_shell.lua(전략 절): ① 고정 배치(적 3기: 가까운 신입/오래된 원거리/고HP 원거리)에서 nearest/oldest/strongest/first 각각이 정의된 표적을 선택 ② 동률 시 먼저 스폰된 적 선택 ③ 은신(phase) 적은 어느 전략에서도 선택되지 않음 ④ autoAttack=false(기존 Lua 스테이지)에서는 스크립트 없는 타워가 공격하지 않음(기존 동작 불변) ⑤ setTargetStrategy 미존재 타워 → false+한글 로그, 잘못된 전략명 → false+`[오류] 알 수 없는 전략 — "<입력>" (nearest/oldest/strongest/first)`
- [ ] **Step 2: 실행해 실패 확인**
- [ ] **Step 3: 구현** — 전략 선택 함수는 battle 내부에서 적 목록을 직접 순회(스폰 순 안정 정렬 전제, isPhased 제외). `first`는 grid 플로우 필드의 잔여 거리를 사용(기존 flow 자료 재사용 — 필드명은 grid.lua에서 확인). autoAttack 루프는 runTick에서 스크립트 경로와 배타 분기(셸 타워는 on_tick 없음). 쿨다운·오버클럭·투사체 생성은 기존 resolveAttack 경로 재사용.
- [ ] **Step 4: 전체 스위트 통과** — 523 + 신규 ≥5 (Lua 회귀 전체 포함)
- [ ] **Step 5: 커밋** — `codedefense: 타워 표적 전략 4종 + autoAttack(코어)`

### Task 2: 코어 — src/shell.lua 파서·명령 9종·별칭·cron

**Files:**
- Create: `love2d-codedefense/src/shell.lua`
- Test: `love2d-codedefense/tests/test_shell.lua` 확장

**Interfaces:**
- Consumes: Task 1의 setTargetStrategy/autoAttack, 기존 buildTower/demolishTower/serverHP/money/kills/enemies/log.
- Produces: `Shell.new(battle)` → `shell:exec(line)` → `{ ok = bool, output = {줄...} }`, `shell:tick(clock)`(cron 실행), `shell.history`(문자열 배열), `shell.cronJobs` — Task 3 터미널·Task 4 러너가 사용

- [ ] **Step 1: 실패 테스트 작성** — ① 토크나이저: 따옴표 인자(`cron 2 "target a nearest"`) 분리, 공백 다중 처리 ② build: `build printer 3 4 a` → battle에 타워 생성(비용 차감·기존 한글 로그), 인자 부족 → usage 출력 ③ rm: 철거+환불(Wave A demolish 경로), 미존재 → 기존 한글 오류 ④ ls / ls enemies / top / history / clear 출력 포맷(각 1건 스냅샷 단언 — 형식은 Step 3 참조) ⑤ target: 전략 지정 반영(tw.strategy 변경), 오류 전파 ⑥ cron: 등록 → `shell:tick`이 nextAt 도달 시 명령 실행(결정론: 같은 등록 시각·간격이면 실행 시각열 동일 단언), `cron -l` 목록, `cron -r <id>` 삭제, 간격<1 거부 ⑦ 오타 제안: `buld` → `command not found: buld — 'build'를 의미했나요?`, 거리 2 이상은 제안 없음 ⑧ ps1 별칭: `Remove-Item a`→rm, `dir`→ls, `Get-Process`→ls enemies, `Get-Content build`→man build 라우팅 + 최초 1회 `PowerShell 사용자를 환영합니다` 출력 ⑨ 출력 절단: 21줄 이상 출력 명령 → 20줄+`…외 n건`
- [ ] **Step 2: 실행해 실패 확인**
- [ ] **Step 3: 구현** — 명령 테이블(name → {run, usage, doc}). 출력 포맷(정확히): ls 타워당 `"<이름>" <타워 표시명> (r,c) · 전략 <strat>`, 빈 목록 `배치된 타워가 없습니다`; ls enemies 적당 `<표시명> HP <n> (r,c)`(스폰 순, 은신 제외), 빈 목록 `필드에 적이 없습니다`; top 한 줄 `서버 HP <n> · 잔액 $<m> · 처치 <k>/<total> · 배속 x<%g>`(배속은 battle이 모름 — exec 호출부가 넘기는 opts로, 없으면 생략); man은 `{ ok=true, open="<명령>" }`처럼 뷰가 소비할 신호 필드 반환(순수성 유지 — 뷰 직접 호출 금지); history 번호 매김 `1  build ...`; clear는 `{ clear = true }` 신호. cron 실행 출력은 `[cron#<id>] <명령>` 접두로 버퍼에 남김.
- [ ] **Step 4: 전체 스위트 통과** (Task 1 분 포함 test_shell 전체)
- [ ] **Step 5: 커밋** — `codedefense: 셸 파서·명령 9종·cron(코어)`

### Task 3: 뷰 — 진영 선택·터미널 패널·man 연동·언락 정리

**Files:**
- Modify: `love2d-codedefense/states/title.lua`(또는 신규 `states/faction.lua` — 기존 상태 흐름 패턴 따름), `love2d-codedefense/states/stageselect.lua`, `love2d-codedefense/states/play.lua`
- Test: 기존 스위트 회귀 + 스크린샷

**Interfaces:**
- Consumes: Task 2 shell 모듈, d.stages[].languages/ui, 기존 에디터 위젯의 한 줄 입력 프리미티브, BUILTIN_DOCS/drawDictCard.
- Produces: 진영 선택 화면(Lua/Shell), stageselect 진영 필터+진영 내 언락, `ui=="shell"` 터미널 패널 — Task 4 스테이지가 사용

- [ ] **Step 1: 진영 선택** — 타이틀 "게임 시작" → 진영 선택 상태(2항목: `Lua 진영 — 스크립트로 방어한다` / `Shell 진영 — 명령줄로 방어한다`, ↑↓/마우스+Enter/클릭, ESC=타이틀). 선택 결과를 stageselect에 파라미터로 전달. 셸 스테이지가 하나도 없으면(데이터 미도입 상태) Shell 항목에 `(준비 중)` 표시+진입 차단 — Task 3 커밋 시점 안전장치.
- [ ] **Step 2: stageselect 진영 필터+언락** — languages 필터(빈 값/`lua`=Lua 진영, `shell`=Shell 진영). 언락을 "진영 내 목록 이전 항목 클리어" 기준으로 변경(전역 id-1 참조 제거) — Lua 진영 결과 불변을 기존 스테이지 목록으로 확인. 기록·별점 표기는 그대로(records 공유).
- [ ] **Step 3: 터미널 패널** — play.lua: `ui=="shell"`이면 에디터 영역에 터미널 렌더 — 출력 버퍼(스크롤, 최근 줄 하단), 프롬프트 줄 `$ ` + 입력(UTF-8, 기존 에디터 입력 프리미티브 재사용), Enter=shell:exec(출력을 버퍼에 append, clear 신호 처리, man 신호 → dictOpen), ↑↓=history 네비, 마우스 휠=버퍼 스크롤. F5/퀵바/Ctrl+L 비활성. 힌트바 셸 전용 문구: `Enter 실행 · ↑↓ 이력 · man <명령> 도움말 · Ctrl+5/1/2/4 배속 · ESC 포기`. play update에서 `shell:tick(battle.clock)` 동기 호출. top의 배속 표기는 exec 호출 opts로 전달.
- [ ] **Step 4: BUILTIN_DOCS 셸 카드 9종** — build(기존 카드 재사용)/demolish(기존) 외 신규: rm(`rm <이름>` — 철거+환불 50%, demolish와 동일 코어), ls(`ls [enemies]` — 내 타워/필드 적 목록), top(서버 상태 요약 1회), target(`target <이름> <전략>` — nearest/oldest/strongest/first, 수치 조작 불가), cron(`cron <초> "<명령>"` — 주기 예약, `-l` 목록 `-r` 삭제, battle 시계 기준 결정론), man(함수 사전 열기), history(이력), clear(화면 지우기). 각 카드 lines는 한글 1~2줄.
- [ ] **Step 5: 스위트(회귀) + 스크린샷** — 진영 선택 화면·터미널(명령 실행 결과 보이는 상태)·오타 제안 출력·man으로 열린 카드 각 1장 Read 판독 후 커밋 — `codedefense: 진영 선택·터미널 패널(뷰)`

### Task 4: 데이터 — 셸 스테이지 101~106 + validate/러너 확장

**Files:**
- Modify: `love2d-codedefense/data/stages.csv`, `love2d-codedefense/data/timelines.csv`, `love2d-codedefense/src/db.lua`(validate: ui=shell → solution_file `.sh` 존재 검사), `love2d-codedefense/tests/test_battle.lua`(러너: ui=shell 스테이지는 solution `.sh`를 시작 시 한 줄씩 shell:exec 후 300초 시뮬 — 클리어 단언)
- Create: `love2d-codedefense/data/mazes/101.txt`~`106.txt`, `love2d-codedefense/data/curriculum/101_solution.sh`~`106_solution.sh`, `love2d-codedefense/data/curriculum/tutorial_101.lua`, `love2d-codedefense/data/lore/101.lua`~`106.lua`

**Interfaces:**
- Consumes: Task 1~3 전부.
- Produces: 셸 진영 커리큘럼 6종 완성 — 회귀 자동 편입

- [ ] **Step 1: 스테이지 설계** — id 101~106, languages `shell`, ui `shell`, theme `터미널`(101~103)·`파이프라인`(104~106), 미로는 죽은 슬롯 금지·6장 상이·12×16·건설칸 ≥6, 타임라인 240s/≤39s/countdown 20~30 (기존 규칙 전부). 적 구성: 101~103 bug/null-ptr, 104 concat-nil 혼합, 105 물량(주기 러시), 106 **deadlock 쌍 포함** 종합(target 분산 없이는 패배하는 예산 설계 — 수동 반례 검증). 개념(concept) 칼럼: 101 `ls`, 102 `rm`, 103 `top`, 104 `man·target`, 105 `cron`, 106 `종합 시험`.
- [ ] **Step 2: 솔루션 .sh 6개** — 명령 시퀀스(시작 시 일괄 exec로 클리어 가능해야 함 — target/cron이 지속 효과이므로 성립). 예: 106은 `build`×n + `target a oldest`/`target b nearest` 분산 + `cron 5 "top"`(모니터링 데모). 각 예산 내. validate와 러너가 기계 검증.
- [ ] **Step 3: tutorial_101.lua** — 기존 tutorial 스키마로 5스텝(전부 한글, allow로 입력 잠금 단계 포함): ① `여기는 셸 진영. 코드 대신 명령줄로 서버를 지킨다.`(allow={}) ② `ls 를 입력하고 Enter — 내 타워 목록을 본다.` ③ `build printer 4 3 a 로 첫 타워를 세운다. 인자 순서: 타워 행 열 이름.` ④ `ls enemies 로 적을 정찰한다.` ⑤ `이제 방어를 완성하라. man build 로 언제든 문서를 열 수 있다.`
- [ ] **Step 4: lore 6편 작성(전문 그대로, 스키마 동일)**
  - 101 briefing `첫 야간 온콜. 선배가 남긴 건 IDE가 아니라 검은 터미널 하나. "GUI는 죽었다. 여기선 명령이 곧 손이다."` / postmortem `셸은 가장 오래된 개발자 인터페이스이자 가장 빠른 손이다. 실무의 해법: ls부터 — 보이지 않으면 고칠 수 없다. 이 판의 해법: ls로 상황을 보고 build 한 줄로 방어선을 세웠다.`
  - 102 briefing `어제 세운 타워가 길목을 비켜나 있다. 지우고 다시 — 터미널에서는 실수도 한 줄이면 복구된다.` / postmortem `rm은 되돌릴 수 없다지만, 이 서버실의 rm은 환불이 된다. 실무의 해법: 실험 비용을 낮춰 빠르게 반복하기. 이 판의 해법: rm으로 철거하고 더 나은 자리에 다시 세웠다.`
  - 103 briefing `상황판 없는 방어는 감이다. top 한 번이면 서버의 심박이 보인다.` / postmortem `모니터링은 대응보다 먼저다 — 보이는 장애만 고칠 수 있다. 실무의 해법: 대시보드와 지표. 이 판의 해법: top과 ls enemies로 판세를 읽고 배치를 조정했다.`
  - 104 briefing `문서를 안 읽는 자, 같은 명령을 두 번 틀린다. man을 열어라 — 답은 대부분 거기 있다.` / postmortem `RTFM은 무례한 말이 아니라 생존 기술이다. 실무의 해법: 공식 문서 먼저. 이 판의 해법: man으로 target 문법을 확인하고 타워마다 전략을 지정했다.`
  - 105 briefing `매번 손으로 치던 명령을 시계에게 맡긴다. 크론은 잠들지 않는다.` / postmortem `자동화의 첫걸음은 반복의 발견이다. 실무의 해법: crontab — 사람은 판단을, 기계는 반복을. 이 판의 해법: cron으로 주기 명령을 걸어 손을 풀었다.`
  - 106 briefing `종합 시험. 데드락 쌍이 몰려온다 — 한 놈만 패면 풀리지 않는다. 네 터미널의 모든 명령이 답안지다.` / postmortem `좋은 운영자는 도구를 조합한다 — 정찰, 배치, 전략, 자동화. 실무의 해법: 원라이너의 미학. 이 판의 해법: target 분산으로 쌍을 동시에 끊고 cron으로 감시를 자동화했다. 셸은 이제 네 손의 연장이다.`
- [ ] **Step 5: validate 확장** — ui=shell이면 solution_file 확장자 `.sh`+존재 검사(오류 문구 한글 `솔루션(.sh) 파일 없음`), lore/미로/타임라인 기존 검사 그대로 적용됨 확인. 러너 확장: ui=shell 분기(autoAttack Battle 생성 → .sh 줄 단위 exec → 300s 시뮬 → 클리어 단언). 106 반례(단일 전략) 수동 검증 기록.
- [ ] **Step 6: 전체 스위트 + 부팅 스모크 후 커밋** — `codedefense: 셸 스테이지 101~106 + 러너 확장`

### Task 5: 통합 검증 + 문서

**Files:**
- Modify: `love2d-codedefense/README.md`, `love2d-codedefense/CLAUDE.md`
- Test: 전체 스위트 + 스크린샷

- [ ] **Step 1: 통합 스크린샷** — 진영 선택 → 셸 스테이지 목록 → 101 튜토리얼 말풍선+터미널 → 106 데드락 전투 중 터미널(target 분산 로그) → 클리어 포스트모템 카드, 각 Read 판독.
- [ ] **Step 2: CLAUDE.md 갱신** — 셸 진영 구조(진영 선택·languages/ui 칼럼·101번대 id·진영 내 언락), src/shell.lua 계약(exec/tick/신호 필드), 명령 표(문법·출력 포맷·별칭·오타 제안·cron 결정론), autoAttack/전략 4종 정의(타이브레이크·은신 제외), .sh 솔루션 러너, 외부 제어 어댑터는 다음 회차(설계 고정) 명시. README — 셸 진영 소개(스포일러 규칙 유지), 테스트 수 갱신.
- [ ] **Step 3: 전체 스위트 + 부팅 스모크 후 커밋** — `codedefense: Wave D 문서 갱신`

### 마무리

- [ ] 전 스위트 + 데이터 회귀(Lua 20 + 셸 6 전 스테이지) 확인
- [ ] fable 최종 리뷰(Wave D diff) → 수정 웨이브 → 재리뷰
- [ ] tools/package.ps1 재실행으로 dist 갱신, 푸시
