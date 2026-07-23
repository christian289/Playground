# Code Defense 셸 진영 (Shell Mode) 설계서 — Wave D

2026-07-23. 사용자 지시: "bash나 ps1 같은 것을 사용할 수 있는 모드 — 추후 Claude Code 같은
것으로 게임을 제어시킬 관문". 문답 확정: **별도 진영** / **cron 자동화 도입** /
**외부 제어 어댑터는 다음 회차**(이번엔 게임 내 터미널까지만, 단 파서를 뷰와 분리해 준비).

## 0. 비전 연결

게임의 최종 아크 "타이핑 → 매크로 → AI 에이전트가 대신 플레이"의 두 번째 단계.
모든 조작이 "한 줄 텍스트 명령"이 되므로, 이후 stdin/명령 파일 어댑터만 붙이면
외부 에이전트(Claude Code)가 문자 그대로 게임을 플레이할 수 있다.

## 1. 구조 — 별도 진영

- 타이틀 "게임 시작" → **진영 선택 화면** 신설: `Lua 진영` / `Shell 진영` (좌우 또는 상하 선택,
  키보드+마우스). 진영별로 스테이지 목록이 분리된다.
- stages.csv 재사용: `languages` 칼럼 값 `shell` + `ui` 값 `shell`. 스테이지 id는 전역 고유
  (셸 스테이지는 101번대 — 예: 101~106)이므로 progress(cleared/records/codes)는 기존 키 그대로 공유.
- stageselect: 진영 파라미터를 받아 `languages` 필터링만 추가. 기록·별점 표기 동일.
- 초기 셸 커리큘럼 6개 (2절 명령 세트와 1:1):
  1. **ls의 세계** — `ls`, `build` 인자 순서 (버튼 힌트 제공)
  2. **rm 재배치** — `rm` 철거+환불로 배치 실험 (Wave A demolish 코어 재사용)
  3. **top 모니터링** — `top`, `ls enemies`로 상황 판단
  4. **man을 읽어라** — `man`, `target` 전략 지정 (nearest/oldest/strongest)
  5. **crontab 입문** — `cron`으로 주기 명령 예약
  6. **셸 종합 시험** — 전 명령 조합 (데드락급 구성을 target 분산으로)

## 2. 명령 세트 (bash 문법 기본 + ps1 별칭)

| 명령 | 문법 | 동작 |
|---|---|---|
| build | `build <타워id/한글별칭> <행> <열> <이름>` | Battle:buildTower 그대로 (검사·한글 오류·로그 동일) |
| rm | `rm <이름>` | Battle:demolishTower (Wave A) — 철거+환불 50% |
| ls | `ls` / `ls enemies` | 내 타워 목록 / 필드 적 목록(종류·HP·행열)을 터미널 출력 |
| top | `top` | 서버 HP·잔액·처치 n/m·배속 요약 1회 출력 |
| target | `target <타워이름> <전략>` | 타워 표적 전략 지정: nearest/oldest/strongest/first. 수치 조작 불가 원칙 유지 |
| cron | `cron <초간격> "<명령>"` / `cron -l` / `cron -r <번호>` | 주기 명령 예약/목록/삭제. battle clock 기준 결정론 실행 |
| man | `man <명령>` | 함수 사전 카드 열기 (기존 dictOpen 연동) |
| history | `history` | 명령 이력 출력 (↑↓ 네비게이션도 지원) |
| clear | `clear` | 터미널 출력 버퍼 비우기 |

- ps1 별칭(이스터에그 겸 실용): `Remove-Item`→rm, `Get-Process`→ls enemies, `Get-Content`→man,
  `dir`→ls. 별칭 사용 시 로그에 "PowerShell 사용자를 환영합니다" 1회 출력.
- 오류는 셸 밈으로: `command not found: buld — 'build'를 의미했나요?` (레벤슈타인 1 이내 제안),
  `usage: build <타워> <행> <열> <이름>`.

## 3. 아키텍처 (코어/뷰 분리 유지)

