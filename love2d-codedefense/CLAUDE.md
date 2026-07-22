# love2d-codedefense

LÖVE (Love2D) 11.5 기반 코딩 교육용 타워디펜스 《Code Defense》. 플레이어가 게임 내 에디터에서
Lua 코드(`on_tick(self, world)`, `build(type, r, c, name)`)를 작성해 타워를 조종하고, 위에서
내려오는 밈 몬스터(버그/널 포인터/concat-nil)를 막습니다. 설계서:
`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md` (레포 루트 기준, 4.1/5.1절이
이번 실시간 개편 반영), 튜토리얼 설계서:
`docs/superpowers/specs/2026-07-21-codedefense-tutorial-design.md`, 스테이지 경험 개선 설계서:
`docs/superpowers/specs/2026-07-22-codedefense-stage-experience-design.md`(적 구성 패널·진행
바·문제 브리핑·메모리 테마 미로·히든 타워·도감·퍼즐·배포 로그), 비주얼·세계관 설계서:
`docs/superpowers/specs/2026-07-22-codedefense-visual-lore-design.md`.

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
├─ conf.lua               ← 창 크기(1280x640, play만 3칼럼 재배치·나머지 화면은 960 기준 레이아웃을
│                            중앙 정렬로 감쌈), 타이틀 등 설정
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
│  ├─ cutscene.lua          ← 컷신(인트로) 진행 순수 로직 — 장면 전환, 초당 30자 타이프라이터
│  └─ stageinfo.lua         ← 적 구성 패널·문제 카드용 순수 집계(전체 수/종류별 수/마지막 스폰
│                               종료 시각/처리 수) — battle의 timeline/spawned/enemies를 읽기만
│                               한다. 뷰 비의존, 헤드리스 테스트 가능(`tests/test_stageinfo.lua`)
├─ states/                ← hump Gamestate 화면들 (뷰 전담, 로직은 src/battle.lua·src/tutorial.lua에 위임)
│  ├─ intro.lua             ← 인트로 컷신 4장면 (첫 실행 1회 자동 재생, 타이틀 "세계관" 메뉴로 재생)
│  ├─ title.lua             ← 타이틀 메뉴 4항목(게임 시작/세계관/도감/종료), 로고 위 룩(Rook) 심볼,
│  │                            ↑↓+Enter 및 마우스(호버 이동·좌클릭 선택) 겸용
│  ├─ stageselect.lua       ← 스테이지 목록 + 배포 기록 표기(`[클리어 · HP n · 구]`/`[시도 n]`)
│  ├─ play.lua              ← 3칼럼(전장 384 / 정보 칼럼 240 / 에디터 610): 그리드 + 코드
│  │                            에디터 + 실시간 전투 + 정보 칼럼(문제 요약·적 구성·함수 사전·
│  │                            전투 로그)·진행 바·문제 카드·구구 클래스 소환 연출을 한 화면에서
│  │                            진행 (구 prep/battle 통합, 전장 오버레이는 정보 칼럼으로 이동)
│  ├─ result.lua            ← 클리어/패배 결과 + 배포 로그 한 줄(§6.7) + 여운 문구, Enter/좌클릭 공용
│  └─ codex.lua             ← 도감: 타워/몬스터/내 함수 3탭(←/→ 순환), 히든 타워 ??? 카드
│                               (뷰 전용, `progress.gugu_found`로 공개 여부 판정). 내 함수 탭은
│                               `progress.funcbook`(이름→{first,count})을 이름 정렬로 나열한다
├─ data/
│  ├─ towers.csv, enemies.csv, items.csv, stages.csv, timelines.csv
│  ├─ mazes/                ← 스테이지별 미로 텍스트(#=벽, .=통로, B=건설칸), 12개(001~012),
│  │                            12×16 규격, 테마별 형태(§ "메모리 테마 미로" 참고)
│  └─ curriculum/            ← 스테이지별 solution(정답)·hints(따라치기/빈칸)·tutorial(가이드)·
│                               buttons(생성기)·naive(퍼즐 스테이지 순진 배치, 반드시 패배해야 함) Lua 파일
├─ tests/                  ← lovec tests로 실행하는 자체 테스트 러너 (206개, 11개 스위트:
│                               csv/grid/sandbox/battle/data/editor/progress/tutorial/particles/
│                               cutscene/stageinfo)
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
복귀). 타이틀 메뉴는 4항목(게임 시작/세계관/도감/종료)이며, "도감"을 고르면 `codex` 상태로
전환됩니다(ESC로 다시 `title`로).

