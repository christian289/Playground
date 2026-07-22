# codedefense 스테이지 경험 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 적 구성·진행 UI, 300초 꽉 찬 타임라인(+validate 강제), 도감, 히든 타워 "구구 클래스", 코딩테스트 문제 브리핑, 메모리 영역 테마 미로 — 실플레이 피드백 6항목을 구현한다.

**Architecture:** 데이터 스키마(towers/stages 열 추가)와 battle 코어 확장(limit·별칭·gugu 능력·TOTAL 노출)을 먼저 깔고, 타임라인·미로는 validate 규칙과 회귀 테스트가 강제하는 데이터 작업으로, UI(적 구성 패널·진행 바·문제 카드)와 도감은 뷰 레이어에 얹는다.

**Tech Stack:** LÖVE 11.5, 기존 모듈 재사용. 외부 의존성 없음.

**Spec:** `docs/superpowers/specs/2026-07-22-codedefense-stage-experience-design.md`

## Global Constraints

- 판정 철학 불변: 코드는 실행으로만 판정, 답안지 비교 금지 (스펙 §0)
- battle 코어 수정은 이번 회차 허용 항목만: `Battle.TOTAL = 300` 노출, buildTower의 limit 검사 + 한글 별칭("구구클래스"→"gugu-class"), gugu 능력(2단 시작, 30초마다 +1, 최대 9단, 실효 데미지 = damage × 단, 단 상승 로그 "[구구 클래스] N단 돌입! N × 1 = N...") — 전부 헤드리스 테스트 필수
- limit 초과 오류 문구: "구구 클래스는 스테이지당 하나뿐입니다" (limit 검사 자체는 범용 — towers.csv `limit` 열, 오류 문구는 "%s는 스테이지당 %d개뿐입니다" 형식)
- 구구 스탯 초안: cost 120, damage 6, range 150, cooldown 1.0, bullet_speed 420, requires 없음, limit 1, hidden 1, ability gugu (밸런스 조정 허용 — 회귀 유지 조건)
- validate 신규 규칙: 각 normal 스테이지의 마지막 스폰 이벤트 종료 시각(at+(count−1)×interval) ≥ 240, 인접 이벤트 간 공백(다음 at − 이전 종료) ≤ 40
- 타임라인: 공백 ≤ 25초 목표(규칙은 40 상한), 스폰이 ~280초까지, 후반 밀도 상승, 결정론·count=0 금지·스폰 열 규칙 유지
- 미로 테마: 1~2 코드 영역(정연한 가로 행), 3~4 데이터 영역(블록 격자), 5~6 스택(위에서 쌓이는 지그재그), 7~8 힙(단편화 조각). 12×16, 건설칸 ≥ 6
- **교차 일관성 의무**: 미로가 바뀌면 해당 스테이지의 solution build 좌표, buttons_1/2.lua 스크립트 좌표, tutorial_1.lua 앵커 셀 좌표를 함께 갱신 (튜토리얼 앵커는 스테이지 1 건설칸과 일치해야 함)
- 문제 카드: 카운트다운 중 전장 중앙 표시, Enter 닫기, I 재열람, 튜토리얼 말풍선보다 아래 z순서. stages.csv `theme`/`problem` 열
- 도감: 타이틀 메뉴 4항목(게임 시작/세계관/도감/종료), ←/→ 탭(타워/몬스터), ↑↓ 항목, ESC. 히든은 `hidden==1`이고 `progress.gugu_found`가 아니면 "???" 카드(스펙 §4 수수께끼 문구 그대로)
- 유저 텍스트 한글, 파티클/이펙트 뷰 전용 원칙 유지
- 테스트: `& "C:\Program Files\LOVE\lovec.exe" love2d-codedefense/tests` (PowerShell), 최종 전 스위트 + 8스테이지 회귀 클리어
- 커밋은 태스크마다, 브랜치 `feature/codedefense-tutorial`

## File Structure

