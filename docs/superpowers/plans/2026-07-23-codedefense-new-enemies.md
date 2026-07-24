# Code Defense Wave B(신규 적·타워) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 승인된 Wave B 스펙(2026-07-23-codedefense-new-enemies-design.md) 구현 — 신규 적 7종+커널 패닉, 신규 타워 2종(GC 수집기/디버거), 신규 스테이지 13~20, world API 확장(age/speed/oldest), 로어·origin·문서.

**Architecture:** 능력은 전부 코어(src/enemy.lua, src/battle.lua, src/api.lua)에 결정론(스폰 시각 기준 고정 주기)으로 구현하고 헤드리스 테스트 동반. 적/타워/스테이지는 CSV+데이터 파일로만 추가. 아트는 src/art.lua 코드 생성(외부 에셋 금지). 뷰(states/)는 스크린샷 검증.

**Tech Stack:** LÖVE 11.5 / LuaJIT. 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` (현재 316 pass 기준).

## Global Constraints

- 모든 사용자 향 문구·오류·로그는 한글. 코어(src/)는 love API 금지(순수 Lua), `love.timer` 금지 — 시간은 battle clock/틱 기반.
- **결정론**: 모든 주기 행동은 스폰 시각 기준. 상수(코어에 정의): `GROW_EVERY=1.0`s·`GROW_AMOUNT=2`·상한 기본 maxHP×5 / `PHASE_VISIBLE=3.0`s·`PHASE_HIDDEN=2.0`s / `DASH_PERIOD=1.5`s·`DASH_LEN=0.3`s·`DASH_MULT=3` / pair 경감 시 데미지 ×`0.4` / resist:printer 데미지 ×`0.5` / splash 반경 `60`px·가장자리 감쇠 `50%` 선형 / slowfield 이동 ×`0.6`·중첩 불가.
- **신규 능력 경로(resist·splash)의** 데미지 계산 결과는 `math.max(1, math.floor(x))` (0데미지 금지). 기존 데미지 파이프라인(charge 배율)은 비정수 그대로 두며 전역 floor 금지 — "기존 스테이지 시뮬 결과 불변"이 우선한다(Task 2 리뷰 판정).
- abilities CSV 표기: `grow`, `pair`, `phase`, `split2`, `dash`, `resist:printer` (`;` 조합, 콜론=대상 지정). 미지의 키워드는 조용히 무시 — **알려진 예외**: 기존 `battle.lua`의 `(abilities):find("split")` 부분 문자열 검사가 `split2`를 오탐한다(Task 1 검증에서 발견). Task 2가 `;` 분리 **토큰 완전 일치** 파서로 교체해 해소하며, 그 전까지 fork-bomb/kernel-panic은 어느 스테이지 타임라인에도 없어 시뮬 영향 0.
- 신규 스테이지 규칙(기존 CLAUDE.md 그대로): 12×16 미로·건설칸 ≥6, `solution_file` 필수(회귀가 클리어 증명), naive_file은 반드시 패배, 마지막 스폰 종료 ≥240s·이벤트 공백 ≤40s(경계값 금지 — 여유 ≥1s), `countdown` 15~30, `theme`/`problem`/`lore_file` 채움.
- **미로 설계 규칙(Task 5 리뷰 반영)**: 모든 건설칸(B)은 스폰이 실제 지나는 경로를 사거리로 교전할 수 있어야 한다 — 영구 무기능 장식 슬롯 금지(world.oldest()가 사거리 무시 전역 판정이므로 유휴 레인은 배치 함정이 된다). 같은 테마 3장은 서로 다른 미로여야 한다(기존 관례). 다분기 형태(평행 차선·허브-스포크)는 스폰 경로가 실제로 지나는 가지에만 건설칸을 둔다.
- 스탯 수치는 전부 CSV로(코어 하드코딩 금지). 절대값은 기존 bug/concat-nil 행을 기준으로 한 상대 규칙(각 태스크에 명시)으로 정하고, 회귀 통과를 완료 조건으로 조정 가능(조정 시 보고서에 기록).
- 기존 테스트 316개 전체 통과 유지. 커밋마다 스위트 실행.
- 폰트 글리프 주의(NanumGothic): 새 특수문자는 렌더 확인. 스크린샷은 captureScreenshot(callback)+io로 스크래치패드 절대경로 저장 후 Read 판독.

---

### Task 1: 데이터+아트 — 적 8종·타워 2종 CSV + 스프라이트 + 도감

**Files:**
- Modify: `love2d-codedefense/data/enemies.csv`, `love2d-codedefense/data/towers.csv`, `love2d-codedefense/src/art.lua`
- Test: 기존 스위트 회귀(로직 무변경) + 도감 스크린샷

**Interfaces:**
- Produces: enemies.csv 신규 id `memory-leak`/`deadlock`/`heisenbug`/`fork-bomb`/`race-cond`/`legacy`/`ddos-bot`/`kernel-panic` (abilities 문자열 포함 — 엔진은 아직 미해석·무시됨), towers.csv 신규 id `gc-collector`(ability `splash`, cost 180, requires compiler)/`debugger`(ability `slowfield`, cost 80, requires 없음, limit 2), art 시트 `enemy_<id>` 8종·`tower_<id>` 2종 — Task 2~7이 사용

- [ ] **Step 1: enemies.csv 8행 추가.** 표시명·유래(origin)·색은 아래 그대로, 수치는 상대 규칙(기존 bug 행 값을 B라 표기: HP=B.hp, SPD=B.speed, RWD=B.reward):
  - memory-leak 메모리 릭 — hp B×3, speed B×0.4, reward B×3, abilities `grow`, color `0.55;0.9;0.5`, origin `할당한 메모리를 해제하지 않으면 프로세스가 죽을 때까지 몸집이 불어난다. 새는 것은 물이 아니라 기억이다`
  - deadlock 데드락 — hp B×2, speed B×0.8, reward B×2, abilities `pair`, color `0.5;0.65;0.95`, origin `1965년 다익스트라의 '식사하는 철학자' 문제가 정식화했다. 서로가 서로의 락을 기다리며 아무도 움직이지 못한다`
  - heisenbug 하이젠버그 — hp B×1.5, speed B×1.0, reward B×2, abilities `phase`, color `0.75;0.55;0.95`, origin `관측하려 하면 사라진다 — 하이젠베르크의 불확정성 원리에서 딴 이름. 디버거를 붙이면 재현되지 않는 버그를 모든 개발자가 안다`
  - fork-bomb 포크 밤 — hp concat-nil×1.5, speed concat-nil×1.0, reward concat-nil×1.5, abilities `split2`, color `0.95;0.6;0.2`, origin `":(){ :|:& };:" — 13글자로 시스템을 마비시키는 가장 유명한 셸 한 줄. 자기복제는 지수적으로 번진다`
  - race-cond 레이스 컨디션 — hp B×1, speed B×1.2, reward B×1.5, abilities `dash`, color `0.95;0.85;0.3`, origin `두 스레드가 같은 값에 동시에 손을 대면 결과는 실행 순서에 달린다. 테스트에선 통과하고 금요일 배포에서 터진다`
  - legacy 레거시 코드 — hp B×8, speed B×0.3, reward B×6, abilities `resist:printer`, color `0.7;0.55;0.35`, origin `문서도 없고 작성자도 퇴사했지만 매출은 이 코드에서 나온다. 아무도 건드리려 하지 않는다`
  - ddos-bot DDoS 봇 — hp 5(절대값), speed B×2.0, reward 1(절대값), abilities 빈 값, color `0.95;0.35;0.35`, origin `2016년 미라이 봇넷은 감염된 IoT 기기 수십만 대로 인터넷 절반을 마비시켰다. 하나하나는 하찮지만 물량이 곧 화력이다`
  - kernel-panic 커널 패닉 — hp legacy×2, speed B×0.35, reward legacy×2, abilities `grow;split2`, color `0.9;0.3;0.7`, origin `커널이 복구 불능 오류를 만나면 모든 것을 멈추고 화면에 유언을 남긴다. 서버실의 모든 악몽이 여기서 합쳐진다`
  - CSV 인용 규칙 준수(쉼표·따옴표 포함 셀은 `"..."`+`""` 이스케이프 — null-ptr origin 전례).
- [ ] **Step 2: towers.csv 2행 추가.** (P=printer 행 기준)
  - gc-collector GC 수집기 — cost 180, damage P×0.6, range P×0.9, cooldown P×1.2, bullet_speed P×1.0, requires `compiler`, limit 빈 값, ability `splash`, color `0.4;0.8;0.6`, desc `광역 수거 타워. 명중 지점 주변까지 함께 청소한다. 물량에는 물량의 논리로`
  - debugger 디버거 — cost 80, damage 0, range P×1.1, cooldown 빈 값 무해하면 빈 값·아니면 P 값 복사, bullet_speed 0, requires 빈 값, limit 2, ability `slowfield`, color `0.35;0.75;0.95`, desc `공격하지 않는다. 사거리 안의 모든 적에게 브레이크포인트를 걸어 발을 늦춘다 (스테이지당 2기)`
- [ ] **Step 3: art.lua 스프라이트 10종.** 16×16 도트, `art.pal` 톤 준수, 기존 `enemy_*`/`tower_*` 시트 빌드 패턴 그대로: 메모리 릭=부풀어 오르는 물방울+게이지, 데드락=서로 맞물린 자물쇠 2개, 하이젠버그=반투명 유령(물음표), 포크 밤=포크 모양 스파크+도화선, 레이스 컨디션=번개 꼬리 달린 주자, 레거시 코드=먼지 쌓인 거미줄 상자, DDoS 봇=미니 드론 떼(단일 스프라이트는 작게), 커널 패닉=깨진 화면(BSOD 청색+적색 균열), GC 수집기=쓰레기통+집게 팔, 디버거=돋보기+일시정지 막대 2개. 각 draw 헬퍼 끝 `setColor(1,1,1)` 복원.
- [ ] **Step 4: 전체 스위트 실행** — 316 pass 유지(로직 무변경 확인). 부팅 스모크(lovec 실행 → 즉시 종료)로 d.validate 통과 확인.
- [ ] **Step 5: 도감 스크린샷 검증** — 몬스터 탭에 신규 8종 카드(스프라이트+origin 줄), 타워 탭에 2종. 스크래치패드 저장 후 Read 판독.
- [ ] **Step 6: 커밋** — `codedefense: 신규 적 8종·타워 2종 데이터+스프라이트`

### Task 2: 코어 능력 팩 1 — grow·dash·resist + 스냅샷 age/speed + world.oldest

**Files:**
- Modify: `love2d-codedefense/src/enemy.lua`, `love2d-codedefense/src/battle.lua`, `love2d-codedefense/src/api.lua`
- Test: `love2d-codedefense/tests/test_abilities.lua` (신규, tests/main.lua 등록)

**Interfaces:**
- Consumes: Task 1의 CSV abilities 문자열. 기존 Battle 틱 구조·스냅샷 빌더(api.lua).
- Produces: `e.age`(스폰 후 초, battle clock 기반)·`e.spawnedAt`, 적 스냅샷 필드 `age`/`speed`(실효 px/s), `world.oldest()`(age 최대, 동률 시 먼저 스폰), abilities 파서 헬퍼(`resist:printer`처럼 콜론 인자 지원) — Task 3·4가 재사용

- [ ] **Step 1: 실패 테스트 작성** — test_abilities.lua: ① grow: 스폰 3초 경과 시 maxHP=기본+6·hp도 +6, 상한 ×5 도달 후 불변 ② dash: age 0.1s(대시 창)에서 실효 speed=기본×3, age 0.5s(창 밖)에서 기본×1 — 틱 단위 결정론 확인 ③ resist:printer: printer 데미지 절반(floor·min1), sniper 데미지는 그대로 ④ 스냅샷에 age/speed 존재·값 일치 ⑤ world.oldest()가 먼저 스폰된 적 반환, 적 없으면 nil
- [ ] **Step 2: 실행해 실패 확인**
- [ ] **Step 3: 구현** — abilities 파서: `;` 분리 후 **토큰 완전 일치**(콜론 인자 지원, 예: `resist:printer` → name=`resist`, arg=`printer`). 기존 `(abilities):find("split")` 부분 문자열 검사(battle.lua ~267행 등 전체 검색)를 이 파서 기반 완전 일치로 교체 — `split2` 오탐 해소(기존 `split` 동작은 불변, 회귀로 확인). enemy 이동에 실효 속도 계산 훅(대시·감속을 한 곳에서 곱셈 — Task 3 slowfield가 같은 훅 사용), battle 데미지 적용부에 resist 계수, 스폰 시 `e.spawnedAt=clock`, grow는 틱 누적으로 1.0s마다 적용. api.lua: 스냅샷에 age/speed 추가, `env.world.oldest` 추가(은신 제외 규칙은 Task 3에서 phase와 함께 — 여기선 전 적 대상).
- [ ] **Step 4: 전체 스위트 통과 확인** — 316 + 신규 ≥5
- [ ] **Step 5: 커밋** — `codedefense: 적 능력 grow·dash·resist + world.oldest(코어)`

### Task 3: 코어 능력 팩 2 — pair·phase·split2 + 결정론 재현

**Files:**
- Modify: `love2d-codedefense/src/enemy.lua`, `love2d-codedefense/src/battle.lua`, `love2d-codedefense/src/api.lua`
- Test: `love2d-codedefense/tests/test_abilities.lua` 확장

**Interfaces:**
- Consumes: Task 2의 abilities 파서·spawnedAt.
- Produces: `e.pairId`/`e.pairAlive` 경감 로직, `e:isPhased(clock)`(스폰 기준 3.0s 가시/2.0s 은신 반복), split2 깊이 상속(`e.splitDepth`, 최대 2) — Task 4 뷰·Task 6~7 스테이지가 사용

- [ ] **Step 1: 실패 테스트 작성** — ① pair: 같은 이벤트 2기 스폰 → 둘 다 생존 시 데미지 ×0.4(floor·min1), 한쪽 사망 즉시 경감 해제. 홀수 스폰 마지막 1기는 경감 없음 ② phase: 스폰 직후(0.0~3.0) 가시, 3.0~5.0 은신 — 은신 중 world.enemies()/nearest()/oldest()에서 제외 + 투사체 명중 무효 + 타워 자동 타겟 제외, 5.0에 재출현. 서버라인 도달은 은신 중에도 판정 ③ split2: 사망 시 hp 절반 2기(깊이1), 깊이1 사망 시 또 2기(깊이2), 깊이2는 분열 없음 — 총 개체 수 검증. reachedByType은 부모 def 기준 ④ 결정론: 같은 스테이지·같은 스크립트 2회 전체 실행 → status·serverHP 완전 일치
- [ ] **Step 2: 실행해 실패 확인**
- [ ] **Step 3: 구현** — pair는 스폰 이벤트 내 홀짝 인덱스로 짝 지정, phase는 clock 산술만(상태 저장 없음 — 결정론), split2는 기존 split 코드 경로를 깊이 파라미터로 일반화(기존 `split`=깊이 1 동작 불변 회귀 확인). api 스냅샷·oldest에 isPhased 필터 추가(Task 2의 oldest에 필터 소급).
- [ ] **Step 4: 전체 스위트 통과 확인** (기존 split 스테이지 회귀 포함)
- [ ] **Step 5: 커밋** — `codedefense: 적 능력 pair·phase·split2 + 결정론 재현(코어)`

### Task 4: 타워 능력 — splash·slowfield(코어) + 뷰 소품

**Files:**
- Modify: `love2d-codedefense/src/battle.lua`, `love2d-codedefense/src/tower.lua`(필요 시), `love2d-codedefense/src/projectile.lua`, `love2d-codedefense/states/play.lua`
- Test: `love2d-codedefense/tests/test_abilities.lua` 확장

**Interfaces:**
- Consumes: Task 2 실효 속도 훅, Task 3 isPhased.
- Produces: splash 명중 처리(반경 60px, 중심 100%→가장자리 50% 선형, 은신 적 면제), slowfield(디버거 사거리 내 ×0.6, 중첩 불가, 디버거는 공격 안 함), BUILTIN_DOCS `world.oldest` 카드 — Task 6~7 스테이지 솔루션이 사용

- [ ] **Step 1: 실패 테스트 작성** — ① splash: 명중점 30px 옆 적이 데미지 ×(1−0.5×30/60)=75% floor 수령, 61px 밖 0, 은신 적 0 ② slowfield: 디버거 사거리 내 적 실효 speed ×0.6, 디버거 2기 겹쳐도 ×0.6 한 번만, 사거리 밖 즉시 원복, dash 중이면 ×3×0.6 ③ 디버거는 발사하지 않음(투사체 0) ④ limit 2 초과 build 실패(기존 limit 경로 — 한글 실패 로그 확인)
- [ ] **Step 2: 실행해 실패 확인**
- [ ] **Step 3: 코어 구현** — splash는 투사체 명중 시 1회 폭발 판정(battle 좌표 기반), slowfield는 Task 2의 실효 속도 훅에 곱셈 참여. 디버거는 타겟팅·발사 루프에서 제외(damage 0이어도 루프를 돌며 낭비하지 않게 ability로 분기).
- [ ] **Step 4: 뷰 소품(play.lua)** — 스플래시 명중 시 particles.burst 링(반경 60 스케일, gc 색), 감속 중인 적에 파란 하단 점(2px, art.pal cyan) 표시, 하이젠버그 은신은 스프라이트 알파 0.25 깜빡임(재출현 0.2s 플래시), BUILTIN_DOCS에 `world.oldest` 카드 추가: sig `world.oldest()`, lines `{ "필드에서 가장 오래 버틴 적의 스냅샷을 반환한다(없으면 nil).", "메모리 릭처럼 시간이 지날수록 강해지는 적은 오래된 것부터 끊어야 싸다." }`, example `local e = world.oldest()`.
- [ ] **Step 5: 전체 스위트 + 오토플레이 스크린샷**(스플래시 링·감속 점·은신 깜빡임·oldest 카드 각 1장, Read 판독)
- [ ] **Step 6: 커밋** — `codedefense: splash·slowfield 타워 능력 + 뷰 소품`

### Task 5: 스테이지 13~16 (스레드×3 + 프로세스 1) — 데이터·로어·회귀

**Files:**
- Modify: `love2d-codedefense/data/stages.csv`, `love2d-codedefense/data/timelines.csv`
- Create: `love2d-codedefense/data/mazes/013.txt`~`016.txt`, `love2d-codedefense/data/curriculum/013_solution.lua`~`016_solution.lua`, `013_hints.lua`, `016_naive.lua`, `love2d-codedefense/data/lore/013.lua`~`016.lua`

**Interfaces:**
- Consumes: Task 1~4 전부(적·타워·능력·API).
- Produces: 스테이지 13~16 (13 메모리 릭/oldest, 14 데드락/표적 분산, 15 하이젠버그/nil 체크, 16 포크 밤/GC·퍼즐) — 회귀 자동 편입

- [ ] **Step 1: 스테이지 설계 값** — theme: 13~15 `스레드`, 16 `프로세스`. 미로: 스레드=평행 차선(가로 2~3레인), 프로세스=격리 구획(방+좁은 문). countdown 20~30. problem 한 줄(코딩테스트 톤, 한글). 타임라인: 마지막 스폰 종료 ≥240s·공백 ≤40s. 16은 `puzzle=1`+`naive_file`(단일 프린터 고화력 배치 — 분열 물량에 반드시 패배).
- [ ] **Step 2: 정답 스크립트 작성·검증** — 13: `world.oldest()` 타겟팅(hints_file 013: 빈칸형 — `local e = world.______()` 안내 주석 `가장 오래 버틴 적부터: oldest`), 14: 타워 2기 이름별 표적 분산(pair 경감 해제 증명), 15: `if e then`/nil 체크 사격, 16: gc-collector 포함 배치. 각 스크립트는 예산 내. 수치(예산·타임라인·적 수)는 회귀 통과까지 조정 가능 — 조정 내역 보고.
- [ ] **Step 3: lore 4편 집필(아래 전문 그대로, 스키마 `return { briefing=..., postmortem=... }`)**
  - 013 briefing `모니터링 그래프가 우상향한다 — 좋은 뜻이 아니다. 메모리 사용량이 내려올 줄을 모른다. 방치하면 어느 순간 서버가 통째로 주저앉는다.` / postmortem `메모리 릭은 시간이 지날수록 비싸진다 — 조기에 잡을수록 싸다. 실무의 해법: 프로파일러로 오래 살아남은 할당부터 추적하기. 이 판의 해법: world.oldest()로 가장 오래 버틴 릭부터 끊었다. 릭은 어릴 때 잡아라.`
  - 014 briefing `두 배치 작업이 새벽 2시부터 멈춰 있다. 로그도 없이, CPU도 조용히. 서로가 서로를 기다리는 중이다.` / postmortem `데드락은 네 가지 조건 중 하나만 깨면 풀린다 — 락 순서 통일이 정석이다. 실무의 해법: 자원 획득 순서를 강제하고 타임아웃을 걸기. 이 판의 해법: 타워 두 기의 표적을 이름으로 갈라 쌍을 동시에 끊었다. 한쪽만 패면 영원히 안 풀린다.`
  - 015 briefing `재현이 안 된다. 로그를 붙이면 멀쩡하고, 로그를 떼면 죽는다. 버그가 관측을 눈치채는 것 같다.` / postmortem `하이젠버그의 정체는 대개 타이밍과 미초기화다 — 관측이 실행 조건을 바꾼다. 실무의 해법: 비침습 로깅과 상태 스냅샷. 이 판의 해법: 보이는 순간에만 쏘도록 nil 체크를 걸었다. 조건문은 가장 싼 관측 장비다.`
  - 016 briefing `프로세스 수가 눈덩이처럼 불어난다. 하나를 죽이면 둘이 태어난다. 정직한 화력으로는 산수에서 진다.` / postmortem `포크 밤은 개체가 아니라 증식률과 싸우는 문제다. 실무의 해법: ulimit로 프로세스 수 상한을 강제하기. 이 판의 해법: GC 수집기의 광역 사격으로 분열체를 한 화면에서 쓸어담았다. 쓰레기는 하나씩 줍지 않는다.`
- [ ] **Step 4: 전체 스위트**(test_battle 회귀가 13~16 클리어+16 naive 패배 자동 증명, lore 콘텐츠 회귀 자동 커버) **통과 후 커밋** — `codedefense: 스테이지 13~16 (메모리 릭·데드락·하이젠버그·포크 밤)`

### Task 6: 스테이지 17~20 (프로세스×2 + 네트워크×2, 보스) — 데이터·로어·회귀

**Files:**
- Modify: `love2d-codedefense/data/stages.csv`, `love2d-codedefense/data/timelines.csv`
- Create: `love2d-codedefense/data/mazes/017.txt`~`020.txt`, `love2d-codedefense/data/curriculum/017_solution.lua`~`020_solution.lua`, `017_hints.lua`, `020_naive.lua`, `love2d-codedefense/data/lore/017.lua`~`020.lua`

**Interfaces:**
- Consumes: Task 1~4 + Task 5와 동일 규칙.
- Produces: 스테이지 17~20 (17 레이스/디버거+예측, 18 레거시/스나이퍼, 19 DDoS/물량, 20 종합+커널 패닉·퍼즐) — 회귀 자동 편입, Wave B 데이터 완성

- [ ] **Step 1: 스테이지 설계 값** — theme: 17~18 `프로세스`, 19~20 `네트워크`. 미로: 네트워크=허브-스포크(중앙 광장+방사 통로). 19 타임라인에 한 이벤트 count 30·interval 0.4(≈11.6s 러시) 포함. 20은 `puzzle=1`+`naive_file`(광역 없이 단일 차선 방어 — 반드시 패배), 마지막 이벤트로 kernel-panic 1기. countdown 20~30, 공백 ≤40s 준수.
- [ ] **Step 2: 정답 스크립트** — 17: debugger 2기 + 프린터(감속로 격추 성립, hints_file 017: `build("debugger", _, _, "bp1")` 빈칸형 + 주석 `브레이크포인트는 두 곳까지`), 18: compiler→sniper 체인(프린터만으로는 저항 때문에 실패하는 예산 설계), 19: gc-collector+프린터 연사 길목 중첩, 20: 종합(oldest+광역+테크). 예산·수치 조정 가능 — 보고.
- [ ] **Step 3: lore 4편 집필(전문 그대로)**
  - 017 briefing `값이 가끔 틀린다. 매번도 아니고, 아무 때나. 두 처리가 같은 데이터를 놓고 경주 중이다 — 그리고 경주는 빠르다.` / postmortem `레이스는 속도가 아니라 순서의 문제다 — 임계 구역을 잠그면 경주가 사라진다. 실무의 해법: 뮤텍스와 원자적 연산. 이 판의 해법: 디버거로 브레이크포인트를 걸어 발을 늦추고, 늦춰진 틈을 화력으로 앞질렀다.`
  - 018 briefing `이 모듈은 10년째 아무도 안 건드렸다. 주석은 거짓말이고 테스트는 없다. 그런데 오늘, 그것이 직접 걸어온다.` / postmortem `레거시는 이해 없이 두드리면 오히려 단단해진다. 실무의 해법: 특성 테스트를 씌운 뒤 전문가가 조금씩 리팩터링하기. 이 판의 해법: 프린터 난사를 접고 스나이퍼 — 전문가를 투입해 급소만 노렸다.`
  - 019 briefing `트래픽 그래프가 수직으로 선다. 한 기 한 기는 하찮은 요청 — 그러나 서른 기가 한꺼번에 온다. 진행 바가 새빨갛다.` / postmortem `DDoS는 개별 차단이 아니라 처리량의 싸움이다. 실무의 해법: 레이트 리밋과 로드 밸런싱, 엣지에서 걸러내기. 이 판의 해법: 연사와 광역을 길목에 겹쳐 물량을 물량으로 받았다.`
  - 020 briefing `새벽 4시, 모든 알람이 동시에 울린다. 릭이 자라고, 밤이 갈라지고, 마지막엔 커널이 비명을 지른다. 배운 것 전부를 꺼낼 시간이다.` / postmortem `커널 패닉 뒤에 남는 것은 덤프와 회고뿐이다 — 그리고 회고를 남긴 팀만이 같은 밤을 두 번 겪지 않는다. 실무의 해법: 포스트모템 문화와 단일 장애점 제거. 이 판의 해법: 성장하기 전에 끊고 분열을 광역으로 받는 이중 방어선. 수고했다 — 이 서버실의 밤은 이제 네 것이다.`
- [ ] **Step 4: 전체 스위트 통과 후 커밋** — `codedefense: 스테이지 17~20 (레이스·레거시·DDoS·커널 패닉)`

### Task 7: 통합 검증 + 문서

**Files:**
- Modify: `love2d-codedefense/README.md`, `love2d-codedefense/CLAUDE.md`, `love2d-codedefense/states/play.lua` (문제 카드 라벨)
- Test: 전체 스위트 + 오토플레이 스크린샷

**Interfaces:**
- Consumes: Wave B 전부.
- Produces: 완성된 Wave B.

- [ ] **Step 1: 통합 스크린샷 검증** — 스테이지 13(oldest 사격)·16(스플래시 링+분열)·17(감속 점)·19(30기 러시 진행 바 눈금)·20(커널 패닉) 오토플레이 각 1장 + 도감 프로필 탭(20스테이지 목록 스크롤) 1장, Read 판독.
- [ ] **Step 2: CLAUDE.md 갱신** — 능력 키워드 표(grow/pair/phase/split2/dash/resist:·splash/slowfield, 상수 포함), 신규 타워 2종·limit, 스테이지 13~20 테마·퍼즐, world.oldest/age/speed API, 테스트 수 갱신. README 갱신 — 신규 적·타워 소개(스포일러 규칙 준수: 커널 패닉 상세는 간략히), 새 API 한 줄.
- [ ] **Step 2.5: 문제 카드 라벨 정정(Task 5 리뷰 반영)** — states/play.lua 2곳(~673행, ~862행)의 하드코딩 라벨 `"메모리 영역: "`을 `"영역: "`으로 — 스테이지 13~20의 테마(스레드/프로세스/네트워크)는 메모리 영역이 아니므로 범주 오류 해소. 기존 1~12(코드/데이터/스택/힙)도 "영역:"으로 자연스럽게 읽힘.
- [ ] **Step 3: 전체 스위트 + 부팅 스모크 후 커밋** — `codedefense: Wave B 문서 갱신`

### 마무리

- [ ] 전 스위트 + 데이터 회귀(전 20스테이지 solution 클리어·naive 3종 패배) 확인
- [ ] fable 최종 리뷰(Wave B diff) → 수정 웨이브 → 재리뷰
- [ ] tools/package.ps1 재실행으로 dist 갱신, 푸시
