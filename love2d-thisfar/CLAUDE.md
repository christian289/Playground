# love2d-thisfar

LÖVE (Love2D) 11.5 기반 코딩 교육용 타워디펜스 《정말 이렇게까지 게임을 해야할까?》(구 Code
Defense — 2026-07-24 개명, 사유는 저장소 루트 커밋 로그 참고). 플레이어가 게임 내 에디터에서
Lua 코드(`on_tick(self, world)`, `build(type, r, c, name)`)를 작성해 타워를 조종하고, 위에서
내려오는 밈 몬스터(버그/널 포인터/concat-nil)를 막습니다. 설계서:
`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md` (레포 루트 기준, 4.1/5.1절이
이번 실시간 개편 반영), 튜토리얼 설계서:
`docs/superpowers/specs/2026-07-21-codedefense-tutorial-design.md`, 스테이지 경험 개선 설계서:
`docs/superpowers/specs/2026-07-22-codedefense-stage-experience-design.md`(적 구성 패널·진행
바·문제 브리핑·메모리 테마 미로·히든 타워·도감·퍼즐·배포 로그), 비주얼·세계관 설계서:
`docs/superpowers/specs/2026-07-22-codedefense-visual-lore-design.md`, 플레이어빌리티 보강
설계서(Wave A): `docs/superpowers/specs/2026-07-23-codedefense-playability-design.md`(슬로우
모드·`demolish`·별점·위기 경고·도감 프로필 탭·패배 코칭·스테이지 네러티브), 신규 적·타워
설계서(Wave B): `docs/superpowers/specs/2026-07-23-codedefense-new-enemies-design.md`(IT
업계 유명 문제를 밈으로 삼은 신규 적 7종+보스·신규 타워 2종·스테이지 13~20·world API 확장),
셸 진영 설계서(Wave D): `docs/superpowers/specs/2026-07-23-codedefense-shell-mode-design.md`
(Lua 스크립트 대신 게임 내 터미널에 명령을 쳐서 방어하는 별도 진영 — 스테이지 101~106,
`src/shell.lua`).

## 실행 방법

```powershell
& "C:\Program Files\LOVE\lovec.exe" .        # 콘솔 출력(print) 확인 가능 — 개발 시 권장
& "C:\Program Files\LOVE\love.exe" .         # 콘솔 없이 실행
```

프로젝트 루트(이 폴더)에서 실행해야 합니다. `main.lua`가 엔트리 포인트입니다.

## 구조

```
love2d-thisfar/
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
│  ├─ stageinfo.lua         ← 적 구성 패널·문제 카드용 순수 집계(전체 수/종류별 수/마지막 스폰
│  │                            종료 시각/처리 수) — battle의 timeline/spawned/enemies를 읽기만
│  │                            한다. 뷰 비의존, 헤드리스 테스트 가능(`tests/test_stageinfo.lua`)
│  ├─ stars.lua             ← 별점 산식(순수 함수, `stars.of(hp)`) — 클리어 시 잔존 HP로
│  │                            ★1~3 결정. result/stageselect/codex(프로필 탭)가 공유
│  ├─ factions.lua          ← 진영(Lua/Shell) 필터·언락 순수 로직(Wave D) — love API 비참조,
│  │                            헤드리스 테스트 가능(`tests/test_factions.lua`)
│  └─ shell.lua             ← 셸 진영 명령 파서(Wave D, 순수 모듈) — `Shell.new(battle)` →
│                               `shell:exec(line)`/`shell:tick(clock)`. § "Wave D — 셸 진영" 참고
├─ states/                ← hump Gamestate 화면들 (뷰 전담, 로직은 src/battle.lua·src/tutorial.lua에 위임)
│  ├─ intro.lua             ← 인트로 컷신 4장면 (첫 실행 1회 자동 재생, 타이틀 "세계관" 메뉴로 재생)
│  ├─ title.lua             ← 타이틀 메뉴 4항목(게임 시작/세계관/도감/종료), 룩(Rook) 심볼 +
│  │                            폰트 렌더 문장형 게임명 2줄, ↑↓+Enter 및 마우스(호버 이동·
│  │                            좌클릭 선택) 겸용
│  ├─ faction.lua           ← 진영 선택 화면(Wave D, 신규) — 타이틀 "게임 시작" 다음. Lua/Shell
│  │                            2항목, 셸 스테이지가 0개면 "(준비 중)"으로 진입 차단
│  ├─ stageselect.lua       ← 스테이지 목록(진영별 필터) + 배포 기록 표기(`[★★☆ · HP n · 구]`/`[시도 n]`)
│  ├─ play.lua              ← 3칼럼(전장 384 / 정보 칼럼 240 / 에디터 610): 그리드 + 코드
│  │                            에디터 + 실시간 전투 + 정보 칼럼(문제 요약·적 구성·함수 사전·
│  │                            전투 로그)·진행 바·문제 카드(+lore 브리핑 문단)·구구 클래스
│  │                            소환 연출·위기 경고 비네트를 한 화면에서 진행 (구 prep/battle
│  │                            통합, 전장 오버레이는 정보 칼럼으로 이동). `ui=="shell"`
│  │                            스테이지는 에디터 자리에 터미널 패널이 대신 뜬다(Wave D, § "Wave D
│  │                            — 셸 진영" 참고)
│  ├─ result.lua            ← 클리어/패배 결과 + 배포 로그 한 줄(§6.7) + 별점 + 패배 코칭 줄 +
│  │                            여운 문구 + 포스트모템 카드(클리어 전용, lore가 있을 때만),
│  │                            Enter/좌클릭 공용
│  └─ codex.lua             ← 도감: 타워/몬스터/내 함수/프로필 4탭(←/→ 순환), 히든 타워 ??? 카드
│                               (뷰 전용, `progress.gugu_found`로 공개 여부 판정). 몬스터 카드는
│                               desc 아래 origin(유래) 줄을 붙인다. 내 함수 탭은
│                               `progress.funcbook`(이름→{first,count})을 이름 정렬로 나열하고,
│                               프로필 탭은 배포 총계·클리어 수·별 합계·구구 발견 여부를 집계한다
├─ data/
│  ├─ towers.csv, enemies.csv(origin 칼럼 포함), items.csv, stages.csv(lore_file 칼럼 포함),
│  │  timelines.csv
│  ├─ mazes/                ← 스테이지별 미로 텍스트(#=벽, .=통로, B=건설칸), 26개(001~020 Lua
│  │                            진영 + 101~106 Shell 진영), 12×16 규격, 테마별 형태(§ "메모리
│  │                            테마 미로"·"스테이지 13~20" 참고 — 13~20은 메모리 영역이 아니라
│  │                            스레드/프로세스/네트워크, 101~106은 "터미널"/"파이프라인")
│  ├─ curriculum/            ← 스테이지별 solution(정답, Lua 진영은 `.lua`·Shell 진영은
│  │                            `<n>_solution.sh` 명령 시퀀스)·hints(따라치기/빈칸)·
│  │                            tutorial(가이드)·buttons(생성기)·naive(퍼즐 스테이지 순진 배치,
│  │                            반드시 패배해야 함) 파일
│  └─ lore/                  ← 스테이지별 서사 데이터 `<n>.lua`(001~020, 101~106), `return {
│                               briefing = "...", postmortem = "..." }` 스키마. `stages.csv`의
│                               `lore_file`이 가리키며, 비어 있으면 해당 스테이지는 브리핑/
│                               포스트모템 표시를 조용히 생략한다(§ "스테이지 네러티브" 참고)
├─ tests/                  ← lovec tests로 실행하는 자체 테스트 러너 (814개, 16개 스위트:
│                               csv/grid/sandbox/battle/data/editor/progress/tutorial/particles/
│                               cutscene/stageinfo/demolish/stars/abilities/shell/factions —
│                               뒤 2개가 Wave D 셸 진영, § "테스트" 참고)
├─ lib/                    ← 외부 라이브러리 (직접 수정 금지)
│  ├─ classic.lua           ← rxi/classic: 경량 OOP
│  └─ hump/                  ← vrld/hump: gamestate, timer, vector, signal, camera
└─ assets/fonts/            ← 나눔고딕(OFL)
```