## 코딩 규칙

- 전투 로직(카운트다운, 스폰, 틱, `build` 처리, 공격 판정, 승패 등)은 반드시 `src/battle.lua`
  코어에 둔다. `states/*.lua`는 렌더링과 입력만 담당하는 뷰이며, 게임 규칙을 states에 새로
  넣지 않는다. 튜토리얼 진행 로직(스텝 전환, 허용 키 판정)도 마찬가지로 `src/tutorial.lua`에
  두고 `states/play.lua`는 그리기와 키 라우팅만 한다.
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지).
- 화면 전환은 hump의 `Gamestate` 사용 (intro / title / stageselect / play / result / codex).
- 스테이지 추가는 코드가 아니라 **데이터로만** 한다 — `data/stages.csv`(+ 필요 시
  `timelines.csv`)에 행을 추가하고, `data/mazes/<n>.txt` 미로와
  `data/curriculum/<n>_solution.lua`(필수)·`<n>_hints.lua`(hint 모드일 때)를 함께 둔다.
  버튼 모드(`ui=button`) 스테이지라면 `buttons_file`에 생성기 Lua(`data/curriculum/buttons_<n>.lua`)를,
  가이드가 필요한 스테이지라면 `tutorial_file`에 튜토리얼 스텝 Lua
  (`data/curriculum/tutorial_<n>.lua`)를 함께 등록한다. `countdown`(15~30초 권장)도 스테이지마다
  지정해야 한다. `solution_file`은 필수 — 회귀 테스트(`tests/test_battle.lua`)가 각 스테이지의
  정답 코드로 실제 클리어가 되는지 자동 검증하므로, 정답 없이 스테이지를 추가하면 테스트가
  실패한다.
  - **문제 브리핑 열**: `theme`(메모리 영역명 — "코드 영역"/"데이터 영역"/"스택"/"힙" 등, 문제
    카드에 "메모리 영역: X"로 표기)과 `problem`(한 줄 문제 서술, 코딩테스트 문제지 톤)도 모든
    스테이지에 채운다. 미로 형태는 테마와 어울리게 짓는다 — 코드 영역=정연한 가로 행 /
    데이터 영역=블록 격자 / 스택=위에서 쌓이는 지그재그 / 힙=단편화 조각(12×16 규격, 건설칸
    ≥6). 같은 테마의 3개 스테이지는 같은 문법 개념의 난이도 변주로 설계한다.
  - **퍼즐 열**: 해당 스테이지를 "정답 배치가 사실상 강제되는" 퍼즐로 만들고 싶으면
    `puzzle`에 `1`을 넣고(빈 값=자유 배치), `naive_file`에 "순진하게(단순 사거리 배치 등)
    지었을 때 반드시 패배하는" 스크립트 경로(`data/curriculum/<n>_naive.lua`)를 채운다.
    회귀 테스트가 `solution_file`은 클리어, `naive_file`은 반드시 defeat임을 자동
    증명하므로(데이터 주도 음성 회귀), 순진 배치가 실제로 이기면 테스트가 실패한다. 코드
    판정 철학(§0, 결과만 봄)은 불변 — 좁아지는 것은 미로·예산이 강제하는 전술 해공간이지
    코드 형태가 아니다.
  - **타임라인 규칙(`d.validate()`가 기계 검증)**: `mode=normal`인 스테이지는 (1) 마지막 스폰
    이벤트 종료 시각(`at + (count-1)*interval`)이 240초 이상이어야 하고, (2) 인접한 두 스폰
    이벤트 사이의 공백이 40초를 넘으면 안 된다. 300초 전투 시간을 스폰으로 고르게 채우기
    위한 규칙이며, 위반하면 부팅 시 `main.lua`가 즉시 에러로 중단한다.