```
변경: data/towers.csv        ← limit/hidden/ability 열 + gugu-class 행
변경: data/stages.csv        ← theme/problem 열
변경: data/timelines.csv     ← 8스테이지 300초 리밸런싱
변경: data/mazes/001~008.txt ← 메모리 테마 재설계
변경: data/curriculum/*_solution.lua, buttons_1/2.lua, tutorial_1.lua ← 좌표 동기화
변경: src/battle.lua         ← TOTAL 노출, limit·별칭, gugu 능력
변경: src/db.lua             ← 새 열 숫자 변환(limit,hidden), validate 타임라인 규칙
변경: src/progress.lua       ← (필드 자동 — 불리언 gugu_found, 코드 변경 불요 확인만)
신규: src/stageinfo.lua      ← 타임라인 → 적 종류별 총수/전체 총수/이벤트 구간 계산 (순수, 헤드리스)
변경: states/play.lua        ← 적 구성 패널, 진행 바, 문제 카드(I 토글), gugu_found 저장 훅
신규: states/codex.lua       ← 도감 (타워/몬스터 탭)
변경: states/title.lua       ← 메뉴 4항목
변경: tests/*                ← test_stageinfo 신규, test_battle/test_data 확장, baddata 픽스처
```

---

### Task 1: 데이터 스키마 + battle 코어 (limit·별칭·구구 능력·TOTAL)

**Files:**
- Modify: `data/towers.csv`, `src/db.lua`(numfields에 limit,hidden), `src/battle.lua`, `tests/test_battle.lua`, `tests/test_data.lua`

**Interfaces:**
- Produces: `Battle.TOTAL = 300` (클래스 상수), towers.csv 새 열(`limit`,`hidden`,`ability`), buildTower 별칭·limit, gugu 능력 필드 `tw.dan`(2..9), `tw:effectiveDamage()` 또는 resolveAttack 내 배율 적용, `battle.guguBuilt`(뷰가 gugu_found 저장 훅에 사용 — 대신 towersByName 순회로도 가능하니 필수 아님; **정확한 계약**: gugu-class 타워가 존재하면 뷰가 감지 가능해야 함 → `tw.def.id == "gugu-class"` 순회로 충분, 추가 필드 불요)

- [ ] **Step 1: towers.csv 확장**

```csv
id,name,cost,damage,range,cooldown,bullet_speed,requires,color,desc,limit,hidden,ability
printer,프린터,100,10,120,1.0,300,,0.3;0.8;0.4,기본 발사기. print()가 그렇듯 어디서나 쓴다,,,
compiler,컴파일러,50,0,0,0,0,,0.8;0.7;0.3,공격하지 않는 테크 타워. 고급 타워 건설을 해금한다,,,
sniper,스나이퍼,150,40,240,2.5,600,compiler,0.4;0.5;0.9,장거리 저격. 컴파일러가 필드에 있어야 건설 가능,,,
gugu-class,구구 클래스,120,6,150,1.0,420,,0.95;0.75;0.2,"위기의 순간 소환되는 전설의 클래스. 시간이 지날수록 단이 오른다 (2단→9단, 데미지 ×단)",1,1,gugu
```

(기존 세 행의 cost 등 수치는 현재 파일 값을 유지 — 위는 형식 예시이므로 실제 파일의 현행 수치를 그대로 두고 열만 추가할 것.)

- [ ] **Step 2: 실패하는 테스트** — test_data에 `t.eq(d.towers["gugu-class"].limit, 1, ...)`, `t.eq(d.towers.printer.limit, nil, "빈 limit은 nil")`; test_battle에:

```lua
    -- 구구 클래스: 별칭·limit·단 성장·배율
    local GUGU = 'build("구구클래스", 3, 10, "g")\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend'
    local bg = Battle(d, 1, {})
    t.ok(bg:setScript(GUGU), "한글 별칭 컴파일")
    t.eq(bg.towers[1].def.id, "gugu-class", "별칭이 gugu-class로 해석")
    t.eq(bg.towers[1].dan, 2, "2단 시작")
    bg:setScript(GUGU .. '\nbuild("gugu-class", 11, 3, "g2")')
    t.eq(#bg.towers, 1, "스테이지당 1개 제한")
    t.ok(table.concat(bg.log, "/"):find("하나뿐"), "limit 한글 오류 로그")
    bg:start()
    local dt = 1 / 30
    for _ = 1, math.floor((d.stages[1].countdown + 31) / dt) do bg:update(dt) end
    t.eq(bg.towers[1].dan, 3, "30초 후 3단")
    t.ok(table.concat(bg.log, "/"):find("3단 돌입"), "단 상승 로그")
    t.eq(Battle.TOTAL, 300, "TOTAL 상수 노출")
```

