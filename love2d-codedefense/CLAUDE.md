# love2d-codedefense

LÖVE (Love2D) 11.5 기반 코딩 교육용 타워디펜스 《Code Defense》. 플레이어가 게임 내 에디터에서
Lua 코드(`on_tick(self, world)`, `build(type, r, c, name)`)를 작성해 타워를 조종하고, 위에서
내려오는 밈 몬스터(버그/널 포인터/concat-nil)를 막습니다. 설계서:
`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md` (레포 루트 기준, 4.1/5.1절이
이번 실시간 개편 반영), 튜토리얼 설계서:
`docs/superpowers/specs/2026-07-21-codedefense-tutorial-design.md`.

## 실행 방법

```powershell
& "C:\Program Files\LOVE\lovec.exe" .        # 콘솔 출력(print) 확인 가능 — 개발 시 권장
& "C:\Program Files\LOVE\love.exe" .         # 콘솔 없이 실행
```

프로젝트 루트(이 폴더)에서 실행해야 합니다. `main.lua`가 엔트리 포인트입니다.

## 구조

```
love2d-codedefense/
├─ main.lua              ← 엔트리 포인트: 폰트·아트 로드 → db.load → 데이터 무결성 검증 →
│                            intro_seen 여부로 intro 또는 title 상태로 진입
├─ conf.lua               ← 창 크기(960x640), 타이틀 등 설정
├─ src/
│  ├─ csv.lua             ← 따옴표/이스케이프 지원 CSV 파서, 레코드 로더
│  ├─ db.lua               ← data/*.csv 로드·색인, 참조 무결성 검증(d.validate)
│  ├─ grid.lua             ← 미로 텍스트 파싱, 통로/건설칸/플로우 필드
│  ├─ sandbox.lua          ← 유저 Lua 코드 실행 격리(제한 env, 명령 예산 훅)
│  ├─ api.lua              ← 타워 코드에 노출되는 self/world/build/아이템 API 빌드
│  ├─ enemy.lua            ← 적 이동·능력(split, crash_tower 등)
│  ├─ tower.lua             ← 타워 상태(쿨다운, 크래시, 오버클럭, 차지)
│  ├─ projectile.lua       ← 투사체 이동·명중 처리
│  ├─ battle.lua            ← 전투 코어 로직 (카운트다운, 스폰, 틱, build, 공격 판정, 승패) — 뷰 비의존
│  ├─ editor.lua            ← 코드 에디터 위젯(커서, UTF-8 입력, 퀵바, 문법 강조)
│  ├─ tutorial.lua          ← 튜토리얼 스텝 진행/허용 키 필터/말풍선 렌더 — 뷰 비의존
│  ├─ fonts.lua             ← 나눔고딕(OFL) 로드
│  ├─ progress.lua          ← 진행도(클리어, 아이템, 저장 코드, 튜토리얼 완료, 인트로 시청) 저장/로드
│  ├─ art.lua               ← 코드 생성 픽셀아트 — 팔레트(`art.pal`), 캔버스 시트(몬스터/타워/개발자),
│  │                            전장 타일, 로고, 인트로 일러스트 4종. 외부 이미지 에셋 없음
│  ├─ particles.lua         ← 뷰 전용 파티클 풀(상한 400) — spark/burst/float/smoke/flash
│  └─ cutscene.lua          ← 컷신(인트로) 진행 순수 로직 — 장면 전환, 초당 30자 타이프라이터
├─ states/                ← hump Gamestate 화면들 (뷰 전담, 로직은 src/battle.lua·src/tutorial.lua에 위임)
│  ├─ intro.lua             ← 인트로 컷신 4장면 (첫 실행 1회 자동 재생, 타이틀 "세계관" 메뉴로 재생)
│  ├─ title.lua
│  ├─ stageselect.lua
│  ├─ play.lua              ← 그리드 + 코드 에디터 + 실시간 전투를 한 화면에서 진행 (구 prep/battle 통합)
│  └─ result.lua
├─ data/
│  ├─ towers.csv, enemies.csv, items.csv, stages.csv, timelines.csv
│  ├─ mazes/                ← 스테이지별 미로 텍스트(#=벽, .=통로, B=건설칸)
│  └─ curriculum/            ← 스테이지별 solution(정답)·hints(따라치기/빈칸)·tutorial(가이드)·buttons(생성기) Lua 파일
├─ tests/                  ← lovec tests로 실행하는 자체 테스트 러너 (156개)
├─ lib/                    ← 외부 라이브러리 (직접 수정 금지)
│  ├─ classic.lua           ← rxi/classic: 경량 OOP
│  └─ hump/                  ← vrld/hump: gamestate, timer, vector, signal, camera
└─ assets/fonts/            ← 나눔고딕(OFL)
```