- **결정론 원칙**: 게임 로직에 랜덤을 쓰지 않는다. 같은 배치·같은 코드는 항상 같은 결과가
  나와야 회귀 테스트와 하드코어 스피드런 기록이 의미를 가진다.
- 스폰 열은 미로 1행의 통로(`.`)와 일치해야 한다 — `src/db.lua`의 `d.validate()`가 이를
  기계 검증하며, `main.lua`가 부팅 시 항상 이 검증을 돌려 오류가 있으면 즉시 에러로 중단시킨다.
- CSV 빈 셀 처리에 주의: 숫자 필드(`cost`, `hp`, `budget`, `countdown`, `puzzle`, `limit`,
  `hidden` 등, `src/db.lua`의 `index()` 두 번째 인자 목록)의 빈 셀은 `nil`로 변환되지만,
  텍스트 필드(`requires`, `abilities`, `reward_item`, `tutorial_file`, `buttons_file`, `theme`,
  `problem`, `naive_file`, `ability` 등)의 빈 셀은 `""`(빈 문자열)로 남는다. `nil` 체크가 아니라
  `x ~= ""` 형태로 비교해야 한다(`src/db.lua`의 `index()` 참고). 단, `naive_file`처럼 옛 CSV(열
  자체가 없던 시절 저장된 진행 파일 등)와의 호환을 위해 `s.naive_file and s.naive_file ~= ""`처럼
  존재 여부까지 함께 체크하는 코드도 있다(`d.validate()` 참고).

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
- **조작**: F5(저장·반영), F1~F4(코드 스니펫 퀵바), Ctrl+1/2/4(배속 x1/x2/x4), Ctrl+I(문제
  브리핑 카드 토글 — 아래 참고), ESC(스테이지 선택으로 나가기)가 기본이다. 버튼 모드
  스테이지(1~2)는 숫자키로 버튼을 누른다. 구 조작이던 Tab(포커스 전환)/B(건설)/T(타워
  순환)/Space(전략 순환)는 통합 스크립트 도입과 함께 삭제되었다 — 건설은 코드의 `build()`
  호출로만 한다. 타이틀 화면은 ↑↓(또는 마우스 호버)로 메뉴(게임 시작/세계관/도감/종료, 4항목)
  이동, Enter(또는 좌클릭)로 확정한다. "도감"을 고르면 `codex` 상태로 들어간다 — ←/→로 탭
  (타워/몬스터/내 함수, 3탭) 전환, ↑↓로 목록 이동, ESC로 타이틀 복귀. 인트로 컷신은
  Enter/좌클릭(타이핑 중이면 즉시 완성, 완성 후엔 다음 장면)로 진행하고 ESC로 전체 스킵한다.
  결과 화면은 Enter 또는 좌클릭으로 스테이지 선택으로 돌아간다. **play 화면의 마우스**:
  `play:mousepressed`가 좌클릭을 두 영역에서 받는다 — ① 에디터 안에서 `build`나
  `battle.userFuncs`에 등록된 식별자를 클릭하면 함수 사전 카드가 펼쳐지고(재클릭 시 접힘),
  ② 정보 칼럼의 사전 목록 항목을 직접 클릭해도 같은 토글이 일어난다(자세한 동작은 "함수
  사전" 절 참고). 그 외 클릭(빈 곳, 우클릭 등)은 무시된다 — 타워 건설은 여전히 코드의
  `build()` 호출로만 한다.
- **3칼럼 레이아웃** (`states/play.lua`): `play` 화면은 창(1280×640) 안에서 좌→우로 전장(x=8,
  w=384) / 정보 칼럼(x=400, w=240) / 에디터(x=656, w=610) 세 칼럼으로 나뉜다. 구 버전의 전장
  우상단 오버레이(적 구성 패널·전투 로그)는 모두 정보 칼럼으로 흡수되었다 — 전장에는 더 이상
  텍스트 오버레이가 없다. 셰이크는 전장에만 적용되고 정보 칼럼·에디터·HUD는 고정이다.
- **정보 칼럼** (x=400, y=48, w=240, h=512 — 전장과 바닥이 나란함): 위에서부터 순서대로
  ① **문제 요약**(`[문제 N] concept` / `메모리 영역: theme` / `Ctrl+I 상세` 안내),
  ② **적 구성**(구 전장 우상단 오버레이 — 스테이지 등장 적 종류별 미니 스프라이트 +
  "처리 n / 전체 N", 모든 스폰이 끝나면 "잔여 소탕 · 생존!" 한 줄 추가),
  ③ **함수 사전**(아래 별도 절 참고),
  ④ **전투 로그**(구 전장 오버레이 — 최근 8줄, 오래된 줄일수록 옅어지는 페이드)가 이어진다.
  상단 HUD 바로 아래에는(전장 폭 기준) 300초 대비 현재 진행률과 스폰 이벤트 시점 눈금을 그리는
  얇은(4px) 진행 바가 별도로 있다. 스테이지 진입(카운트다운 중)에는 전장+정보 칼럼을 아우르는
  중앙에 문제 카드가 자동으로 뜬다 — `[문제 N] concept`, `메모리 영역: theme`, `problem` 한 줄
  서술, `예산 X · 유입 예정 N기`, 제출/채점 안내를 보여주며 Enter로 닫고 전투 중 언제든 Ctrl+I로
  다시 연다. 튜토리얼 말풍선이 활성 상태면 문제 카드보다 z순서상 위에 그려져 튜토리얼이
  우선한다.
- **함수 사전** (`states/play.lua`의 `drawFuncDict`/`drawDictCard` — 정보 칼럼 ③): 빌트인 함수
  `build`의 문서(시그니처·설명 5줄·예시)가 `BUILTIN_DOCS` 리터럴로 항상 목록 첫 줄에 있고, 그
  아래로 유저 정의 함수 목록이 이어진다.
  - **수집 원리(env diff)**: `Battle:setScript`(`src/battle.lua`)가 F5로 코드를 저장할 때마다
    `api.buildEnv`로 만든 env의 키 집합을 컴파일 *전*에 스냅샷(`known`)해 두고, 컴파일 *후* env에
    새로 생긴 키 중 `type(v) == "function"`인 것만 이름 정렬해 `battle.userFuncs`에 담는다.
    **`local function`은 감지되지 않는다** — 로컬 함수는 청크의 지역 변수일 뿐 env 테이블에
    할당되지 않기 때문이다(전역으로 정의한 `function foo() end`만 env에 남는다). 정보 칼럼에는
    "(local 함수는 목록에 잡히지 않아요)" 안내가 항상 붙는다.
  - **클릭 → 펼침**: 에디터 안에서(`Editor:charAt`+`Editor.tokenAt`로 클릭 좌표 → 식별자 토큰
    변환) `build` 또는 `battle.userFuncs`에 있는 식별자를 좌클릭하거나, 정보 칼럼의 사전 목록
    항목(`self.dictRows`)을 직접 좌클릭하면 `self.dictOpen`이 토글된다(같은 항목 재클릭 시
    접힘). 펼쳐지면 목록의 해당 줄 바로 아래에 카드가 삽입되어 이후 섹션(예: 전투 로그)을
    밀어낸다 — 빌트인(`build`)은 `BUILTIN_DOCS`의 문서 카드, 유저 함수는
    `extractFuncSource`(`function 이름` 줄부터 function/if/for/while/do(+1)·end(-1) 키워드
    카운팅으로 대응 `end`까지 훑는 휴리스틱, 정밀 파서 아님)가 뽑은 소스 발췌를 `L시작줄번호` +
    최대 10줄(초과 시 "…" 절단)로 보여준다.
  - **`BUILTIN_DOCS` 확장법**: 새 빌트인 API를 문서화하려면 `states/play.lua`의
    `BUILTIN_DOCS` 테이블에 `{ sig = "이름(인자...)", lines = {설명 줄...}, example = "예시 코드" }`
    항목을 키(함수 이름)로 추가하면 `drawDictCard`가 자동으로 카드를 그린다 — 별도 렌더 코드를
    추가할 필요는 없다.
  - **funcbook 영구 수집** (`src/progress.lua`의 `p.funcbook`, `play:save`): F5 저장이 성공할
    때마다 `battle.userFuncs`를 훑어 판당(전투당) 이름별로 **한 번만**(`self.funcCounted` 가드)
    `p.funcbook[name] = { first = stageId, count = 0 }`를 만들고 `count`를 1 증가시켜
    `progress.save`로 영구 저장한다. 도감(`states/codex.lua`)의 3번째 탭 **"내 함수"**가 이
    `funcbook`을 이름 정렬로 나열하고, 카드는 "스테이지 N에서 처음 정의 · M회"를 보여준다(아직
    없으면 "아직 수집된 함수가 없습니다..." 안내).
- **세계관·비주얼**: `states/intro.lua`가 첫 실행 시 자동으로(또는 타이틀 "세계관" 메뉴로 언제든)
  4장면 컷신을 보여준다 — 지상의 화려한 서비스 → 새벽 서버실의 개발자 → 버그로 인한 장애 발생 →
  코드로 맞서는 결의. 장면마다 `src/art.lua`의 코드 생성 일러스트와 `src/cutscene.lua`의 초당
  30자 타이프라이터 텍스트가 함께 나온다. 타이틀 화면은 네온 서버실 배경에 로고와 책상 앞
  개발자 뒷모습, 그리고 로고 위 룩(Rook, 체스 성탑) 심볼을 그린다 — `art.drawRook(x, y, scale, t)`가
  16×16 도트(총안 3개+몸통+받침, green 몸체·cyan 하이라이트)를 직접 그리고, `art.rookIconData()`가
  같은 도트를 32×32 `ImageData`로 만들어 `main.lua`가 부팅 시 `love.window.setIcon`으로 창/작업
  표시줄 아이콘을 설정한다. intro/title/stageselect/result/codex는 `love.graphics.getWidth()` 기반
  중앙 정렬로 1280 폭 창에 대응한다(intro의 960×420 일러스트는 재작업 없이 `translate`로 중앙에
  감쌈). 전투 화면(`states/play.lua`)에는 코드 생성 픽셀아트 몬스터/타워,
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
  있어야 건설 가능), `gugu-class`(히든 — 아래 별도 절 참고)(`data/towers.csv`). `towers.csv`에는
  `limit`(스테이지당 최대 설치 수, 빈 값=무제한), `hidden`(1=도감에서 발견 전 "???"로 표시),
  `ability`(엔진이 인식하는 특수 능력 키워드 — 현재 `gugu` 하나뿐, `battle.lua`가 이 키워드로
  분기)의 3개 열이 추가돼 있다.
