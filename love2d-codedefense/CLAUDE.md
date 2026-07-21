# love2d-codedefense

LÖVE (Love2D) 11.5 기반 코딩 교육용 타워디펜스 《Code Defense》. 플레이어가 게임 내 에디터에서
Lua 코드(`on_tick(self, world)`)를 작성해 타워를 조종하고, 위에서 내려오는 밈 몬스터(버그/널
포인터/concat-nil)를 막습니다. 설계서: `docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md`
(레포 루트 기준).

## 실행 방법

```powershell
& "C:\Program Files\LOVE\lovec.exe" .        # 콘솔 출력(print) 확인 가능 — 개발 시 권장
& "C:\Program Files\LOVE\love.exe" .         # 콘솔 없이 실행
```

프로젝트 루트(이 폴더)에서 실행해야 합니다. `main.lua`가 엔트리 포인트입니다.

## 구조

```
love2d-codedefense/
├─ main.lua              ← 엔트리 포인트: 폰트 로드 → db.load → 데이터 무결성 검증 → title 상태
├─ conf.lua               ← 창 크기(960x640), 타이틀 등 설정
├─ src/
│  ├─ csv.lua             ← 따옴표/이스케이프 지원 CSV 파서, 레코드 로더
│  ├─ db.lua               ← data/*.csv 로드·색인, 참조 무결성 검증(d.validate)
│  ├─ grid.lua             ← 미로 텍스트 파싱, 통로/건설칸/플로우 필드
│  ├─ sandbox.lua          ← 유저 Lua 코드 실행 격리(제한 env, 명령 예산 훅)
│  ├─ api.lua              ← 타워 코드에 노출되는 self/world API 빌드
│  ├─ enemy.lua            ← 적 이동·능력(split, crash_tower 등)
│  ├─ tower.lua             ← 타워 상태(쿨다운, 크래시, 오버클럭, 차지)
│  ├─ projectile.lua       ← 투사체 이동·명중 처리
│  ├─ battle.lua            ← 전투 코어 로직 (스폰, 틱, 공격 판정, 승패) — 뷰 비의존
│  ├─ editor.lua            ← 코드 에디터 위젯(커서, UTF-8 입력, 퀵바, 문법 강조)
│  ├─ fonts.lua             ← 나눔고딕(OFL) 로드
│  └─ progress.lua          ← 진행도(클리어, 아이템, 저장 코드) 저장/로드
├─ states/                ← hump Gamestate 화면들 (뷰 전담, 로직은 src/battle.lua에 위임)
│  ├─ title.lua
│  ├─ stageselect.lua
│  ├─ prep.lua             ← 그리드 배치 + 코드 에디터 (전투 준비/일시정지 재개 공용)
│  ├─ battle.lua            ← 전투 진행 렌더링, 배속(1/2/4), pause_at 도달 시 prep 복귀
│  └─ result.lua
├─ data/
│  ├─ towers.csv, enemies.csv, items.csv, stages.csv, timelines.csv
│  ├─ mazes/                ← 스테이지별 미로 텍스트(#=벽, .=통로, B=건설칸)
│  └─ curriculum/            ← 스테이지별 solution(정답)·hints(따라치기/빈칸) Lua 파일
├─ tests/                  ← lovec tests로 실행하는 자체 테스트 러너 (81개)
├─ lib/                    ← 외부 라이브러리 (직접 수정 금지)
│  ├─ classic.lua           ← rxi/classic: 경량 OOP
│  └─ hump/                  ← vrld/hump: gamestate, timer, vector, signal, camera
└─ assets/fonts/            ← 나눔고딕(OFL)
```

## 코딩 규칙

- 전투 로직(스폰, 틱, 공격 판정, 승패 등)은 반드시 `src/battle.lua` 코어에 둔다. `states/*.lua`는
  렌더링과 입력만 담당하는 뷰이며, 게임 규칙을 states에 새로 넣지 않는다.
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지).
- 화면 전환은 hump의 `Gamestate` 사용 (title / stageselect / prep / battle / result).
- 스테이지 추가는 코드가 아니라 **데이터로만** 한다 — `data/stages.csv`(+ 필요 시
  `timelines.csv`)에 행을 추가하고, `data/mazes/<n>.txt` 미로와
  `data/curriculum/<n>_solution.lua`(필수)·`<n>_hints.lua`(hint 모드일 때)를 함께 둔다.
  `solution_file`은 필수 — 회귀 테스트(`tests/test_battle.lua`)가 각 스테이지의 정답 코드로
  실제 클리어가 되는지 자동 검증하므로, 정답 없이 스테이지를 추가하면 테스트가 실패한다.
- **결정론 원칙**: 게임 로직에 랜덤을 쓰지 않는다. 같은 배치·같은 코드는 항상 같은 결과가
  나와야 회귀 테스트와 하드코어 스피드런 기록이 의미를 가진다.
- 스폰 열은 미로 1행의 통로(`.`)와 일치해야 한다 — `src/db.lua`의 `d.validate()`가 이를
  기계 검증하며, `main.lua`가 부팅 시 항상 이 검증을 돌려 오류가 있으면 즉시 에러로 중단시킨다.
- CSV 빈 셀 처리에 주의: 숫자 필드(`cost`, `hp`, `budget` 등)의 빈 셀은 `nil`로 변환되지만,
  텍스트 필드(`requires`, `abilities`, `reward_item` 등)의 빈 셀은 `""`(빈 문자열)로 남는다.
  `nil` 체크가 아니라 `x ~= ""` 형태로 비교해야 한다 (`src/db.lua`의 `index()` 참고).