상태 흐름은 기본적으로 `title → stageselect → play → result` 네 가지입니다. 구 `prep`/`battle`
상태는 `play` 하나로 통합되어 삭제되었습니다 — 준비 단계가 없어졌고, 배치와 코딩과 전투가 같은
화면에서 동시에 진행됩니다. 여기에 세계관 도입부인 `intro` 상태가 더해졌습니다: 첫 실행 시
(`progress.intro_seen`이 없으면) `main.lua`가 `title` 대신 `intro`로 곧장 진입해 4장면을 자동
재생하고, 끝나면 `intro_seen`을 저장한 뒤 `title`로 넘어갑니다. 이후에는 타이틀 메뉴의 "세계관"
항목으로 언제든 다시 볼 수 있습니다(이때는 `intro_seen`을 다시 쓰지 않고 재생 후 `title`로만
복귀).

## 코딩 규칙

- 전투 로직(카운트다운, 스폰, 틱, `build` 처리, 공격 판정, 승패 등)은 반드시 `src/battle.lua`
  코어에 둔다. `states/*.lua`는 렌더링과 입력만 담당하는 뷰이며, 게임 규칙을 states에 새로
  넣지 않는다. 튜토리얼 진행 로직(스텝 전환, 허용 키 판정)도 마찬가지로 `src/tutorial.lua`에
  두고 `states/play.lua`는 그리기와 키 라우팅만 한다.
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지).
- 화면 전환은 hump의 `Gamestate` 사용 (intro / title / stageselect / play / result).
- 스테이지 추가는 코드가 아니라 **데이터로만** 한다 — `data/stages.csv`(+ 필요 시
  `timelines.csv`)에 행을 추가하고, `data/mazes/<n>.txt` 미로와
  `data/curriculum/<n>_solution.lua`(필수)·`<n>_hints.lua`(hint 모드일 때)를 함께 둔다.
  버튼 모드(`ui=button`) 스테이지라면 `buttons_file`에 생성기 Lua(`data/curriculum/buttons_<n>.lua`)를,
  가이드가 필요한 스테이지라면 `tutorial_file`에 튜토리얼 스텝 Lua
  (`data/curriculum/tutorial_<n>.lua`)를 함께 등록한다. `countdown`(15~30초 권장)도 스테이지마다
  지정해야 한다. `solution_file`은 필수 — 회귀 테스트(`tests/test_battle.lua`)가 각 스테이지의
  정답 코드로 실제 클리어가 되는지 자동 검증하므로, 정답 없이 스테이지를 추가하면 테스트가
  실패한다.
- **결정론 원칙**: 게임 로직에 랜덤을 쓰지 않는다. 같은 배치·같은 코드는 항상 같은 결과가
  나와야 회귀 테스트와 하드코어 스피드런 기록이 의미를 가진다.
- 스폰 열은 미로 1행의 통로(`.`)와 일치해야 한다 — `src/db.lua`의 `d.validate()`가 이를
  기계 검증하며, `main.lua`가 부팅 시 항상 이 검증을 돌려 오류가 있으면 즉시 에러로 중단시킨다.