- **퍼즐 스테이지 (6·9·12)**: `stages.csv`의 `puzzle=1`인 스테이지는 미로·예산·적 구성이 특정
  배치를 사실상 강제하도록 설계됐다 — 6(건설칸이 전부 프린터 사거리 밖 가장자리라 컴파일러+
  스나이퍼 조합 필수), 9(사거리가 닿는 건설칸이 극소수), 12(독립된 3차선이라 분할 지점마다
  타워가 필요). 판정 철학은 그대로다(§0 무변경, 코드 형태가 아니라 결과만 봄) — 좁아지는 것은
  전술 해공간이지 정답 코드 강제가 아니다. `naive_file`(예: `curriculum/006_naive.lua`)에 "사거리
  등을 고려 안 하고 단순하게 지으면" 나오는 스크립트를 등록해 두면, 회귀 테스트가 그 배치는
  반드시 defeat임을(= "브루트포스는 시간초과") 결정론으로 증명한다.
- **히든 타워 "구구 클래스"** (한국 코딩 밈 오마주 — **스포일러이므로 이 항목은 CLAUDE.md에만
  전체 기록하고 README.md에는 절대 옮기지 않는다**):
  - 소환: 코드에서 `build("gugu-class", r, c, name)` 또는 한글 별칭 `build("구구클래스", r, c, name)`
    (둘 다 인정 — `Battle:buildTower`가 별칭을 `gugu-class`로 정규화). `requires` 없음, `limit=1`
    (스테이지당 1개, 초과 시 "구구 클래스는 스테이지당 1개뿐입니다").
  - 스탯(`data/towers.csv`): cost 120, damage 6(기본), range 150, cooldown 1.0, bullet_speed 420,
    color `0.95;0.75;0.2`(금색), desc "위기의 순간 소환되는 전설의 클래스. 시간이 지날수록 단이
    오른다 (2단→9단, 데미지 ×단)".
  - **단(段) 성장** (`ability=gugu`, `Battle:update`): 설치 시 `tw.dan = 2`로 시작, 전투 중
    (`clock >= 0`) 30초마다 `dan`이 1씩 올라 최대 9단까지 성장한다(`tw.danTimer` 누적).
    실효 데미지는 `Battle:resolveAttack`에서 `tw.def.damage * (tw.dan or 1)`로 계산 —
    2단=12, 9단=54. 단이 오를 때마다 전투 로그: `"[구구 클래스] N단 돌입! N × 1 = N..."`.
  - **소환 연출** (`states/play.lua`, 뷰 전용 frame-diff): 새 타워 목록에서 `def.id == "gugu-class"`가
    감지되면(`fx.guguFx = 1.2`) 1.2초짜리 전체 화면 연출이 재생된다 — 처음 0.3초는 흰 화면
    플래시(`fx.guguFx > 0.9`), 이어서 금색 테두리 펄스 + 전장 셰이크(`fx.shake = 0.4`) + 중앙
    배너 "전설의 클래스, 소환." + 전장 6곳(3열×2행)에 구구단 텍스트 파티클("2 × 1 = 2" ~
    "2 × 6 = 12", 1.4초 생존)이 떠오른다. `src/battle.lua` 코어에는 이펙트 코드가 없다.
  - **스프라이트**: `src/art.lua`의 `drawGuguFrame`이 김이 나는 커피잔(자바 밈 — 받침(소서) +
    머그컵 + 손잡이 + 김) 4프레임 시트를 `tower_gugu-class`로 빌드한다.
  - **도감 공개**: `states/codex.lua`가 `def.hidden == 1 and not p.gugu_found`이면 타워 목록에
    "???"로만 표시하고, 카드도 이름/설명/스탯을 전부 "???"·"?"로 가리며 수수께끼 힌트만 보여준다
    — "장애가 터지면 회의실 화면 앞에서 실시간으로 코딩을 시작한다는 전설의 클래스. Java로 짠
    그것의 이름을 아는 자만이 소환할 수 있다." 전투 중 최초로 필드에 등장하면(`states/play.lua`
    의 `update`) `progress.gugu_found = true`가 영구 저장되어 이후 도감에 실제 이름·스탯·예시
    코드가 공개된다.