(단 타이머는 전투 시간(clock>=0) 기준. 배율 검증: resolveAttack이 만드는 projectile.damage가 `def.damage * dan`인지 — gugu 타워로 발사 시점 projectile 검사 assert 1개 추가.)

- [ ] **Step 3: 구현** — db.lua: towers numfields에 `"limit", "hidden"` 추가. battle.lua:
  - 파일 상단 `local TOTAL = 300` → `Battle.TOTAL = 300` 병기 (기존 지역 상수 유지해도 무방, 클래스 필드로 노출)
  - buildTower 진입부: `if typeId == "구구클래스" then typeId = "gugu-class" end`
  - limit 검사 (requires 검사 다음): `if def.limit then local n = 0; for _, tw in ipairs(self.towers) do if tw.def.id == def.id then n = n + 1 end end; if n >= def.limit then return false, ("%s는 스테이지당 %d개뿐입니다"):format(def.name, def.limit) end end`
  - 설치 시 `if def.ability == "gugu" then tw.dan = 2; tw.danTimer = 0 end`
  - update 루프(타워 순회부): `if tw.dan and self.clock >= 0 and tw.dan < 9 then tw.danTimer = tw.danTimer + dt; if tw.danTimer >= 30 then tw.danTimer = tw.danTimer - 30; tw.dan = tw.dan + 1; self:say(("[구구 클래스] %d단 돌입! %d × 1 = %d..."):format(tw.dan, tw.dan, tw.dan)) end end`
  - resolveAttack 데미지: `local dmg = tw.def.damage * (tw.dan or 1)` 후 기존 차지 배율과 곱해 projectile 생성에 사용
- [ ] **Step 4: 통과 확인** (기존 156 + 신규) → **Step 5: Commit** `codedefense: 구구 클래스 히든 타워 (limit·별칭·단 성장)`

---

### Task 2: 타임라인 리밸런싱 + validate 규칙

**Files:**
- Modify: `data/timelines.csv`, `src/db.lua`(validate), `tests/test_data.lua`, `tests/fixtures/baddata/data/timelines.csv`(+stages 필요 시)

**Interfaces:**
- Produces: validate 오류 문구 — `"timelines: 스테이지 %s 마지막 스폰 종료 %d초 < 240초"`, `"timelines: 스테이지 %s 스폰 공백 %d초 > 40초 (at %d)"` (숫자는 정수 반올림)

- [ ] **Step 1: validate 규칙 구현** — d.timeline(id)로 정렬된 이벤트에서 각 이벤트 종료 = `at + (count-1)*interval`; 마지막 종료 ≥ 240 검사; 인접 공백 = `다음.at - 이전종료` ≤ 40 검사. normal 모드 스테이지에만 적용.
- [ ] **Step 2: 음성 픽스처** — baddata에 마지막 스폰 60초 종료인 스테이지 추가, test_data에 `find("240초")`/`find("공백")` assert. 양성: 실데이터 0오류 유지 assert (이미 존재).
- [ ] **Step 3: timelines.csv 재설계** — 8개 스테이지 전부: 첫 이벤트 at 0~10, 이후 이벤트가 ~280초까지 공백 ≤ 25초로 이어지도록 (규칙 상한 40의 여유 안). 스테이지 1은 초반 저밀도(튜토리얼 읽기), 전 스테이지 후반 밀도 상승. 적 구성은 기존 종류 분포 유지(신규 종류 금지). 예시 형태 (스테이지 1):

```csv
1,5,bug,5,4,4
1,35,bug,6,3.5,9
1,70,bug,8,3,4
1,105,bug,8,2.8,9
1,140,bug,10,2.5,4
1,180,bug,10,2.2,9
1,215,bug,12,2,4
1,250,bug,12,1.8,9
```