- CSV 빈 셀 처리에 주의: 숫자 필드(`cost`, `hp`, `budget`, `countdown` 등)의 빈 셀은 `nil`로
  변환되지만, 텍스트 필드(`requires`, `abilities`, `reward_item`, `tutorial_file`, `buttons_file`
  등)의 빈 셀은 `""`(빈 문자열)로 남는다. `nil` 체크가 아니라 `x ~= ""` 형태로 비교해야 한다
  (`src/db.lua`의 `index()` 참고).

## 아트 규칙

- **외부 이미지 에셋 없음 — 전부 코드 생성**. 모든 그래픽(전장 타일, 타워, 몬스터, 개발자
  캐릭터, 로고, 인트로 일러스트)은 `src/art.lua`가 `love.graphics.rectangle`/`circle` 등으로
  직접 그린다. 유일한 외부 바이너리 에셋은 폰트(나눔고딕, `assets/fonts/`)뿐이다. 몬스터/타워/
  개발자처럼 반복 사용되는 스프라이트는 `love.graphics.newCanvas`에 16x16 논리 도트를 `px=2`로
  한 번 찍어 시트 이미지를 만든 뒤(`art.load()`, 부팅 시 1회) `Quad`로 잘라 매 프레임 그린다 —
  매 프레임 도트를 다시 찍지 않는다.
- **팔레트 통일**: 모든 색상은 `art.pal`(네온 서버실 팔레트 — `bg/panel/green/cyan/magenta/red/
  orange/purple/white` 등)의 상수를 쓴다. 새 에셋을 추가할 때 임의의 hex 색을 즉석에서 넣지
  말고, 기존 톤과 맞는 `art.pal` 항목을 재사용하거나 필요하면 팔레트에 추가한다.
- **draw 헬퍼는 끝에 `love.graphics.setColor(1, 1, 1)`로 색을 복원한다.** `art.lua`의 모든
  `draw*` 함수(그리고 이를 호출하는 `states/*.lua`의 그리기 코드)는 자기 색을 스스로 관리하고
  반환 전 흰색으로 되돌려, 다음에 그려지는 요소가 이전 색을 물려받지 않게 한다.
- **`love.timer` 직접 호출 금지 — 시간은 `t` 인자로 받는다.** `src/art.lua`·`src/particles.lua`·
  `src/cutscene.lua`는 `love.timer.getTime()`을 스스로 부르지 않는다. 애니메이션에 필요한 현재
  시각은 호출부(`states/*.lua`)가 한 번만 `love.timer.getTime()`으로 읽어 `t` 인자로 넘긴다 —
  테스트에서 순수 함수로 호출 가능하게 유지하기 위함이다.
- **파티클은 뷰 전용, 상한 400개**. `src/particles.lua`의 파티클 풀은 전투 시뮬레이션 상태를
  전혀 읽거나 쓰지 않는 순수 뷰 이펙트이며(`spark`/`burst`/`float`/`smoke`/`flash` 5종), 풀
  크기가 `particles.MAX`(400)를 넘으면 가장 오래된 파티클부터 제거한다.
- **이펙트는 프레임-diff 기반 뷰 전용이며 전투 코어는 불변이다.** `states/play.lua`는 매 프레임
  `battle` 코어의 상태(적 생사, 타워 쿨다운/크래시, `serverHP`, 타워 수 등)를 이전 프레임 스냅샷과
  비교해(`self.fx.prev*`) 처치 버스트+보상 float, 서버 피격 셰이크+빨간 테두리, 설치 플래시,
  크래시 연기/스파크/개발자 아바타 놀람 포즈 같은 이펙트를 발동시킨다. `src/battle.lua`
  자체에는 이펙트를 위한 코드를 추가하지 않는다 — 코어는 순수 시뮬레이션으로 남기고, 뷰가
  코어 상태를 읽기만 해서 프레임 간 변화를 감지하는 방식을 유지한다.

## 구현된 규칙