상태 흐름은 기본적으로 `title → faction → stageselect → play → result` 다섯 가지입니다(Wave D에서
타이틀과 스테이지 선택 사이에 진영 선택(`faction`)이 신설됨 — 아래 "Wave D — 셸 진영" 참고). 구 `prep`/`battle`
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
- 화면 전환은 hump의 `Gamestate` 사용 (intro / title / faction / stageselect / play / result / codex).
- 스테이지 추가는 코드가 아니라 **데이터로만** 한다 — `data/stages.csv`(+ 필요 시
  `timelines.csv`)에 행을 추가하고, `data/mazes/<n>.txt` 미로와
  `data/curriculum/<n>_solution.lua`(필수)·`<n>_hints.lua`(hint 모드일 때)를 함께 둔다.
  버튼 모드(`ui=button`) 스테이지라면 `buttons_file`에 생성기 Lua(`data/curriculum/buttons_<n>.lua`)를,
  가이드가 필요한 스테이지라면 `tutorial_file`에 튜토리얼 스텝 Lua
  (`data/curriculum/tutorial_<n>.lua`)를 함께 등록한다. `countdown`(15~30초 권장)도 스테이지마다
  지정해야 한다. `solution_file`은 필수 — 회귀 테스트(`tests/test_battle.lua`)가 각 스테이지의
  정답 코드로 실제 클리어가 되는지 자동 검증하므로, 정답 없이 스테이지를 추가하면 테스트가
  실패한다. `ui=="shell"`(Shell 진영, id 101번대)인 스테이지는 규칙이 다르다 — `solution_file`이
  Lua가 아니라 `.sh` 확장자의 명령 시퀀스 파일이어야 하며 세부 규칙은 § "Wave D — 셸 진영"에
  모아 뒀다(진영별로 규칙이 갈리므로 이 절의 "코드 스테이지" 서술은 기본적으로 Lua 진영
  기준이다).
  - **문제 브리핑 열**: `theme`(스테이지 1~12는 메모리 영역명 "코드 영역"/"데이터 영역"/
    "스택"/"힙", 13~20은 실행 테마 "스레드"/"프로세스"/"네트워크" — 문제 카드에 "영역: X"로
    표기. 과거엔 "메모리 영역: X"로 고정 표기했으나 13~20이 메모리 영역이 아니어서 범주
    오류였다 — Wave B에서 "영역: X"로 정정, `states/play.lua` 2곳)과 `problem`(한 줄 문제
    서술, 코딩테스트 문제지 톤)도 모든 스테이지에 채운다. 미로 형태는 테마와 어울리게 짓는다
    — 코드 영역=정연한 가로 행 / 데이터 영역=블록 격자 / 스택=위에서 쌓이는 지그재그 / 힙=
    단편화 조각 / 스레드=단일 세로 회랑 변주(직선/지그재그/이중 굴곡) / 프로세스=격리 구획(방+좁은 문) / 네트워크
    =허브-스포크(중앙 광장+방사 통로)(12×16 규격, 건설칸 ≥6). 같은 테마의 3개 스테이지는
    같은 문법 개념의 난이도 변주로 설계하며, 미로 자체도 서로 달라야 한다(테마 형태를
    공유하되 통로/건설칸 배치는 3장 모두 다르게).
  - **미로 설계 규칙(Wave B에서 확립, 13~20 적용)**: 모든 건설칸(`B`)은 스폰이 실제로
    지나가는 경로를 사거리로 교전할 수 있어야 한다 — 영구히 아무 적도 닿지 않는 장식용
    죽은 슬롯을 두지 않는다(`world.oldest()` 등 `world.*` API는 사거리와 무관하게 필드 전체를
    보는 전역 판정이라, 유휴 레인에 지은 타워는 "쏠 수 있다고 착각하게 만드는" 배치 함정이
    되기 쉽다). 다분기 형태(허브-스포크처럼 갈래가 있는 미로)는 스폰 경로가 실제로
    지나는 가지에만 건설칸을 둔다 — 스폰과 무관한 죽은 가지에 건설칸을 두지 않는다.
  - **lore 열(선택)**: `lore_file`에 `data/lore/<n>.lua`(스키마 `return { briefing = "...",
    postmortem = "..." }`)를 연결하면 브리핑 문단·포스트모템 카드가 자동으로 뜬다(§ "구현된
    규칙"의 "스테이지 네러티브" 참고). 비워 두면 두 표시 모두 조용히 생략되므로 필수는 아니다
    — 채울 경우 `d.validate()`가 파일 존재를 검증한다.
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
    위한 규칙이며, 위반하면 부팅 시 `main.lua`가 즉시 에러로 중단한다. **설계 시 경계값은
    피한다**(Wave B에서 확립) — 검증식이 "40초 초과 금지"라 정확히 40초는 통과하지만, 신규
    스테이지 13~20의 공백은 여유를 두어 39초 이하로 설계했다(예: 스테이지 19는 실측 공백
    22~33.4초). 정확히 경계에 걸치는 값은 반올림·부동소수 오차에 취약해 피하는 편이 안전하다.
- **결정론 원칙**: 게임 로직에 랜덤을 쓰지 않는다. 같은 배치·같은 코드는 항상 같은 결과가
  나와야 회귀 테스트와 하드코어 스피드런 기록이 의미를 가진다.
- **데미지 반올림 원칙(Wave B에서 확립)**: **신규 능력 경로(`resist:<타워id>`·`pair`·
  `splash`)의 데미지 계산 결과에만** `math.max(1, math.floor(x))`(내림 + 0데미지 금지)를
  적용한다(`src/battle.lua`의 `resolveAttack`, `src/projectile.lua`). **기존 데미지
  파이프라인(차지샷 배율 `1 + charge*0.5` 등)은 비정수 그대로 두며, 여기에 전역 floor를
  추가하지 않는다** — 기존 스테이지의 시뮬레이션 결과(클리어/패배 판정, 회귀 테스트 기준값)
  가 달라지지 않는 것이 우선이다. 앞으로 새 능력을 추가할 때도 이 경계를 따른다: 그 능력이
  실제로 만들어내는 새 계산 경로에만 floor·min1을 적용하고, 기존 경로에는 손대지 않는다.
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
- **조작**: F5(저장·반영), F1~F4(코드 스니펫 퀵바), Ctrl+L(에디터 비우기 — 힌트 템플릿을 지우고
  처음부터 짤 때), Ctrl+1/2/4/5(배속 x1/x2/x4/x0.5 — Ctrl+5가 "슬로우 모드"), Ctrl+I(문제
  브리핑 카드 토글 — 아래 참고), Ctrl+R(같은 스테이지로 즉시 재시작), ESC(스테이지 선택으로
  나가기 — 실수 방지로 2단 확인: 첫 ESC는 3초짜리 확인 토스트만 띄우고, 그 안에 다시 누르면
  실제로 나간다)가 기본이다. 버튼 모드 스테이지(1~2)는 숫자키로 버튼을 누른다. 구 조작이던
  Tab(포커스 전환)/B(건설)/T(타워 순환)/Space(전략 순환)는 통합 스크립트 도입과 함께
  삭제되었다 — 건설은 코드의 `build()` 호출로만 한다. 타이틀 화면은 ↑↓(또는 마우스 호버)로
  메뉴(게임 시작/세계관/도감/종료, 4항목) 이동, Enter(또는 좌클릭)로 확정한다. "도감"을 고르면
  `codex` 상태로 들어간다 — ←/→로 탭(타워/몬스터/내 함수/프로필, 4탭) 전환, ↑↓로 목록 이동
  (프로필 탭은 스테이지 기록 스크롤), ESC로 타이틀 복귀. 인트로 컷신은 Enter/좌클릭(타이핑
  중이면 즉시 완성, 완성 후엔 다음 장면)로 진행하고 ESC로 전체 스킵한다. **결과 화면**은
  Enter 또는 좌클릭으로 스테이지 선택으로 돌아가고, **R**은 카드 상태와 무관하게 즉시 같은
  스테이지로 재도전한다(스테이지 선택 왕복 없이 최단 재도전 루프) — 클리어 시 lore가 있으면
  포스트모템 카드가 먼저 뜨는데, 이때 Enter/좌클릭 1회차는 카드만 닫고, 카드가 닫힌 뒤
  2회차부터 실제로 스테이지 선택으로 이동한다(§ "스테이지 네러티브" 참고). **play 화면의
  마우스**: `play:mousepressed`가 좌클릭을 두 영역에서 받는다 — ① 에디터 안에서 `build`·
  `demolish`나 `battle.userFuncs`에 등록된 식별자를 클릭하면 함수 사전 카드가 펼쳐지고(재클릭
  시 접힘), ② 정보 칼럼의 사전 목록 항목을 직접 클릭해도 같은 토글이 일어난다(자세한 동작은
  "함수 사전" 절 참고). 그 외 클릭(빈 곳, 우클릭 등)은 무시된다 — 타워 건설은 여전히 코드의
  `build()` 호출로만 한다. 전장에서 타워 위에 마우스를 올리면(호버) 사거리 원 + 스탯/상태
  툴팁이 뜬다(구구 클래스는 현재 단이 반영된 실효 데미지를 보여준다).
- **3칼럼 레이아웃** (`states/play.lua`): `play` 화면은 창(1280×640) 안에서 좌→우로 전장(x=8,
  w=384) / 정보 칼럼(x=400, w=240) / 에디터(x=656, w=610) 세 칼럼으로 나뉜다. 구 버전의 전장
  우상단 오버레이(적 구성 패널·전투 로그)는 모두 정보 칼럼으로 흡수되었다 — 전장에는 더 이상
  텍스트 오버레이가 없다. 셰이크는 전장에만 적용되고 정보 칼럼·에디터·HUD는 고정이다.
- **정보 칼럼** (x=400, y=48, w=240, h=512 — 전장과 바닥이 나란함): 위에서부터 순서대로
  ① **문제 요약**(`[문제 N] concept` / `영역: theme` / `Ctrl+I 상세` 안내),
  ② **적 구성**(구 전장 우상단 오버레이 — 스테이지 등장 적 종류별 미니 스프라이트 +
  "처리 n / 전체 N", 모든 스폰이 끝나면 "잔여 소탕 · 생존!" 한 줄 추가),
  ③ **함수 사전**(아래 별도 절 참고),
  ④ **전투 로그**(구 전장 오버레이 — 최근 8줄, 오래된 줄일수록 옅어지는 페이드)가 이어진다.
  상단 HUD 바로 아래에는(전장 폭 기준) 300초 대비 현재 진행률과 스폰 이벤트 시점 눈금을 그리는
  얇은(4px) 진행 바가 별도로 있다. 스테이지 진입(카운트다운 중)에는 전장+정보 칼럼을 아우르는
  중앙에 문제 카드가 자동으로 뜬다 — `[문제 N] concept`, `영역: theme`, (lore가 있으면)
  회색 톤 브리핑 문단, `problem` 한 줄 서술, `예산 X · 유입 예정 N기`, 제출/채점 안내를
  보여주며 Enter로 닫고 전투 중 언제든 Ctrl+I로 다시 연다. 튜토리얼 말풍선이 활성 상태면 문제
  카드보다 z순서상 위에 그려져 튜토리얼이 우선한다.
- **함수 사전** (`states/play.lua`의 `drawFuncDict`/`drawDictCard` — 정보 칼럼 ③): 빌트인 함수
  `build`/`demolish`의 문서(시그니처·설명 줄·예시)가 `BUILTIN_DOCS` 리터럴로 항상 목록 맨 위
  두 줄(`> build`, `> demolish`)에 고정으로 있고, 그 아래로 유저 정의 함수 목록이 이어진다.
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
    밀어낸다 — 빌트인(`build`/`demolish`)은 `BUILTIN_DOCS`의 문서 카드, 유저 함수는
    `extractFuncSource`(`function 이름` 줄부터 function/if/for/while/do(+1)·end(-1) 키워드
    카운팅으로 대응 `end`까지 훑는 휴리스틱, 정밀 파서 아님)가 뽑은 소스 발췌를 `L시작줄번호` +
    최대 10줄(초과 시 "…" 절단)로 보여준다.
  - **`BUILTIN_DOCS` 확장법**: 새 빌트인 API를 문서화하려면 `states/play.lua`의
    `BUILTIN_DOCS` 테이블에 `{ sig = "이름(인자...)", lines = {설명 줄...}, example = "예시 코드" }`
    항목을 키(함수 이름)로 추가하면 `drawDictCard`가 자동으로 카드를 그린다 — 별도 렌더 코드를
    추가할 필요는 없다. `lines`의 각 줄은 카드 폭 기준으로 `printf` 줄바꿈되므로(높이도 실제
    래핑된 줄 수로 계산) `build`처럼 짧게 쓸 필요는 없다(`demolish` 항목의 재건설 함정 설명이
    2줄로 자동 줄바꿈되는 것이 예시).
  - **셸 진영 오버라이드(`SHELL_DOCS`, 최종 리뷰 반영)**: 셸 스테이지(`ui=="shell"`)의 `man
    build`/명령 사전 `build` 카드는 Lua 문법(`build(종류, 행, 열, "이름")`)이 아니라 셸 문법을
    보여줘야 한다 — `states/play.lua`에 `BUILTIN_DOCS`와 별도로 `SHELL_DOCS` 테이블(현재
    `build` 하나만 등록)을 두고, `drawDictCard`가 `self:isShellStage()`이면 `SHELL_DOCS[name]`을
    먼저 찾은 뒤 없으면 `BUILTIN_DOCS[name]`으로 폴백한다. 이 오버라이드로 셸 진영에서는
    `sig = "build <타워> <행> <열> <이름>"`, `example = "build printer 4 3 a"` 카드가 뜨고,
    Lua 진영의 기존 `BUILTIN_DOCS.build`는 그대로다(양쪽 다 손대지 않고 분기만 추가).
  - **`demolish("이름")`**: 이름으로 타워를 철거하는 API(`src/battle.lua`의
    `Battle:demolishTower`, `src/api.lua`의 `env.demolish`). 환불은 `floor(cost * 0.5)`로
    `money`에 가산되고, 로그 `[철거] <타워명> → "<이름>" · +<환불> 환불`이 남는다(없는 이름이면
    `[오류] 철거 실패 — "<이름>" 타워가 없습니다` + false). 크래시·비활성 타워도 철거 가능.
    **함정**: `build`는 이름 기준 멱등이라, 스크립트 최상위에 `build("printer", r, c, "a")`가
    남아 있는 채 `on_tick` 안에서 `demolish("a")`를 호출하면 다음 F5 저장 때 최상위가 재실행되며
    "a"가 다시 지어진다 — 버그가 아니라 실시간 스크립트 재실행 규칙의 자연스러운 결과다(카드에
    이 함정을 명시). `runTick`은 이번 틱 타워 목록을 미리 스냅샷해 두므로, 어떤 타워의
    `on_tick`이 아직 차례가 안 온 다른 타워를 `demolish`해도 그 틱에서 스킵되지 않는다
    (`tests/test_demolish.lua`). 같은 스냅샷 메커니즘의 반대쪽 효과도 있다 — `on_tick` 안에서
    `build()`로 새로 지은 타워는 이번 틱 스냅샷에 없으므로 그 타워의 `on_tick`은 이번 틱에는
    실행되지 않고 다음 틱부터 반영된다.
  - **funcbook 영구 수집** (`src/progress.lua`의 `p.funcbook`, `play:save`): F5 저장이 성공할
    때마다 `battle.userFuncs`를 훑어 판당(전투당) 이름별로 **한 번만**(`self.funcCounted` 가드)
    `p.funcbook[name] = { first = stageId, count = 0 }`를 만들고 `count`를 1 증가시켜
    `progress.save`로 영구 저장한다. 도감(`states/codex.lua`)의 3번째 탭 **"내 함수"**가 이
    `funcbook`을 이름 정렬로 나열하고, 카드는 "스테이지 N에서 처음 정의 · M회"를 보여준다(아직
    없으면 "아직 수집된 함수가 없습니다..." 안내).
- **세계관·비주얼**: `states/intro.lua`가 첫 실행 시 자동으로(또는 타이틀 "세계관" 메뉴로 언제든)
  4장면 컷신을 보여준다 — 지상의 화려한 서비스 → 새벽 서버실의 개발자 → 버그로 인한 장애 발생 →
  코드로 맞서는 결의. 장면마다 `src/art.lua`의 코드 생성 일러스트와 `src/cutscene.lua`의 초당
  30자 타이프라이터 텍스트가 함께 나온다. 타이틀 화면은 네온 서버실 배경에 책상 앞 개발자
  뒷모습, 룩(Rook, 체스 성탑) 심볼, 그리고 그 아래 문장형 게임명 2줄을 그린다 —
  `art.drawRook(x, y, scale, t)`가 16×16 도트(총안 3개+몸통+받침, green 몸체·cyan 하이라이트)를
  직접 그리고, `art.rookIconData()`가 같은 도트를 32×32 `ImageData`로 만들어 `main.lua`가 부팅 시
  `love.window.setIcon`으로 창/작업표시줄 아이콘을 설정한다. 게임명은 (구 버전의 5×7 도트
  픽셀 레터링 "CODE DEFENSE" 대신) `art.drawTitleText(cx, y, font, t)`가 `fonts.title`(40px
  나눔고딕)로 "정말 이렇게까지"/"게임을 해야할까?" 2줄을 그린다 — 문장형 제목이라 픽셀 폰트로는
  감당이 안 돼 Wave 개명 때 폰트 렌더 기반으로 바꿨다(green→cyan 그라데이션 + 자홍 글로우 레이어로
  네온 톤 유지). `states/title.lua`는 `art.titleTextHeight(font)`로 실제 렌더 높이를 미리 계산해
  룩 심볼·부제·메뉴 y좌표를 그 높이에 맞춰 배치한다(폰트 교체 시에도 레이아웃이 안 깨지도록).
  intro/title/stageselect/result/codex는 `love.graphics.getWidth()` 기반
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
- **몬스터·타워 능력 키워드** (CSV의 `abilities`/`ability` 필드, `;`로 조합·`Enemy.parseAbilities`가
  토큰 완전 일치로 파싱 — 부분 문자열 검사가 아니므로 `split2`가 `split` 판정에 오탐되지
  않는다): 상수는 대부분 `src/enemy.lua`(적)·`src/projectile.lua`(splash 반경)에 로컬로
  정의된 코어 상수이며 CSV에 노출되지 않는다. 단, `resist`·`pair`의 감쇄 배율(`RESIST_MULT`
  `=0.5`·`PAIR_MULT=0.4`)은 직격과 splash 피해자에게 같은 값을 적용해야 해서
  `src/battle.lua` 파일 상단 상수로 옮겨져 있다(최종 리뷰 반영, 아래 splash 규칙 참고).

  | 키워드 | 대상(예) | 동작 | 상수 |
  |---|---|---|---|
  | `crash_tower` | 널 포인터 | 서버 도달 시 최근접 타워 강제 크래시 | – |
  | `split` | concat-nil | 사망 시 체력 절반씩 둘로 분열(깊이 1, 자식은 더 분열하지 않음) | – |
  | `grow` | 메모리 릭 | 스폰 후 `GROW_EVERY`마다 maxHP/HP가 `GROW_AMOUNT`씩 증가, 상한은 기본(CSV) hp×`GROW_CAP_MULT` | `GROW_EVERY=1.0`s·`GROW_AMOUNT=2`·`GROW_CAP_MULT=5` |
  | `pair` | 데드락 | 같은 스폰 이벤트 안에서 홀짝으로 짝지어짐, 짝이 살아 있는 동안 받는 데미지 ×배율(내림·최소1). 홀수 스폰의 마지막 1기는 짝 없음(경감 없음) | 배율 `0.4` |
  | `phase` | 하이젠버그 | 스폰 시각 기준 가시/은신을 교대 반복. 은신 중엔 `world.*` 스냅샷·투사체 명중·타워 자동 타겟에서 전부 제외(서버라인 도달 판정은 은신과 무관) | `PHASE_VISIBLE=3.0`s(가시)·`PHASE_HIDDEN=2.0`s(은신) |
  | `split2` | 포크 밤, 커널 패닉 | 사망 시 체력 절반씩 둘로 분열하며, 그 자식도 한 번 더 분열 가능(깊이 상한 2 — `split`의 상위 호환) | 깊이 상한 `2` |
  | `dash` | 레이스 컨디션 | 스폰 시각 기준 주기마다 짧은 창 동안 이동 속도 배율 | `DASH_PERIOD=1.5`s(주기)·`DASH_LEN=0.3`s(창)·`DASH_MULT=3`(배율) |
  | `resist:<타워id>` | 레거시 코드(`resist:printer`) | 지정한 타워 종류의 데미지만 배율 감쇄(내림·최소1), 다른 타워 종류의 데미지는 그대로(반올림 없음) | 배율 `0.5` |
  | `splash`(타워 `ability`) | GC 수집기 | 명중점 기준 반경 안 "다른" 적에게 중심 100%→가장자리 50% 선형 낙폭 피해(내림·최소1), 은신 중인 피해자는 면제 | 반경 `SPLASH_RADIUS=60`px |
  | `slowfield`(타워 `ability`) | 디버거 | 사거리 안 적의 실효 이동 속도에 배율(여러 대가 겹쳐도 OR 판정이라 한 번만 적용, `dash`와는 곱연산으로 복합) | 배율 `SLOW_MULT=0.6` |

  **splash·pair 관련 추가 규칙(최종 리뷰 반영)**:
  - pair 경감·resist는 광역(splash) 피해에도 피해자 기준으로 적용된다 — 직격(`resolveAttack`)
    과 동일하게 resist→pair 순서로 각각 floor·min1 적용하며, 우회를 허용하면 물량형 적을
    광역 타워 하나로 표적 구분 없이 쓸어담아 "표적 분산" 등의 학습 포인트가 무력화된다.
  - pair 해제는 짝이 필드에서 사라질 때(사망·서버라인 도달 모두) 일어난다 — 사망 정리
    분기와 도달(reached) 정리 분기 양쪽에 동일한 해제 로직이 있다(`src/battle.lua`).

  `grow`/`dash`/`phase`의 실효 속도·성장은 전부 `age`(스폰 후 경과초, battle clock 기준)의
  순수 함수로 재계산되며 별도 상태를 저장하지 않으므로(단, `grow`는 이미 적용된 증분만
  누적) 매 호출 결정론이 보장된다.
- **타워 종류**: `printer`(기본 발사기, cost 100), `compiler`(공격하지 않는 테크 타워, cost 50,
  고급 타워 건설을 해금), `sniper`(장거리 저격, cost 150, `requires=compiler` — 필드에 컴파일러가
  있어야 건설 가능), `gugu-class`(히든 — 아래 별도 절 참고), `gc-collector`·`debugger`(Wave B
  신규 — 아래 "신규 타워" 절 참고)(`data/towers.csv`). `towers.csv`에는 `limit`(스테이지당 최대
  설치 수, 빈 값=무제한), `hidden`(1=도감에서 발견 전 "???"로 표시), `ability`(엔진이 인식하는
  특수 능력 키워드 — `gugu`/`splash`/`slowfield`, `battle.lua`가 이 키워드로 분기)의 3개 열이
  추가돼 있다.
- **신규 타워(Wave B)**:
  - **GC 수집기(`gc-collector`)**: cost 180, damage 6, range 108, cooldown 1.2,
    `requires=compiler`(컴파일러 필요), limit 없음, `ability=splash`. 명중 시 위 표의 `splash`
    낙폭 피해로 명중점 주변 적까지 함께 처리한다 — 포크 밤(`split2`)·DDoS 봇 같은 물량형 적
    대응이 존재 이유다.
  - **디버거(`debugger`)**: cost 80, damage 0(공격하지 않는 순수 필드 타워), range 132,
    `requires` 없음, **limit 2**(스테이지당 최대 2기 — 감속 도배로 실시간 압박이 사라지는
    것을 막는 의도적 상한), `ability=slowfield`. `runTick`이 `tw.def.ability == "slowfield"`인
    타워는 타겟팅·`on_tick` 호출·명령 예산 소비 자체를 건너뛰므로(우연히 damage 0이라 무해한
    게 아니라 의도적으로 발사 루프에서 제외) 스크립트에서 `self:attack(...)`을 걸어도 아무
    일도 일어나지 않는다 — 사거리 안에 있기만 하면 자동으로 감속 효과를 낸다.
- **world API 확장(Wave B)**: 타워 스크립트에 노출되는 적 스냅샷(`api.lua`의 `snapshot`)에
  `age`(스폰 후 경과초)·`speed`(현재 실효 이동 속도 px/s — `dash`/`slowfield` 배율이 반영된
  값)가 추가됐고, `world.oldest()`(`age`가 가장 큰, 즉 가장 먼저 스폰된 적의 스냅샷을 반환 —
  동률이면 더 먼저 스폰된, 즉 낮은 `id` 쪽. 적이 없으면 `nil`)가 `world.nearest()`/
  `weakest()`/`fastest()`와 같은 반열에 추가됐다(`BUILTIN_DOCS`에도 카드 등록, "함수 사전"에서
  클릭해 볼 수 있다). **은신(phase) 적은 `world.oldest()`를 포함해 `world.*` 전부에서
  똑같이 제외된다** — `api.refresh`가 스냅샷 목록(`snaps`)을 만들 때 `e:isPhased(clock)`로
  한 번만 걸러내고 그 목록을 모든 `world.*` 함수가 공유하므로, 새 `world.*` 함수를 추가해도
  은신 제외 규칙을 따로 구현할 필요가 없다(단일 필터 지점).
- **퍼즐 스테이지 (6·9·12)**: `stages.csv`의 `puzzle=1`인 스테이지는 미로·예산·적 구성이 특정
  배치를 사실상 강제하도록 설계됐다 — 6(건설칸이 전부 프린터 사거리 밖 가장자리라 컴파일러+
  스나이퍼 조합 필수), 9(사거리가 닿는 건설칸이 극소수), 12(독립된 3차선이라 분할 지점마다
  타워가 필요). 판정 철학은 그대로다(§0 무변경, 코드 형태가 아니라 결과만 봄) — 좁아지는 것은
  전술 해공간이지 정답 코드 강제가 아니다. `naive_file`(예: `curriculum/006_naive.lua`)에 "사거리
  등을 고려 안 하고 단순하게 지으면" 나오는 스크립트를 등록해 두면, 회귀 테스트가 그 배치는
  반드시 defeat임을(= "브루트포스는 시간초과") 결정론으로 증명한다. Wave B의 퍼즐 스테이지는
  16(단일 표적 화력으로 포크 밤의 분열 물량을 못 이김 — GC 수집기의 광역 필수)과 20(광역
  없이 단일 차선만 방어하면 반드시 패배 — 종합 방어선 필수)이다.
- **스테이지 13~20 (Wave B, 테마: 스레드/프로세스/네트워크)**: 기존 1~12(코드 영역/데이터
  영역/스택/힙 × 3, 메모리 영역 테마)는 그대로 두고, 신규 8스테이지를 스레드(13~15)·
  프로세스(16~18)·네트워크(19~20) 테마로 이어 붙였다 — 13 정렬 기준(메모리 릭/`world.oldest()`
  타겟팅), 14 표적 분산(데드락/타워 2기 협동), 15 안전 검사(하이젠버그/nil 체크 사격), 16
  광역 방어(포크 밤/GC 수집기, 퍼즐), 17 브레이크포인트(레이스 컨디션/디버거+예측 사격), 18
  정밀 타격(레거시 코드/스나이퍼 테크 체인), 19 물량 방어(DDoS 봇/연사+광역, 한 이벤트에
  30기 러시), 20 복합 방어(전 종 혼합+커널 패닉 보스, 퍼즐). 정확한 수치(HP·보상·예산 등)는
  `data/enemies.csv`/`data/towers.csv`/`data/stages.csv`가 원본이므로 여기서 되풀이하지
  않는다 — 회귀 테스트(solution 클리어·naive 패배)를 통과하도록 구현 중 조정된 값들이다.
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
  화면은 항목 옆에 기록을 붙인다 — 클리어면 `[★★☆ · HP n · 구]`(별점 3개 만점, 구구 사용
  시 " · 구" 추가), 미클리어면 `[시도 n]`, 기록이 아예 없으면 미표기. ("九"는 나눔고딕에
  글리프가 없어 "구"로 표기한다.)
- **진행도**: 클리어 여부, 획득 아이템(`cache`/`webhook`), 스테이지별 저장 코드, 튜토리얼 완료
  여부, 배포 기록(`records`), 구구 클래스 발견 플래그(`gugu_found`)를 `love.filesystem` 유저
  폴더에 저장(`src/progress.lua`). 아이템은 `data/items.csv`의 `api` 필드로 타워 env에 어떤
  함수를 추가로 열어줄지 결정한다 (`cache.get/set`, `on_spawn`). 아이템은 획득 시 배치되는
  모든 타워에 자동 장착된다 (0.1 규칙; 타워별 개별 장착 UI는 0.2).
- **슬로우 모드**: `Ctrl+5` → `self.speed = 0.5`(기존 x1/x2/x4에 배속 하나를 더 추가). "일시정지"는
  도입하지 않는다 — 실시간으로 코드를 치는 압박이 이 게임의 정체성이라는 원칙(Wave A 설계서
  §0)에 따라 시간은 항상 흐르고, 대신 가장 느린 배속으로 여유를 준다. HUD 배속 표기는
  `%g` 포맷이라 "x0.5"가 그대로 보인다.
- **별점 ★1~3** (`src/stars.lua`, 뷰 전용·저장 필드 추가 없음): `stars.of(hp)` 순수 함수 —
  클리어 시 잔존 서버 HP 기준 `HP≥8 → ★3`, `HP≥4 → ★2`, 그 외(클리어 전제) → ★1. 기존
  `records[id].bestHP`로 매번 계산하므로 세이브 마이그레이션이 필요 없다. 결과 화면(이번 판
  별 + 최고 기록 별을 함께 "이번 ★★☆ (최고 ★★★)" 식으로), 스테이지 선택(위 배포 로그
  참고), 도감 프로필 탭(별 합계)이 이 값을 공유한다.
- **위기 경고**: `battle.serverHP <= 3`이고 `status == "running"`이면(`states/play.lua`) 전장
  가장자리에 붉은 비네트(4겹 알파 그라데이션, 1.2초 주기 사인 펄스 — 배속 무관한 원시 dt
  누적 `fx.crisisTimer`)가 뜨고, 상단 HUD의 "서버 HP n" 부분만 빨갛게 강조된다. 피격 순간의
  `fx.redFlash`(테두리 플래시)와는 완전히 별개이며 동시에 표시될 수 있다.
- **진행 바 눈금 색상**: 상단 진행 바의 스폰 이벤트 눈금(`states/play.lua`)이 해당 이벤트
  적 종류의 `enemies.csv color`로 칠해진다(과거엔 흰 단색 고정). 이미 지나간 눈금은 알파
  0.35로 옅어져 앞으로 올 이벤트와 구분된다.
- **패배 코칭**: `src/battle.lua`가 적이 서버라인에 도달할 때마다(카운트 시점 1회)
  `self.reachedByType[enemyId]`를 증가시킨다(순수 집계, 시뮬 로직에는 영향 없음). 패배 결과
  화면(`states/result.lua`의 `topReached`)은 가장 많이 도달한 적 종류 1개를 "가장 많이 도달:
  <이름> n기 — 사거리와 화력 배치를 다시 보라"로 보여준다(도달 0이면 생략, 동률이면 스테이지
  타임라인상 더 먼저 스폰된 종 우선) — "버틴 시간 N초 / 300초" 바로 아래에 붙는다. concat-nil의
  표시명(영문 에러 문구 그대로)이 섞이는 최악 사례가 `fonts.ui` 기준 711px로 결과 패널 폭
  (600px)을 넘기므로, 이 줄은 **항상** `fonts.small`로 렌더링한다.