(스폰 열은 각 스테이지 미로 1행 통로와 일치해야 하나 **미로가 Task 3에서 바뀌므로**, 이 태스크에서는 현행 미로 기준으로 열을 맞추고 Task 3가 미로 변경 시 열을 재동기화한다.)
- [ ] **Step 4: 회귀 재클리어** — 밀도 상승으로 실패하는 스테이지는 count/interval 미세 조정 (validate 규칙 준수 유지). 전 스위트 통과.
- [ ] **Step 5: Commit** `codedefense: 300초 꽉 찬 타임라인 + validate 스폰 연속성 규칙`

---

### Task 3: 메모리 영역 테마 미로 8종

**Files:**
- Modify: `data/mazes/001~008.txt`, `data/timelines.csv`(스폰 열 재동기화), `data/curriculum/00N_solution.lua`(build 좌표), `data/curriculum/buttons_1.lua`/`buttons_2.lua`(좌표), `data/curriculum/tutorial_1.lua`(앵커 셀), 필요 시 `data/curriculum/00N_hints.lua`(빈칸 내 좌표)

**Interfaces:**
- Consumes: Global Constraints의 테마 표. validate(스폰 열·미로 파일 규격)와 회귀 테스트가 정합성 강제.

- [ ] **Step 1: 미로 8종 재설계** — 테마별 형태 (12열×16행, `#`벽/`.`통로/`B`건설칸 ≥ 6, 1행 통로 = 스폰 열, 맨 아랫줄 통로 ≥ 1, 전 통로가 아랫줄 도달 가능):
  - 001~002 코드 영역: 가로 행 통로가 명령어 줄처럼 규칙적으로 반복, 행 사이 벽 랙
  - 003~004 데이터 영역: 4×3 블록 벽들이 격자 배치, 블록 사이 십자 통로
  - 005~006 스택: 좌우 번갈아 뚫린 층계 지그재그, 아래로 갈수록 통로 폭 감소
  - 007~008 힙: 크기가 제각각인 벽 조각을 흩뿌린 단편화 구조 (통로는 유기적 곡류)
- [ ] **Step 2: 좌표 동기화** — 각 스테이지: 새 미로의 건설칸에서 정답 배치 좌표 선정(예산 내 프린터 수) → solution build 좌표 갱신 → buttons_1/2 스크립트 좌표 갱신(스테이지 1: 정답 2좌표와 동일) → tutorial_1.lua 앵커 2셀을 그 좌표로 → timelines 스폰 열을 새 1행 통로로.
- [ ] **Step 3: 회귀로 검증** — 8스테이지 정답 클리어 + validate 0오류 + 전 스위트. 클리어 안 되는 스테이지는 배치 좌표(브루트포스 허용) 또는 timeline 미세 조정.
- [ ] **Step 4: 스크린샷** — 스크래치패드 하네스로 미로 8종을 각각 캡처(전장만이라도) → Read로 테마 식별성 육안 확인, 미흡하면 형태 조정.
- [ ] **Step 5: Commit** `codedefense: 메모리 영역 테마 미로 (코드·데이터·스택·힙)`

---

### Task 4: 적 구성 패널 + 진행 바 + 문제 카드

**Files:**
- Create: `src/stageinfo.lua`, `tests/test_stageinfo.lua`(suites 등록)
- Modify: `data/stages.csv`(theme/problem 열), `src/db.lua`(열 통과 — 텍스트라 변환 불요, validate도 불요), `states/play.lua`

**Interfaces:**
- Produces: `stageinfo.totals(timeline) → { byType = { [enemyId] = n, ... }, total = N, lastEnd = 초, events = timeline }`, `stageinfo.killedCounts(totals, battle) → { [enemyId] = 처치수 }` — 처치수 = 종류별 전체 − (미스폰 잔여 + 필드 생존). 미스폰 잔여는 battle.spawned와 timeline 대조. 순수 함수(헤드리스 테스트).