## 구현된 규칙

- **에디터/타워 코드**: 타워는 `function on_tick(self, world) ... end`를 정의해 `self:attack(적)`
  으로 공격을 지시한다. `world.nearest()/weakest()/fastest()/enemies()` 등으로 대상을 조회.
- **샌드박스**: 유저 코드는 `math/string/table`의 순수 함수만 볼 수 있는 격리 환경에서 실행되며
  (`io/os/love/debug/loadstring/_G` 등 차단), `debug.sethook`의 카운트 훅으로 명령 예산을 강제한다.
  정의부(최상위) 실행에도 별도 예산(`COMPILE_BUDGET`)이 있어 무한 루프인 코드는 컴파일 단계에서
  걸러진다.
- **전투 루프**: 10Hz(`TICK = 0.1`) 의사결정, 틱당 명령 예산(`BUDGET = 3000`), 일반 모드 총
  300초. 예산을 절반 미만으로 쓰면 오버클럭 배율이 1.0에 수렴해 발사 속도가 빨라진다.
- **크래시/워치독**: 런타임 오류가 나면 타워가 3초(`WATCHDOG`) 동안 "크래시" 상태로 비활성화된
  뒤 자동 재시작한다. 재시작 직후 곧바로 다시 크래시하면(`recovering` 플래그) 영구 비활성화되어
  더 이상 재시작을 시도하지 않는다.
- **몬스터 능력**: `crash_tower`(널 포인터 — 서버 도달 시 최근접 타워 강제 크래시),
  `split`(concat-nil — 사망 시 체력 절반씩 둘로 분열). CSV의 `abilities` 필드로 조합 가능.
  전투 준비 화면은 스테이지 `ui` 필드에 따라 버튼 모드(`button`, 전략 프리셋 순환) 또는
  코드 에디터 모드(`hint`/`free`)로 렌더링을 분기한다.
- **진행도**: 클리어 여부, 획득 아이템(`cache`/`webhook`), 스테이지별 저장 코드를
  `love.filesystem` 유저 폴더에 저장(`src/progress.lua`). 아이템은 `data/items.csv`의 `api`
  필드로 타워 env에 어떤 함수를 추가로 열어줄지 결정한다 (`cache.get/set`, `on_spawn`).
  아이템은 획득 시 배치되는 모든 타워에 자동 장착된다 (0.1 규칙; 타워별 개별 장착 UI는 0.2).

## 알려진 한계

- 샌드박스의 명령 예산 훅은 C 함수 내부에서는 적용되지 않는다 (`string.rep(1e9)` 같은 호출은
  훅이 개입하기 전에 이미 오래 걸릴 수 있음). 싱글플레이어이고 자기 자신의 타워/틱만 느려지는
  자기피해에 한정되므로 v0.1에서는 수용 범위로 판단했다.
- `sandbox.call`은 `debug.sethook`을 전역으로 설정/해제하므로 **비재진입**이다. 타워 콜백 안에서
  또 다른 샌드박스 실행을 중첩 호출하지 않는다.
- 크래시 루프에 빠진 타워(워치독 복구 직후 재크래시)는 해당 전투 동안 영구 비활성화되며,
  플레이어가 되살릴 방법은 없다(재입장/재도전으로 새 배치를 해야 함). 의도된 교육적 페널티.

## 다음 단계 (0.2+)

v0.1은 코어 루프·샌드박스·에디터·퀵바·아이템 해금·테크 의존성·코드 크래프트(오버클럭)·CSV
데이터 기반 스테이지 8종까지의 범위다. 설계서(`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md`)
9장 기준으로 다음이 남아 있다.

- **하드코어 모드**: 50단계, 실시간 코딩(준비 없이 웨이브가 주기적으로 밀려옴), 클리어 타임 계측
- **클리어 타임 인증·공유**: 인증 카드 PNG 자동 생성 + 해시태그 공유 텍스트 클립보드 복사
- **밈 도감 UI**: 몬스터별 "실제 오류가 언제 나는지 + 어떻게 고치는지" 텍스트 영구 수집
- **아이템 확장**: CPU 코어 증설(명령 예산 증가), 공용 라이브러리 탭 등 인벤토리 심화
- **언어 진영 시스템**: 진영 선택 UI·보너스 데이터·언어별 랭킹 분리는 v1 프레임워크로 넣되,
  실행 가능한 진영은 Lua 하나로 시작 (Python/JS/C#은 외부 프로세스 어댑터로 v2 확장)

## 테스트

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

`tests/main.lua`가 `tests/test_*.lua` 스위트를 전부 실행하고 `RESULT pass=N fail=N`을 출력한다
(현재 81개, 전부 PASS). 실패가 있으면 콘솔 종료 코드도 0이 아니게 된다.

스테이지를 추가할 때는 `data/curriculum/<n>_solution.lua`를 **반드시** 함께 추가해야 한다 —
`tests/test_battle.lua`가 CSV에 등록된 모든 스테이지를 순회하며 `solution_file`의 코드로 실제
전투를 실행해 클리어(서버 생존)까지 확인하는 회귀 테스트이므로, 정답 코드가 없거나 틀리면
테스트가 실패해 스테이지 추가가 자동으로 검증된다.