- **도감 프로필 탭** (`states/codex.lua`, 4번째 탭 — 전부 기존 저장 데이터 파생, 새 필드 없음):
  좌측 패널은 요약 집계(총 배포 횟수 = 모든 `records.tries` 합 / 클리어 스테이지 수 / 별
  합계 / 등록 함수 수(`funcbook`) / 구구 클래스 발견 여부), 우측 패널은 스테이지별 한 줄
  기록(`N. 개념 — 시도 n · ★★☆` 또는 미클리어면 `미클리어`)을 다른 탭과 같은 스크롤
  패턴으로 보여준다(단, 커서 이동이 아니라 `profileScroll`로 별도 관리).
- **스테이지 네러티브(브리핑·포스트모템) + 도감 origin** (`data/lore/<n>.lua`, `stages.csv`의
  `lore_file`이 가리킴, 스키마 `return { briefing = "...", postmortem = "..." }`): 로드는
  `db.lua`와 동일하게 `io.open` + `loadstring` 기반이다(love API 미사용 — `dofile` 아님).
  `states/play.lua`(브리핑용)와 `states/result.lua`(포스트모템용)가 각자 진입 시 필요한 만큼만
  읽는다. `lore_file`이 비어 있으면 `self.lore`/`self.postmortem`이 `nil`로 남아 두 표시 모두
  조용히 생략된다(기존 동작 그대로) — 즉 유저 커스텀 스테이지처럼 lore 없는 스테이지도 그냥
  동작한다.
  - **브리핑**: `play`의 문제 카드에서 기존 `problem` 문구 위, 회색 톤 서사체로 붙는다.
    `fonts.small:getWrap`으로 줄바꿈해 실제 줄 수만큼 카드 높이(`cardH`)를 늘리므로(lore 없으면
    `cardH`가 기존 190 그대로), 12편 중 가장 긴 브리핑(스테이지 6, 약 90자)도 카드 안에 온전히
    들어간다.
  - **포스트모템**: 클리어 결과 화면 진입 시 lore의 `postmortem`이 있으면 `self.pmCard = true`로
    오버레이 카드("포스트모템 #스테이지번호" + 본문 + 힌트 줄, 배경을 살짝 어둡게 깔아 초점을
    모음)가 자동으로 뜬다. 힌트 줄은 이 스테이지의 **첫 클리어**면 "Enter 닫기", 이미 한 번 이상
    클리어한 뒤의 **재클리어**면 "Enter 건너뛰기"로 바뀐다(`rec.clears`는 `result:enter`가 이번
    판 기록을 이미 반영한 뒤 값이므로, `clears > 1`이면 재클리어로 판정). Enter/좌클릭
    **1회차**는 카드만 닫고(`self.pmCard = false`), 카드가 이미 닫혀 있는 **2회차**부터 기존
    동작(스테이지 선택으로 이동)을 한다. 패배 시에는 카드가 뜨지 않는다(교육 보상은 클리어의
    몫). **`R` 재도전은 카드가 열려 있든 아니든 항상 즉시 동작**한다 — 반복 숙달 루프를 카드
    유무로 막지 않기 위해 `keypressed`에서 `r`을 카드 분기보다 먼저 처리한다.
  - **도감 origin**: `enemies.csv`의 `origin` 칼럼(이름의 유래 1~2문장)이 `codex`의 몬스터
    카드에서 desc 바로 아래 "유래: ..." 줄(회색, `printf` 줄바꿈)로 나온다. 값이 비어 있으면
    그 줄 자체가 그려지지 않는다.