- [ ] **Step 1: stages.csv에 theme/problem 열 + 8행 값 작성** — theme: 코드 영역/코드 영역/데이터 영역/데이터 영역/스택/스택/힙/힙. problem: 스테이지 개념과 이어지는 한 줄 문제 서술 (예: 1 "첫 배포 날, 버그가 유입되기 시작했다. 첫 타워를 세워 서버라인을 지켜라." — 8개 전부 코딩테스트 문제 톤의 한글 서술 작성).
- [ ] **Step 2: stageinfo.lua + 테스트** (TDD) —

```lua
return function(t)
    local db = require("src.db")
    local stageinfo = require("src.stageinfo")
    local d = db.load(PROJECT_ROOT)
    local info = stageinfo.totals(d.timeline(1))
    t.ok(info.total > 0, "전체 적 수 > 0")
    t.ok(info.byType.bug and info.byType.bug > 0, "종류별 집계")
    t.ok(info.lastEnd >= 240, "마지막 스폰 종료 ≥ 240 (validate와 일치)")
    local sum = 0
    for _, n in pairs(info.byType) do sum = sum + n end
    t.eq(sum, info.total, "종류 합 = 전체")
end
```

구현: totals는 timeline 순회 합산. killedCounts는 `spawnedOf(i)` = battle.spawned[i] (이벤트 인덱스별 스폰 수) 합산으로 종류별 스폰 수를 구하고, 필드 생존은 battle.enemies 순회 — `처치+도달 = 스폰 − 생존` (도달 분리는 UI에 불필요, "처리됨"으로 묶음. 라벨은 "처치"가 아니라 **"처리 n / 전체 N"**로 표기해 도달 포함 의미를 정직하게).
- [ ] **Step 3: play UI** —
  - **적 구성 패널** (전장 우상단, x=GRID_X+전장폭−폭−4, y=GRID_Y+4, 반투명 bg 박스): 종류별 한 줄 — `art.drawEnemy(id, ...)` 미니 아이콘(중심 스케일 그대로) + `처리 n / N`. 데이터: enter에서 `self.info = stageinfo.totals(self.battle.timeline)` 1회, draw에서 killedCounts.
  - **진행 바** (HUD 아래 y=34, 전장 폭): 배경 바 + 진행(clock/Battle.TOTAL, 카운트다운 중 0) + 이벤트 at 지점 눈금(1px cyan) + 모든 스폰 종료 후 우측에 "소탕 후 생존!" 텍스트. 좌표 라벨(y=32~46)과 겹치므로 열 라벨을 y=36→그리드 쪽으로 4px 내리거나 진행 바를 y=30 얇게(4px) — 구현 시 겹침 없게 조정하고 스크린샷으로 확인.
  - **문제 카드**: `self.showBrief = true`로 시작(카운트다운 중), 전장 중앙 카드(폭 ~360px, 반투명 panel): "[문제 N] 개념 · 메모리 영역: 테마" / problem 텍스트 wrap / "제한: 예산 B · 유입 예정 T기" / "제출: F5 · 채점: 300초 생존" / "Enter 닫기 · I 다시 보기". keypressed: Enter로 닫기(단, 튜토리얼 게이팅 통과 후·에디터 개행과 충돌 없게 — **카드가 열려 있는 동안만 Enter를 카드 닫기로 소비**), `i` 키 토글(버튼 스테이지 숫자 입력과 무충돌, 에디터 문자 입력과 충돌하므로 **Ctrl+I**로 결정 — 힌트바에 표기). 카운트다운 종료 시 자동 닫기 없음(카드는 열려 있어도 게임 진행 — 실시간 원칙). z순서: 튜토리얼 말풍선 아래.
  - gugu_found 훅: update에서 `if not p.gugu_found then for _, tw in ipairs(b.towers) do if tw.def.id == "gugu-class" then p.gugu_found = true; progress.save(p) end end end` (1회 가드).
  - 힌트바 문구에 `Ctrl+I 문제` 추가.
- [ ] **Step 4: 검증** — 전 스위트 + 부팅 스모크 + 스크린샷(카운트다운 문제 카드/전투 중 패널·진행 바) Read 확인.
- [ ] **Step 5: Commit** `codedefense: 적 구성 패널·진행 바·문제 브리핑 카드`