- **실시간 코어 루프**: 준비 단계가 없다. 스테이지에 입장하면 즉시 `battle:start()`가 호출되어
  카운트다운(스테이지별 `countdown`, 15~30초, `clock`이 음수 구간)부터 실시간으로 진행되고,
  카운트다운이 끝나면 곧바로 웨이브가 밀려온다. 전투는 멈추지 않으며(구 `pause_at` 없음),
  `clock`이 300초(`TOTAL`)에 도달하면(=서버 생존) 자동으로 클리어 처리된다. 그리드 배치, 코드
  에디터, 전투 진행이 `states/play.lua` 한 화면에서 동시에 이루어진다.
- **통합 스크립트**: 타워를 짓는 유일한 수단은 스크립트 안에서 호출하는
  `build(type, r, c, name)`이다. 4번째 인자(고유 이름)가 필수이며, 이미 같은 이름의 타워가
  있으면 성공을 반환하되 아무 일도 하지 않는 **멱등** 동작이다(`src/battle.lua`의
  `buildTower`) — F5로 스크립트가 반복 실행돼도 기존 타워가 중복 건설되지 않는다. 돈(`money`)은
  스테이지 시작 예산(`budget`)에 적 처치 보상(`enemies.csv`의 `reward`)이 누적되는 방식이며,
  건설 비용은 즉시 차감된다. **F5**를 누르면 에디터의 전체 코드를 최상위부터 재실행하고
  `on_tick`을 새 버전으로 교체한다(`Battle:setScript`) — 문법/실행 오류가 나면 기존 코드와 이미
  지어진 타워는 그대로 유지되고 화면에 빨간 오류 메시지만 표시된다(`b.scriptError`). 스크립트
  env는 전투당 하나만 만들어 모든 타워가 공유하며(`api.buildEnv`), 그중 `cache`(아이템)는
  타워 간에 값을 주고받는 공유 저장소로 쓸 수 있다. `on_spawn(fn)`으로 등록한 콜백은 적이
  스폰될 때 `fn(enemy)` 형태로 호출되며, 이때 넘어오는 스냅샷에는 타워 기준 `dist`가 없다
  (`api.plainSnapshot`) — `world.enemies()` 등이 주는 스냅샷과 다른 축약형이다.
- **조작**: F5(저장·반영), F1~F4(코드 스니펫 퀵바), Ctrl+1/2/4(배속 x1/x2/x4), ESC(스테이지
  선택으로 나가기)가 기본이다. 버튼 모드 스테이지(1~2)는 숫자키로 버튼을 누른다. 구 조작이던
  Tab(포커스 전환)/B(건설)/T(타워 순환)/Space(전략 순환)는 통합 스크립트 도입과 함께
  삭제되었다 — 건설은 코드의 `build()` 호출로만 한다. 타이틀 화면은 ↑↓로 메뉴(게임 시작/
  세계관/종료) 이동, Enter로 확정한다. 인트로 컷신은 Enter(타이핑 중이면 즉시 완성, 완성 후엔
  다음 장면)로 진행하고 ESC로 전체 스킵한다.
- **세계관·비주얼**: `states/intro.lua`가 첫 실행 시 자동으로(또는 타이틀 "세계관" 메뉴로 언제든)
  4장면 컷신을 보여준다 — 지상의 화려한 서비스 → 새벽 서버실의 개발자 → 버그로 인한 장애 발생 →
  코드로 맞서는 결의. 장면마다 `src/art.lua`의 코드 생성 일러스트와 `src/cutscene.lua`의 초당
  30자 타이프라이터 텍스트가 함께 나온다. 타이틀 화면은 네온 서버실 배경에 로고와 책상 앞
  개발자 뒷모습을 그린다. 전투 화면(`states/play.lua`)에는 코드 생성 픽셀아트 몬스터/타워,
  `src/particles.lua` 이펙트, IDE 패널 옆 개발자 미니 아바타(저장 시 타이핑 포즈, 타워 크래시
  시 놀람 포즈)가 있다. 결과 화면(`states/result.lua`)은 클리어/패배에 맞는 여운 문구를 덧붙인다
  (예: 클리어 — "오늘도 서비스는 무사히 돌아간다. 아무 일 없었다는 듯이.").