## Wave D — 셸 진영 (Shell Mode)

설계서: `docs/superpowers/specs/2026-07-23-codedefense-shell-mode-design.md`. "타이핑 → 매크로 →
AI 에이전트가 대신 플레이"라는 게임의 최종 비전 중 두 번째 단계 — 모든 조작을 "한 줄 텍스트
명령"으로 통일해, 다음 회차의 외부 제어 어댑터가 그대로 올라탈 수 있게 준비한다.

- **진영 구조**: 타이틀 "게임 시작" → **진영 선택**(`states/faction.lua`, 신규) — `Lua 진영`
  (스크립트로 방어)과 `Shell 진영`(명령줄로 방어) 2항목을 ↑↓/마우스+Enter/클릭으로 고른다.
  셸 스테이지가 0개면(데이터 미도입 상태) Shell 항목이 "(준비 중)"으로 표시되며 진입이 막힌다
  (`faction:blocked`). 선택 결과("lua"|"shell")는 `stageselect`에 그대로 전달된다.
  - **데이터 축**: `stages.csv`의 `languages` 칼럼(빈 값="lua", "shell") + `ui` 칼럼("shell"이면
    에디터 대신 터미널 패널)이 진영을 가른다. 셸 스테이지 id는 전역과 겹치지 않게 **101번대**
    (101~106)를 쓴다 — Lua 진영(1~20)과 물리적으로 분리해 두면 이후 다른 언어 진영을 추가할 때도
    번호대만 새로 배정하면 된다. `progress`(cleared/records/codes)는 스테이지 id를 키로 그대로
    공유하므로 별도 마이그레이션이 필요 없다.
  - **진영 내 언락** (`src/factions.lua`, 순수 로직·love API 비참조·`tests/test_factions.lua`):
    `factions.idsFor(stages, faction)`가 해당 진영(`languageOf` 판정, mode=="normal")의 id를
    오름차순으로 뽑고, `factions.unlocked(ids, cleared, id)`가 "그 **목록 안에서** 바로 이전
    항목이 클리어됐는가"로 언락을 판정한다. 과거(Wave A 이전) 방식은 전역 id 오름차순 목록에서
    "리스트상 이전 항목"을 봤는데, 이게 우연히 진영 경계와 일치하던 것뿐이라 셸 스테이지 101이
    도입되자 "101의 이전 항목=Lua 20"이 되어버려 20을 클리어해야 101이 풀리는 오판정이 있었다
    (수정 완료, `test_factions.lua`가 "Lua 20 전부 클리어해도 셸 102는 안 풀림" 등으로 회귀 방지).
  - `states/stageselect.lua`는 `faction` 파라미터를 받아 `factions.idsFor`로 목록을 구성하고,
    제목에 진영명을 붙인다(`스테이지 선택 — Shell 진영`). ESC는 진영 선택으로 돌아간다. `play`
    화면의 ESC(2단 확인 후 나가기)도 `factions.languageOf(stage)`로 스테이지 자신의 진영을
    파생해 항상 올바른 진영의 stageselect로 복귀한다(별도 상태 전달 불필요).