---

### Task 5: 도감 + 타이틀 메뉴 확장

**Files:**
- Create: `states/codex.lua`
- Modify: `states/title.lua`(메뉴 4항목: 게임 시작/세계관/도감/종료)

**Interfaces:**
- Consumes: d.towers/d.enemies(desc 포함), art.drawTower/drawEnemy/pal, progress.gugu_found
- Produces: `codex:enter(prev, d, p)`, ESC → title

- [ ] **Step 1: codex.lua** — 상단 탭 라벨 [타워] [몬스터] (←/→ 전환, 활성 green), 좌측 목록(↑↓, `>` 커서), 우측 카드: 스프라이트 크게(스케일 4~6, t 애니) + 이름 + desc + (타워) 스탯 표(비용/데미지/사거리/쿨다운/요구 테크 — 값 없는 것 "—") + 예시 코드 `build("<id>", 3, 10, "a")` (몬스터는 능력 설명 — abilities 키워드를 한글 설명으로 매핑: crash_tower→"도달 시 최근접 타워를 크래시", split→"죽으면 둘로 분열", 빈 값→"—"). 정렬: 타워는 towers.csv 순, gugu-class는 항상 마지막.
  - **히든 처리**: `hidden==1 and not p.gugu_found` → 목록명 "???", 카드: 검은 실루엣(스프라이트를 검정 단색으로 — art.drawTower 위에 검정 반투명 사각 덮기로 간단히) + 수수께끼 문구(스펙 §4 그대로: "장애가 터지면 회의실 화면 앞에서 실시간으로 코딩을 시작한다는 전설의 클래스. Java로 짠 그것의 이름을 아는 자만이 소환할 수 있다.") + 스탯 전부 "?".
- [ ] **Step 2: title 메뉴 4항목** — "도감" 선택 → `Gamestate.switch(codex, d, p)`.
- [ ] **Step 3: 검증** — 전 스위트 무손상 + 부팅 스모크 + 스크린샷(타워 카드/몬스터 카드/??? 카드) Read 확인.
- [ ] **Step 4: Commit** `codedefense: 도감 (타워·몬스터·히든 ???)`

---

### Task 6: 문서 + 최종 검증

**Files:**
- Modify: `love2d-codedefense/CLAUDE.md`, `README.md`

- [ ] **Step 1: 문서** — 조작(Ctrl+I 문제 카드, 도감 메뉴·탭 조작), 데이터 스키마(towers limit/hidden/ability, stages theme/problem, validate 타임라인 규칙 2종), 구구 클래스(별칭·limit·단 성장 — 히든이므로 README에는 "숨겨진 타워가 있다는 소문" 정도로만, CLAUDE.md에는 전체 명세), 메모리 테마 미로, 적 구성 패널·진행 바. 스테이지 추가 절차에 새 열·타임라인 규칙 반영.
- [ ] **Step 2: 최종 검증** — 전 스위트 + 부팅 스모크 + 새 저장으로 스테이지 1 진입 스크린샷(문제 카드+튜토리얼 공존 확인).
- [ ] **Step 3: Commit** `codedefense: 스테이지 경험 문서화`

---

## Self-Review 결과

- **스펙 커버리지**: §0(무변경 — 문서만), §1(Task 4), §2(Task 2), §3(Task 5), §4(Task 1+4 훅+5 히든카드), §5(Task 4), §6(Task 3), §7(각 태스크+6). 범위 제외 준수.
- **플레이스홀더**: 미로·problem 문구·도감 레이아웃은 형태 명세+검증 게이트(validate/회귀/스크린샷 Read)로 정의 — 창작 데이터 특성상 최종 판정은 검증 단계가 담당.
- **타입 일관성**: stageinfo.totals/killedCounts 시그니처 Task 4 내 정의·사용 일치. Battle.TOTAL, tw.dan, def.limit/hidden/ability가 Task 1 정의 → 4·5 사용 일치. 교차 일관성(미로↔좌표↔튜토리얼 앵커)은 Task 3 Step 2 의무 + 회귀가 강제.