- **버튼 스테이지**: `ui=button` 스테이지(1~2)는 코드 에디터를 직접 노출하지 않는다. 숫자키를
  누르면 `stages.csv`의 `buttons_file`(`data/curriculum/buttons_1.lua`,`buttons_2.lua`)에 정의된
  버튼의 스크립트가 초당 40자 속도로 에디터에 자동 타이핑되고, 타이핑이 끝나면 자동으로
  저장(`Battle:setScript`)까지 실행되는 **생성기**다(`states/play.lua`의 `pressButton`/
  `update`의 오토타이핑 블록).
- **튜토리얼**: 스테이지 1~4에 가이드 오버레이가 있다(`src/tutorial.lua` +
  `data/curriculum/tutorial_1.lua`~`tutorial_4.lua`, `stages.csv`의 `tutorial_file`). 하단
  말풍선으로 스텝 텍스트를 보여주며, **Enter**로 다음 스텝, **Ctrl+X**로 전체 스킵한다. 설명
  중심 스텝은 `allow={}`(또는 허용 키 목록)로 타이핑/건설 입력을 잠가 가이드를 따라가게 만든다
  (`Tutorial:allows`/`allowsText`). 완료하거나 스킵하면 `progress.tutorial_done[stageId]`에
  저장되어(`src/progress.lua`) 같은 스테이지를 재방문할 때는 다시 표시되지 않는다 — 리셋하려면
  저장 파일(`progress.lua`, `love.filesystem` 유저 폴더)을 지우는 방법뿐이다. 튜토리얼이 진행
  중일 때는 화면 하단 힌트바(조작 안내)가 숨겨진다(말풍선과 겹치지 않도록).
- **샌드박스**: 유저 코드는 `math/string/table`의 순수 함수만 볼 수 있는 격리 환경에서 실행되며
  (`io/os/love/debug/loadstring/_G` 등 차단), `debug.sethook`의 카운트 훅으로 명령 예산을 강제한다.
  정의부(최상위) 실행에도 별도 예산(`COMPILE_BUDGET`)이 있어 무한 루프인 코드는 컴파일 단계에서
  걸러진다.
- **전투 루프**: 10Hz(`TICK = 0.1`) 의사결정, 틱당 명령 예산(`BUDGET = 3000`), 일반 모드 총
  300초(`TOTAL`) 생존 시 클리어. 예산을 절반 미만으로 쓰면 오버클럭 배율이 1.0에 수렴해 발사
  속도가 빨라진다.
- **크래시/워치독**: 런타임 오류가 나면 타워가 3초(`WATCHDOG`) 동안 "크래시" 상태로 비활성화된
  뒤 자동 재시작한다. 재시작 직후 곧바로 다시 크래시하면(`recovering` 플래그) 영구 비활성화되어
  더 이상 재시작을 시도하지 않는다.
- **몬스터 능력**: `crash_tower`(널 포인터 — 서버 도달 시 최근접 타워 강제 크래시),
  `split`(concat-nil — 사망 시 체력 절반씩 둘로 분열). CSV의 `abilities` 필드로 조합 가능.
- **타워 종류**: `printer`(기본 발사기, cost 100), `compiler`(공격하지 않는 테크 타워, cost 50,
  고급 타워 건설을 해금), `sniper`(장거리 저격, cost 150, `requires=compiler` — 필드에 컴파일러가
  있어야 건설 가능)(`data/towers.csv`).
- **진행도**: 클리어 여부, 획득 아이템(`cache`/`webhook`), 스테이지별 저장 코드, 튜토리얼 완료
  여부를 `love.filesystem` 유저 폴더에 저장(`src/progress.lua`). 아이템은 `data/items.csv`의
  `api` 필드로 타워 env에 어떤 함수를 추가로 열어줄지 결정한다 (`cache.get/set`, `on_spawn`).
  아이템은 획득 시 배치되는 모든 타워에 자동 장착된다 (0.1 규칙; 타워별 개별 장착 UI는 0.2).