- **`src/shell.lua` 계약** (순수 모듈, love API/`love.timer` 금지 — 헤드리스 테스트 대상):
  `Shell.new(battle)`이 셸 인스턴스를 만든다. 유일한 실행 진입점은
  `shell:exec(line, opts)` → `{ ok, output(문자열 배열), [open], [clear] }`이며, 실행한 원문을
  `shell.history`(문자열 배열, ↑↓ 이력 네비게이션이 참조)에 남긴다. `shell:tick(clock)`은
  battle의 시계값만 받아 `shell.cronJobs`(`{ id, interval, line, nextAt }` 배열) 중 due한 예약을
  id 순으로 실행하고 그 출력을 반환한다 — 셸 자신은 시계를 갖지 않는다(등록 시각 기준
  `nextAt += interval` 산술이라 드리프트 없는 결정론). `man`/`clear`는 뷰를 직접 호출하지 않고
  신호 필드만 돌려준다 — `open = "<명령>"`(뷰가 `dictOpen` 토글), `clear = true`(뷰가 출력 버퍼를
  비움). 이 "문자열 in → 문자열 out" 경계를 지키는 이유가 바로 다음 회차 외부 제어 어댑터
  준비다(아래 참고). `Shell.expectedTotal(battle)`은 "처치 k/N"의 N을 계산하는 순수 함수 —
  아래 battle.kills 절 참고.