- **src/shell.lua** (신규, 순수 모듈 — love 금지, 헤드리스 테스트 대상):
  - `Shell.new(battle)` → `shell:exec(line)` → `{ ok, output(문자열 배열) }`.
  - 토크나이저(따옴표 인자 지원) + 명령 테이블 + 별칭 맵 + 오타 제안.
  - cron 레지스트리: `{ id, interval, line, nextAt }` — `shell:tick(clock)`을 battle 틱과 동기
    호출(뷰가 아니라 play update에서 battle clock 전달). 결정론: nextAt은 등록 시각 기준 산술.
- **battle.lua 확장 (Lua 진영과 공유)**:
  - `Battle:setTargetStrategy(name, strat)` — 타워별 전략 필드. on_tick 스크립트가 없는(셸 진영)
    타워는 매 틱 전략에 따라 기본 공격을 수행한다(현재 Lua 진영의 "스크립트 없으면 대기"와 구분).
  - 전략 구현: nearest(거리)/oldest(스폰 순)/strongest(최대 HP)/first(서버라인 최근접 진행도).
  - 셸 진영 battle 생성 시 `opts.autoAttack = true` — Lua 진영 동작은 불변(회귀 보장).
- **states/play.lua**: `ui == "shell"`이면 에디터 대신 **터미널 패널** 렌더:
  프롬프트 줄(`$ ` 접두), 출력 버퍼 스크롤(최근 N줄), 명령 히스토리 ↑↓, Enter 즉시 실행.
  기존 정보 칼럼·전장·튜토리얼 구조는 그대로. F5/스니펫/Ctrl+L은 셸 스테이지에서 비활성
  (힌트바 문구도 셸 전용: "Enter 실행 · ↑↓ 이력 · man <명령> 도움말 · Ctrl+5/1/2/4 배속 · ESC 포기").
- **함수 사전**: BUILTIN_DOCS에 셸 명령 카드 9종 추가, man이 이를 연다. 도감 프로필의 배포
  카운트는 셸 명령 실행 수와 별개(배포=cron 등록+build로 정의).

## 4. 외부 제어 준비 (이번 회차 비범위, 설계만 고정)

- shell:exec가 "문자열 in → 문자열 out"이므로 어댑터는 얇다. 다음 회차에서:
  `--cmdfile <경로>` 기동 옵션 → 파일 tail 폴링 → 한 줄씩 exec → 결과를 `<경로>.out`에 append.
  Claude Code가 파일에 명령을 쓰면 게임이 실행되는 데모가 목표.
- 결정론/공정성: 외부 명령도 배포 로그에 동일 기록. 하드코어 모드에서는 외부 어댑터 비활성.

## 5. 테스트·검증

- 헤드리스(신규 스위트 test_shell): 명령 파싱(따옴표·오타 제안·별칭), build/rm/target/cron의
  battle 상태 반영, cron 결정론(같은 시각 등록→같은 실행 시각열), ls/top 출력 포맷 스냅샷.
- 전략 테스트: 4전략 각각 표적 선택이 정의대로인지(고정 적 배치로 단언).
- 회귀: Lua 진영 전 스테이지 솔루션 클리어 불변 (autoAttack 미사용 경로 확인).
- 비주얼: 터미널 패널, 오타 제안, cron -l, man 연동, 진영 선택 화면 — 오토플레이 스크린샷.
- 데이터: 셸 스테이지 101~106 stages.csv+미로+튜토리얼(1번만)+솔루션(명령 시퀀스 파일,
  회귀 러너가 한 줄씩 exec) 추가. validate() 확장: ui=shell이면 solution_file은 .sh 텍스트.

## 6. 의존/순서

- Wave A의 demolishTower가 rm의 전제 → **Wave A 먼저 구현**.
- Wave B(신규 적)와는 독립 — 순서 무관. 셸 종합 시험(스테이지 106)에서 데드락을 쓰려면
  Wave B 이후 데이터만 갱신.