- **배포 로그** (개발자 친숙한 "배포 이력" 콘셉트, `src/progress.lua` + `states/result.lua` +
  `states/stageselect.lua`): 스테이지마다 `progress.records[stageId] = { tries, clears, bestHP,
  lastResult, gugu }`를 저장한다(`gugu`는 한 번이라도 구구 클래스를 투입하면 영구 `true`).
  결과 화면은 이번 판 로그 한 줄을 보여준다 — 성공 `"배포 #N 성공 · 서버 HP h 잔존 · 타워
  t기[ · 구구 클래스 투입]"`, 실패 `"배포 #N 롤백 · ..."`. `result:enter`는
  `self.recordedCtx ~= ctx` 가드로 같은 전투 결과를 두 번 기록하지 않는다. 스테이지 선택
  화면은 항목 옆에 기록을 붙인다 — 클리어면 `[클리어 · HP n · 구]`(구구 사용 시), 미클리어면
  `[시도 n]`, 기록이 아예 없으면 미표기. ("九"는 나눔고딕에 글리프가 없어 "구"로 표기한다.)
- **진행도**: 클리어 여부, 획득 아이템(`cache`/`webhook`), 스테이지별 저장 코드, 튜토리얼 완료
  여부, 배포 기록(`records`), 구구 클래스 발견 플래그(`gugu_found`)를 `love.filesystem` 유저
  폴더에 저장(`src/progress.lua`). 아이템은 `data/items.csv`의 `api` 필드로 타워 env에 어떤
  함수를 추가로 열어줄지 결정한다 (`cache.get/set`, `on_spawn`). 아이템은 획득 시 배치되는
  모든 타워에 자동 장착된다 (0.1 규칙; 타워별 개별 장착 UI는 0.2).

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
아이템 해금·테크 의존성·코드 크래프트(오버클럭)·튜토리얼·CSV 데이터 기반 스테이지 12종(테마당
3개)·적 구성 패널·진행 바·문제 브리핑·히든 타워·도감·배포 로그까지의 범위다. 설계서
(`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md` 9장,
`docs/superpowers/specs/2026-07-22-codedefense-stage-experience-design.md`) 기준으로 다음이
남아 있다.