- **명령 9종** (`src/shell.lua`의 `COMMANDS` 테이블, `name → run` 형태):

  | 명령 | 문법 | 출력(성공 시) |
  |---|---|---|
  | `build` | `build <타워> <행> <열> <이름>` | 신규 설치·오류는 `Battle:buildTower`의 기존 한글 로그 그대로 재사용한다. **멱등(이미 존재) 분기는 다르다** — `Battle:buildTower`가 이 경우 로그를 남기지 않으므로, 셸(`src/shell.lua`의 `cmdBuild`)이 직접 `이미 존재하는 타워입니다 — "<이름>"` 문구를 합성해 반환한다(최종 리뷰에서 정정 — 과거 서술 "기존 로그 공유"는 멱등 분기에는 해당하지 않았다) |
  | `rm` | `rm <이름>` | `Battle:demolishTower`(Wave A `demolish`)와 동일 코어 — 철거+환불 50% |
  | `ls` | `ls` / `ls enemies` | 무인자: `"<이름>" <타워명> (r,c) · 전략 <strat>` 목록(빈 목록 `배치된 타워가 없습니다`). `enemies`: `<적명> HP <n> (r,c)` 스폰 순 목록(은신 제외, 빈 목록 `필드에 적이 없습니다`) |
  | `top` | `top` | `서버 HP <n> · 잔액 $<m> · 처치 <k>/<total>`(배속은 `exec`의 `opts.speed`가 있을 때만 ` · 배속 x<%g>` 추가 — battle은 배속을 모른다). **배속 접미어는 비대칭이다**: 터미널에서 수동으로 친 `top`은 `states/play.lua`의 `termExec()`가 항상 `{ speed = self.speed }`를 넘기므로 배속이 x1이어도 ` · 배속 x1`부터 항상 붙지만, `cron`으로 예약되어 `shell:tick`이 대신 실행하는 `top`은 `runLine(job.line, {})`처럼 `opts`에 `speed`가 아예 없어 접미어가 붙지 않는다(의도된 동작 — battle 자체는 배속 개념이 없다) |
  | `target` | `target <타워> <전략>` | `Battle:setTargetStrategy` 성공 시 `전략 변경 — "<이름>" → <전략>`, 실패(없는 타워/전략)는 battle의 한글 오류 로그 재사용 |
  | `cron` | `cron <초> "<명령>"` / `cron -l` / `cron -r <id>` | 등록 `cron#<id> 등록 · <n>초마다 · "<명령>"`, 목록/삭제 각 1줄. 간격 1초 미만은 거부 |
  | `man` | `man <명령>` | 출력 없이 `{ open = "<명령>" }` 신호만 반환(뷰가 `BUILTIN_DOCS` 카드를 연다) |
  | `history` | `history` | `<번호>  <원문>` 번호 매김 목록(exec 자신의 호출도 포함) |
  | `clear` | `clear` | 출력 없이 `{ clear = true }` 신호만 반환(뷰가 버퍼를 비움) |

  - **ps1 별칭** 4종(`PS1_ALIASES`): `Remove-Item`→`rm`, `Get-Process`→`ls enemies`,
    `Get-Content`→`man`, `dir`→`ls` — 첫 토큰만 치환하고 나머지 인자는 그대로 이어붙여, 별칭이
    원 명령과 **완전히 동일한 코드 경로**(`COMMANDS` 조회)를 타게 한다(별도 분기 없음). 최초
    1회 별칭을 쓰면 결과 앞에 `PowerShell 사용자를 환영합니다` 한 줄이 덧붙는다(세션당 1회,
    `shell.ps1WelcomeShown`).
  - **오타 제안**: 명령어 토큰에만 레벤슈타인 거리를 적용한다(인자는 검사 대상 아님). 거리
    1 이내 후보가 있으면 `command not found: <입력> — '<후보>'를 의미했나요?`, 2 이상이면 제안
    없이 그대로 `command not found: <입력>`.
  - **cron 결정론**: 같은 시각에 등록하고 같은 간격이면 실행 시각열이 항상 동일하다(등록 시각
    기준 `nextAt` 누적 산술이라 프레임 레이트·호출 빈도에 무관). 한 번의 `tick` 호출에서 여러
    간격을 건너뛴 경우(큰 clock 점프)는 그만큼 반복 실행해 캐치업한다 — 그래서 회귀 러너는
    반드시 작은 dt로 자주 tick해야 한다(아래 ".sh 솔루션 러너" 참고). cron 실행 출력은
    `[cron#<id>] <명령>` 접두로 버퍼에 남아 수동 입력과 구분된다.
  - **출력 절단**: 한 명령의 출력이 20줄을 넘으면 20줄 + `…외 n건` 한 줄로 잘린다
    (`MAX_OUTPUT_LINES = 20`, `history`처럼 누적형 명령에서 특히 발생).

- **전략 4종** (`Battle:selectTarget`, `src/battle.lua`) — `Battle:setTargetStrategy(name, strat)`로
  타워별 `tw.strategy`를 바꾼다(기본값 `"nearest"`, 유효값 아니면 `false` + 한글 오류 로그).
  **네 전략 모두 이 타워의 사거리 안(`dist² <= range²`) + 은신(`isPhased`) 제외** 후보 중에서만
  고른다는 점이 공통이며(전역 판정 아님 — `world.oldest()` 같은 스크립트 API와는 다른 축),
  그 안에서 비교 기준만 다르다: `nearest`=거리 최소, `oldest`=`age` 최대(스폰이 가장 오래된),
  `strongest`=현재 hp 최대, `first`=서버라인까지 잔여 거리(`grid.dist`) 최소. **동률이면 항상
  먼저 스폰된(낮은 `id`) 적**을 고른다(네 전략 공통 타이브레이크). 구현은 "key가 더 크면 승리"
  형태로 통일해 네 비교를 한 분기에서 다룬다(`nearest`/`first`는 값의 부호를 뒤집어 "최대화"
  형태로 맞춘 것뿐 — 셋 다 실질은 최소화 지표다).