## 알려진 한계

- 샌드박스의 명령 예산 훅은 C 함수 내부에서는 적용되지 않는다 (`string.rep(1e9)` 같은 호출은
  훅이 개입하기 전에 이미 오래 걸릴 수 있음). 싱글플레이어이고 자기 자신의 타워/틱만 느려지는
  자기피해에 한정되므로 v0.1에서는 수용 범위로 판단했다.
- `sandbox.call`은 `debug.sethook`을 전역으로 설정/해제하므로 **비재진입**이다. 타워 콜백 안에서
  또 다른 샌드박스 실행을 중첩 호출하지 않는다.
- 크래시 루프에 빠진 타워(워치독 복구 직후 재크래시)는 해당 전투 동안 영구 비활성화되며,
  플레이어가 되살릴 방법은 없다(재입장/재도전으로 새 배치를 해야 함). 의도된 교육적 페널티.
- **env의 `self`는 전투당 하나만 만들어 모든 타워가 공유한다**(`api.buildEnv`의 `env._selfApi`,
  `api.refresh`가 매 틱 그 값을 현재 타워 기준으로 덮어씀). `on_tick` 안에서 `self`를 그대로
  클로저나 외부 변수에 저장해 나중에 참조하면, 그 시점의 타워가 아니라 **가장 최근에 `refresh`된
  타워의 값**을 보게 된다. 타워별 상태를 기억하려면 `self.name`을 키로 `cache`(아이템)나
  스크립트 최상위의 로컬 테이블에 저장해야 한다.

## 다음 단계 (0.2+)

v0.1은 코어 루프(카운트다운→실시간→300초 생존)·샌드박스·에디터·통합 스크립트(`build`)·
아이템 해금·테크 의존성·코드 크래프트(오버클럭)·튜토리얼·CSV 데이터 기반 스테이지 8종까지의
범위다. 설계서(`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md`) 9장 기준으로
다음이 남아 있다.

- **하드코어 모드**: 50단계, 클리어 타임 계측
- **클리어 타임 인증·공유**: 인증 카드 PNG 자동 생성 + 해시태그 공유 텍스트 클립보드 복사
- **밈 도감 UI**: 몬스터별 "실제 오류가 언제 나는지 + 어떻게 고치는지" 텍스트 영구 수집
- **아이템 확장**: CPU 코어 증설(명령 예산 증가), 공용 라이브러리 탭 등 인벤토리 심화
- **언어 진영 시스템**: 진영 선택 UI·보너스 데이터·언어별 랭킹 분리는 v1 프레임워크로 넣되,
  실행 가능한 진영은 Lua 하나로 시작 (Python/JS/C#은 외부 프로세스 어댑터로 v2 확장)
- **타워 매도(sell)**, 진행도 리셋 메뉴: 스펙에서 명시적으로 이연됨

## 테스트

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

`tests/main.lua`가 `tests/test_*.lua` 스위트를 전부 실행하고 `RESULT pass=N fail=N`을 출력한다
(현재 156개, 전부 PASS — `test_particles.lua`·`test_cutscene.lua`가 뷰 전용 이펙트/컷신 로직을
다룬다). 실패가 있으면 콘솔 종료 코드도 0이 아니게 된다.

스테이지를 추가할 때는 `data/curriculum/<n>_solution.lua`를 **반드시** 함께 추가해야 한다 —
`tests/test_battle.lua`가 CSV에 등록된 모든 스테이지를 순회하며 `solution_file`의 코드로 실제
전투를 실행해 클리어(300초 서버 생존)까지 확인하는 회귀 테스트이므로, 정답 코드가 없거나
틀리면 테스트가 실패해 스테이지 추가가 자동으로 검증된다. 회귀 테스트는 `Battle:setScript`로
정답 스크립트를 주입하는 방식이며, 스크립트 안의 `build()` 좌표는 반드시 스테이지 예산
(`budget`) 안에서 지을 수 있는 조합이어야 한다.