- **하드코어 모드**: 50단계, 클리어 타임 계측
- **클리어 타임 인증·공유**: 인증 카드 PNG 자동 생성 + 해시태그 공유 텍스트 클립보드 복사
- **밈 도감 심화**: 몬스터별 "실제 오류가 언제 나는지 + 어떻게 고치는지" 텍스트 영구 수집
  (현재 도감은 스탯·능력 카드까지만 — 실제 오류 텍스트 확장은 이연)
- **아이템 확장**: CPU 코어 증설(명령 예산 증가), 공용 라이브러리 탭 등 인벤토리 심화
- **언어 진영 시스템**: 진영 선택 UI·보너스 데이터·언어별 랭킹 분리는 v1 프레임워크로 넣되,
  실행 가능한 진영은 Lua 하나로 시작 (Python/JS/C#은 외부 프로세스 어댑터로 v2 확장)
- **타워 매도(sell)**, 진행도 리셋 메뉴: 스펙에서 명시적으로 이연됨
- **타워 업그레이드 시스템**, 스테이지별 타일 틴트 변주, 도감 코드 예제 실행: 이번 웨이브
  범위 제외로 명문화됨(§8)

## 테스트

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

`tests/main.lua`가 `tests/test_*.lua` 스위트를 전부 실행하고 `RESULT pass=N fail=N`을 출력한다
(현재 206개, 전부 PASS — 11개 스위트: `test_csv`·`test_grid`·`test_sandbox`·`test_battle`·
`test_data`·`test_editor`·`test_progress`·`test_tutorial`·`test_particles`·`test_cutscene`·
`test_stageinfo`. `test_particles.lua`·`test_cutscene.lua`가 뷰 전용 이펙트/컷신 로직을,
`test_stageinfo.lua`가 적 구성 패널 집계 유틸을 다룬다. 이번 웨이브(3칼럼 레이아웃+함수 사전)는
신규 스위트를 추가하지 않고 기존 `test_editor`/`test_battle`/`test_progress` 스위트를 확장해
`Editor:charAt`/`Editor.tokenAt`, `battle.userFuncs`(env diff), `progress.funcbook`을 검증한다).
실패가 있으면 콘솔 종료 코드도 0이 아니게 된다.

스테이지를 추가할 때는 `data/curriculum/<n>_solution.lua`를 **반드시** 함께 추가해야 한다 —
`tests/test_battle.lua`가 CSV에 등록된 모든 스테이지를 순회하며 `solution_file`의 코드로 실제
전투를 실행해 클리어(300초 서버 생존)까지 확인하는 회귀 테스트이므로, 정답 코드가 없거나
틀리면 테스트가 실패해 스테이지 추가가 자동으로 검증된다. 회귀 테스트는 `Battle:setScript`로
정답 스크립트를 주입하는 방식이며, 스크립트 안의 `build()` 좌표는 반드시 스테이지 예산
(`budget`) 안에서 지을 수 있는 조합이어야 한다. 스테이지에 `naive_file`이 등록돼 있으면
(퍼즐 스테이지 6·9·12) 같은 회귀 루프가 그 스크립트로도 전투를 돌려 **반드시 defeat**임을
함께 증명한다 — 순진 배치가 실제로 클리어해 버리면 테스트가 실패해 퍼즐 설계가 깨졌음을
알려준다.