- **autoAttack** (`opts.autoAttack = true`, `states/play.lua`가 `ui=="shell"`일 때만 켠다):
  스크립트(`on_tick`) 없이 매 틱 `tw.strategy`대로 기본 공격만 수행하는 경로 —
  `Battle:runTick`에서 스크립트 경로와 **배타적**이다(`self.env.on_tick`이 있으면 항상 스크립트
  경로 우선). 쿨다운·투사체 생성은 기존 `resolveAttack`을 그대로 재사용해 Lua 진영과 동일한
  판정을 받는다. **오버클럭이 갱신되지 않는다** — 오버클럭은 `on_tick` 호출에 쓴 명령 예산으로
  계산되는데(`tw.overclock = 1 - used/(BUDGET/2)`), autoAttack은 그 호출 자체가 없으므로
  `tw.overclock`이 항상 초기값 그대로다. **밸런스 함의**: 데미지 배율에 오버클럭이 관여하지
  않으므로 셸 진영 타워는 "예산을 아주 적게 쓰는 최적화된 Lua 스크립트"가 낼 수 있는 최고
  발사 속도보다 항상 불리한 하한(배율이 사실상 고정)에 머문다 — 셸 스테이지 101~106의 예산/적
  구성은 전부 이 전제로 튜닝됐다(더 유리한 셈은 하지 않았다).

- **`battle.kills`**(`src/battle.lua`, 셸 `top` 명령 전용 집계): 적이 **사망**(hp 0)할 때만
  증가한다 — 서버라인 **도달**은 별개(`reachedByType`가 담당)이며 kills에 포함되지 않는다.
  `Shell.expectedTotal(battle)`이 "처치 k/N"의 N을 계산하는데, `split`/`split2` 능력을 가진 적은
  죽을 때마다 자식으로 갈라져(`split`은 자식 2, `split2`는 자식 2+손자 4) `kills`가 원래
  스폰 수보다 훨씬 커질 수 있다(실측: 스테이지 104의 concat-nil로 k=90 > 스폰 수 N=61). 이걸
  방치하면 "k/N"에서 k가 N을 넘는 모순 표기가 나오므로, N을 "모든 분열 자손까지 처치했을 때의
  최대 가능 처치 수"로 보정한다(`ev.count * 2`(split)/`ev.count * 6`(split2)를 원래 스폰 수에
  더함). split이 없는 스테이지는 보정량이 0이라 기존 "스폰 수 그대로" 표기와 완전히 같다.

- **.sh 솔루션 러너** (`tests/test_battle.lua`의 `runShellSolution`, 회귀 자동 검증): `ui=="shell"`
  스테이지는 스크립트 대신 `opts.autoAttack=true`인 `Battle` + `Shell.new(battle)`을 만들고,
  `solution_file`(`.sh`)을 줄 단위로 읽어 `battle:start()` **전**(`clock`이 카운트다운 구간,
  즉 실제 플레이에서 카운트다운 중 명령을 미리 쳐 두는 것과 동일한 타이밍)에 전부
  `shell:exec`한다 — `target`/`cron`은 등록형 지속 효과라 한꺼번에 실행해도 그 뒤 300초 동안
  똑같이 작동하므로 이 방식이 성립한다. 이후 시뮬레이션은 Lua 진영 회귀와 동일하게 **작은
  dt(1/30)** 로 `battle:update(dt)`를 반복 호출하되, **매 스텝 `shell:tick(battle.clock)`을
  반드시 함께 호출**한다 — 실제 플레이(`states/play.lua`의 `update`)와 동일한 카덴스로 cron이
  실행되게 하기 위해서다. 큰 dt로 건너뛰면 `tick`의 캐치업 로직(위 "cron 결정론" 참고) 때문에
  cron이 한꺼번에 몰아서 실행되어 실제 플레이와 다른 타이밍을 관측하게 된다 — 회귀와 실플레이의
  괴리를 막는 핵심 규칙이다. 106에는 이 러너와 별개로 "화력을 분산 배치하면 반드시 패배"하는
  반례 시나리오도 자동화돼 있다(같은 예산을 서버라인 앞뒤로 멀리 흩어 지으면 데드락 쌍의
  절반이 무방비로 뚫린다).

- **셸 스테이지 데이터 규칙** (`src/db.lua`의 `d.validate()` 확장): `ui=="shell"`이면
  `solution_file`이 **`.sh` 확장자 + 실제 파일 존재**를 요구한다(일반 검사는 `solution_file`이
  빈 값이면 통과시키므로 셸 진영은 별도 게이트가 필요했다) — 위반 시 한글 오류
  `솔루션(.sh) 파일 없음`으로 부팅이 즉시 중단된다. lore/미로/타임라인 등 기존 검사(§ "코딩
  규칙")는 진영 무관하게 그대로 적용된다. 101~106은 테마 "터미널"(101~103)·"파이프라인"
  (104~106), concept 칼럼에 명령 이름을 그대로 적었다(`ls`/`rm`/`top`/`man·target`/`cron`/
  `종합 시험`).

- **튜토리얼 이벤트 전진 배선(최종 리뷰에서 수정 완료)**: 과거에는 `states/play.lua`의
  `termExec()`(터미널 Enter 실행)가 `self.tut:notify(...)`를 전혀 호출하지 않아 셸 스테이지
  101의 튜토리얼(`data/curriculum/tutorial_101.lua`, 5스텝)이 전부 `advance={on="enter"}`로만
  진행됐다 — 그 결과 명령 실행을 지시하는 스텝에서도 Enter가 늘 튜토리얼 전진에 먼저 소비되어
  터미널까지 도달하지 못했다(`src/tutorial.lua`의 `Tutorial:keypressed`가 `adv.on=="enter"`인
  스텝에서 Enter를 무조건 가로채 `true`를 반환하므로, 호출부 `states/play.lua:keypressed`가
  `isShellStage()` 분기의 `termExec()`까지 내려가지 못했다 — 튜토리얼 중 명령 실행이 0회
  가능했던 근본 원인). 지금은 `termExec()`가 명령 실행 성공/실패와 무관하게 실행 직후
  `self.tut:notify("exec")`를 호출한다(F5 저장 경로의 `notify("saved")`/`notify("built")`와
  동일 패턴). `tutorial_101.lua`도 명령 실행을 지시하는 스텝 ②(`ls`)·③(`build`)·④(`ls
  enemies`)를 `advance={on="event", event="exec"}`로 바꿨다 — `Tutorial:keypressed`는
  `adv.on=="event"`인 스텝에서 Enter를 소비하지 않고 그대로 `false`를 반환하므로, Enter가
  `states/play.lua`의 `isShellStage()` 라우팅까지 흘러가 `termExec()`가 실제로 명령을
  실행한다. 설명 전용 스텝 ①과 마무리 스텝 ⑤는 여전히 `advance={on="enter"}`(Enter 수동
  전진)를 유지한다. ②~④는 터미널 타이핑이 필요하므로 `allow`에 `"textinput"` +
  편집/이력 키(`up`/`down`/`left`/`right`/`home`/`end`/`backspace`/`delete`)를 열어 뒀다
  (`"return"`은 `Tutorial:allows`가 항상 통과시키므로 목록에 넣지 않아도 된다).

- **106 학습 포인트 정정(집중 사격=희생자 선정)**: 처음 계획 문서에는 "표적을 분산해야
  데드락 쌍을 각각 끊는다"는 취지가 있었으나, 실측 결과 `pair` 경감은 **짝 중 한쪽이 사망(또는
  도달)하는 즉시 해제**되는 구조라(§ "몬스터·타워 능력 키워드"의 pair 행 참고) 실제 정답은
  반대다 — **화력을 한 곳에 모아 한쪽부터 먼저 끊는("희생자(victim) 선정") 것이 정답**이며,
  타워를 서버라인 앞뒤로 멀리 흩어 지으면 오히려 쌍의 절반이 무방비로 뚫려 패배한다(자동화된
  반례가 이를 증명, 위 ".sh 솔루션 러너" 참고). 데이터베이스 데드락 해소가 "희생 트랜잭션을
  골라 강제 종료"하는 것과 같은 비유라 `data/lore/106.lua`의 postmortem에도 이 표현을 그대로
  반영했다. "분산 필수"라는 원래 가정은 데이터/문서 양쪽에서 이미 정정 완료.

- **외부 제어 어댑터(다음 회차, 설계만 고정)**: `shell:exec`가 "문자열 in → 문자열 out"이므로
  어댑터는 얇게 붙는다 — 다음 회차에 `--cmdfile <경로>` 기동 옵션 → 그 파일을 tail 폴링 →
  한 줄씩 `shell:exec` → 결과를 `<경로>.out`에 append하는 구조로 고정했다(이번 회차는 게임 내
  터미널까지만, 이 어댑터 자체는 구현하지 않음). 목표는 Claude Code 같은 외부 에이전트가 파일에
  명령을 쓰면 게임이 그대로 실행되는 데모다. 외부 명령도 배포 로그에 동일하게 기록되어야 하고,
  하드코어 모드에서는 어댑터를 비활성화한다는 방침도 함께 정해 뒀다(둘 다 다음 회차 구현 시
  적용 — 이번 웨이브에서 이미 만든 부분 아님).

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
- (해소됨, 최종 리뷰) 과거 "셸 진영 튜토리얼(101)은 이벤트 기반 자동 진행이 없다"는 한계가
  있었으나 `termExec()`의 `tut:notify("exec")` 배선으로 해소됐다 — 상세는 § "Wave D — 셸 진영"의
  "튜토리얼 이벤트 전진 배선" 항목 참고.

## 다음 단계 (0.2+)

v0.1은 코어 루프(카운트다운→실시간→300초 생존)·샌드박스·에디터·통합 스크립트(`build`)·
아이템 해금·테크 의존성·코드 크래프트(오버클럭)·튜토리얼·CSV 데이터 기반 스테이지 12종(테마당
3개)·적 구성 패널·진행 바·문제 브리핑·히든 타워·도감·배포 로그까지의 범위다. 이후 플레이어빌리티
보강 웨이브(Wave A, `docs/superpowers/specs/2026-07-23-codedefense-playability-design.md`)에서
`demolish` API·슬로우 모드(x0.5)·별점·위기 경고·진행 바 눈금 색·패배 코칭·도감 프로필 탭·
스테이지 네러티브(브리핑/포스트모템)+도감 origin이 추가되었고, 이어진 신규 적·타워 웨이브
(Wave B, `docs/superpowers/specs/2026-07-23-codedefense-new-enemies-design.md`)에서 신규 적
7종+보스(커널 패닉)·신규 타워 2종(GC 수집기/디버거)·신규 스테이지 13~20(스레드/프로세스/
네트워크)·world API 확장(`age`/`speed`/`oldest`)이 추가되어 위 "구현된 규칙"에 반영돼 있다.
이어진 셸 진영 웨이브(Wave D, `docs/superpowers/specs/2026-07-23-codedefense-shell-mode-design.md`)
에서 진영 선택 UI·Shell 진영(명령줄 방어, 스테이지 101~106)·전략 4종+autoAttack·게임 내 터미널
패널이 추가되어 § "Wave D — 셸 진영"에 반영돼 있다(과거 이 절에 있던 "언어 진영 시스템(v1
프레임워크만)" 계획은 이로써 완료 — Lua 다음의 두 번째 실행 가능 진영이 실제로 붙었다).
설계서(`docs/superpowers/specs/2026-07-21-love2d-codedefense-design.md` 9장,
`docs/superpowers/specs/2026-07-22-codedefense-stage-experience-design.md`) 기준으로 다음이
남아 있다.

- **하드코어 모드**: 50단계, 클리어 타임 계측
- **클리어 타임 인증·공유**: 인증 카드 PNG 자동 생성 + 해시태그 공유 텍스트 클립보드 복사
- **밈 도감 심화**: 몬스터별 "실제 오류가 언제 나는지 + 어떻게 고치는지" 텍스트 영구 수집
  (현재 도감은 스탯·능력 카드까지만 — 실제 오류 텍스트 확장은 이연)
- **아이템 확장**: CPU 코어 증설(명령 예산 증가), 공용 라이브러리 탭 등 인벤토리 심화
- **외부 제어 어댑터(Wave D 설계 고정, 미구현)**: `--cmdfile <경로>` 기동 옵션 → 파일 tail
  폴링 → `shell:exec` → `<경로>.out`에 결과 append. Claude Code 같은 외부 에이전트가 파일에
  명령을 쓰면 게임이 실행되는 데모가 목표(§ "Wave D — 셸 진영"의 "외부 제어 어댑터" 참고).
  Python/JS/C# 등 다른 언어 진영을 추가한다면 이 어댑터 패턴이 그대로 재사용 가능한 뼈대다.
- **타워 매도(sell)**, 진행도 리셋 메뉴: 스펙에서 명시적으로 이연됨
- **타워 업그레이드 시스템**, 스테이지별 타일 틴트 변주, 도감 코드 예제 실행: 이번 웨이브
  범위 제외로 명문화됨(§8)

## 테스트

```powershell
& "C:\Program Files\LOVE\lovec.exe" tests
```

`tests/main.lua`가 `tests/test_*.lua` 스위트를 전부 실행하고 `RESULT pass=N fail=N`을 출력한다
(현재 814개, 전부 PASS — 16개 스위트: `test_csv`·`test_grid`·`test_sandbox`·`test_battle`·
`test_data`·`test_editor`·`test_progress`·`test_tutorial`·`test_particles`·`test_cutscene`·
`test_stageinfo`·`test_demolish`·`test_stars`·`test_abilities`·`test_shell`·`test_factions`.
`test_particles.lua`·`test_cutscene.lua`가 뷰 전용 이펙트/컷신 로직을, `test_stageinfo.lua`가
적 구성 패널 집계 유틸을, `test_demolish.lua`가 `Battle:demolishTower`(환불·재사용·틱 중 철거
스킵 방지)를, `test_stars.lua`가 `stars.of`의 HP→별점 경계값을 다룬다. `test_abilities.lua`
(Wave B 신규)가 `grow`/`pair`/`phase`/`split2`/`dash`/`resist`의 능력 6종(상한·경감 해제·주기·
깊이 제한 등)과 `splash`/`slowfield` 타워 능력, `world.oldest()`·스냅샷 `age`/`speed`, 그리고
같은 스크립트를 2회 실행했을 때 `status`/`serverHP`가 완전히 일치하는 결정론 재현까지
헤드리스로 검증한다. `test_shell.lua`(Wave D 신규)가 토크나이저·명령 9종·ps1 별칭·오타 제안·
cron 결정론·출력 절단과 함께 타워 전략 4종(사거리 필터·타이브레이크·은신 제외)을 다룬다.
`test_factions.lua`(Wave D 신규)가 `languageOf`/`idsFor`/`unlocked`의 진영 분리·진영 내 언락을
검증한다(특히 "Lua 20 전부 클리어해도 셸 102는 안 풀림"처럼 진영이 섞이지 않는지가 핵심
단언). `test_data.lua`는 `d.validate()`가 보지 못하는 lore 파일 "내용" 회귀도 잡는다 —
`lore_file`이 있는 모든 스테이지를 `io.open`+`loadstring`으로 직접 로드·실행해
`briefing`/`postmortem`이 비어있지 않은 문자열을 반환하는지 확인한다(구문 오류나 스키마
누락은 파일 존재 검사만으로는 잡히지 않기 때문). 브리핑/포스트모템 카드·도감 origin·스플래시
링·감속 점·셸 터미널 패널 같은 `states/*.lua`에만 있는 순수 뷰 표시는 헤드리스 스위트로
검증되지 않으므로, 오토플레이 하네스로 스크린샷을 찍어 육안 확인한다(§ "구현된 규칙"의 관련
항목 참고). 실패가 있으면 콘솔 종료 코드도 0이 아니게 된다.

스테이지를 추가할 때는 `data/curriculum/<n>_solution.lua`(Lua 진영) 또는 `<n>_solution.sh`
(Shell 진영)를 **반드시** 함께 추가해야 한다 — `tests/test_battle.lua`가 CSV에 등록된 모든
스테이지(현재 Lua 1~20 + Shell 101~106)를 순회하며, `ui=="shell"`이면 `.sh`를 줄 단위로
`shell:exec`한 뒤 autoAttack 배틀을 300초 이상 시뮬레이션해(§ "Wave D — 셸 진영"의 ".sh 솔루션
러너" 참고), 그 외에는 기존처럼 `solution_file`의 Lua 코드로 실제 전투를 실행해 클리어(300초
서버 생존)까지 확인하는 회귀 테스트이므로, 정답이 없거나 틀리면 테스트가 실패해 스테이지
추가가 자동으로 검증된다. Lua 진영 회귀는 `Battle:setScript`로 정답 스크립트를 주입하는
방식이며, 스크립트 안의 `build()` 좌표는 반드시 스테이지 예산(`budget`) 안에서 지을 수 있는
조합이어야 한다. 스테이지에 `naive_file`이 등록돼 있으면(퍼즐 스테이지 6·9·12·16·20) 같은
회귀 루프가 그 스크립트로도 전투를 돌려 **반드시 defeat**임을 함께 증명한다 — 순진 배치가
실제로 클리어해 버리면 테스트가 실패해 퍼즐 설계가 깨졌음을 알려준다.
