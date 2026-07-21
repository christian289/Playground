# love2d-mario

LÖVE (Love2D) 11.5 기반 슈퍼마리오 스타일 횡스크롤 플랫포머. 바이브코딩으로 게임 로직을 채워 나가는 프로젝트입니다.

## 실행 방법

```powershell
& "C:\Program Files\LOVE\lovec.exe" .   # 콘솔 출력(print) 확인 가능 — 개발 시 권장
& "C:\Program Files\LOVE\love.exe" .    # 콘솔 없이 실행
```

프로젝트 루트(이 폴더)에서 실행해야 합니다. `main.lua`가 엔트리 포인트입니다.

## 구조

```
love2d-mario/
├─ main.lua           ← 엔트리 포인트: 폰트/스프라이트 로드 후 title 상태로 전환
├─ conf.lua           ← 창 크기(800x600), 타이틀 등 설정
├─ src/
│  ├─ level.lua       ← STI 맵 로드 + bump_init + 엔티티 파싱(objectgroup) + 코인/깃발 렌더
│  ├─ sprites.lua     ← 런타임 캔버스로 스프라이트시트 생성 + anim8 그리드/애니메이션
│  ├─ player.lua      ← 플레이어 (가속/마찰, 가변 점프, bump slide 충돌, 걷기/점프 애니)
│  ├─ enemy.lua       ← 굼바형 적 (순찰, 벽 반전, 근접 활성화, 밟히면 납작 연출)
│  └─ fonts.lua       ← 나눔고딕(OFL) 로드 — 게임 내 텍스트 한글 지원
├─ states/
│  ├─ title.lua       ← 타이틀/조작법
│  ├─ play.lua        ← 핵심 루프 (충돌 이벤트 처리, 스톰프/사망, 카메라, HUD)
│  ├─ gameover.lua    ← 게임오버
│  └─ clear.lua       ← 코스 클리어
├─ tools/
│  └─ genmap/         ← 레벨 문자열 → Tiled Lua 맵 + 타일셋 PNG 생성기
├─ assets/
│  ├─ fonts/          ← NanumGothic-Regular.ttf (OFL 라이선스)
│  ├─ images/         ← tileset.png (genmap이 생성)
│  └─ maps/           ← level1.lua (genmap이 생성한 Tiled Lua 형식)
└─ lib/               ← 외부 라이브러리 (직접 수정 금지)
   ├─ bump.lua        ← kikito/bump: AABB 충돌 감지·해결
   ├─ anim8.lua       ← kikito/anim8: 스프라이트시트 애니메이션
   ├─ classic.lua     ← rxi/classic: 경량 OOP
   ├─ sti/            ← Simple Tiled Implementation: Tiled 맵 로드/렌더
   └─ hump/           ← vrld/hump: gamestate, camera 등
```

## 레벨 수정 방법

`tools/genmap/main.lua`의 MAP 문자열을 고친 뒤 프로젝트 루트에서:

```powershell
& "C:\Program Files\LOVE\lovec.exe" tools/genmap
```

`assets/maps/level1.lua`와 `assets/images/tileset.png`가 재생성된다. 생성된 맵 파일은 직접 수정하지 말 것.
Tiled 에디터로 만든 맵을 쓰려면 Lua로 export해서 `assets/maps/`에 두고 `src/level.lua`의 경로만 바꾸면 된다
(terrain 레이어에 `collidable=true` 속성, entities objectgroup에 coin/enemy/spawn/flag 타입 오브젝트 필요).

## 코딩 규칙

- 라이브러리 로드: `require("lib.bump")`, `require("lib.sti")`, `require("lib.hump.camera")` 형태
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지)
- 충돌은 **bump.lua 월드 하나로 통일** — 물리엔진(love.physics/Box2D)은 쓰지 않는다. 플랫포머에는 bump의 `world:move(item, goalX, goalY, filter)` 방식이 적합
- 맵은 Tiled 에디터로 제작 후 **Lua 형식으로 export**해서 `assets/maps/`에 두고 STI로 로드: `sti("assets/maps/level1.lua", { "bump" })` — STI의 bump 플러그인으로 충돌 레이어 자동 등록
- 화면 전환은 hump `Gamestate`, 스크롤은 hump `Camera` 사용
- 플레이어/적/아이템은 classic 클래스로 정의, 애니메이션은 anim8 그리드 사용
- 스프라이트는 픽셀아트 기준 `love.graphics.setDefaultFilter("nearest", "nearest")` 를 love.load 초반에 설정

## 구현된 게임 규칙

- 물리: 중력 1500, 점프 초속 -520, 키를 떼면 상승 감쇠(-180)로 가변 점프. 이동은 가속/마찰 + 최대 속도 230
- 충돌: bump 월드 하나. 플레이어 필터 — 지형 "slide", 코인/깃발/적 "cross" (cross 충돌은 play 상태가 이벤트로 처리)
- 적: 왼쪽으로 순찰, 벽(normal.x ≠ 0)에서 반전, 플레이어가 520px 이내로 오면 활성화. 낙하 중 위에서 접촉(플레이어 바닥과 적 상단 차 < 16px)이면 스톰프 +200, 아니면 사망
- 사망: 라이프 차감 후 레벨 재시작(점수/코인 유지, `play:enter`의 carry 파라미터), 라이프 소진 시 게임오버. 낙사(y > 레벨높이+60) 동일
- 상태 전환은 update 루프 도중이 아니라 `pendingDeath` 플래그로 모아 프레임 끝에서 처리 (루프 중 world 재구축 방지)
- 레벨: STI가 `assets/maps/level1.lua`(Tiled Lua 형식, 120x18 타일)를 로드. 지형 충돌은 `map:bump_init(world)`가 등록 — STI가 넣는 타일 아이템은 `kind`가 없어서 필터의 기본값 "slide"에 걸린다
- STI 렌더는 자체 캔버스를 쓰므로 hump 카메라 attach 안에서 그리지 않고 `map:draw(400 - cam.x, 300 - cam.y)`로 오프셋을 직접 넘긴다. 엔티티/플레이어는 attach 안에서 그린다
- 스프라이트: `src/sprites.lua`가 실행 시점에 캔버스로 픽셀아트 시트를 만들고 anim8로 애니메이션. anim8 애니메이션 객체는 프레임 상태를 가지므로 엔티티마다 `sprites.newXxxAnims()`로 새로 생성
- 카메라: hump Camera, x는 플레이어 추적(레벨 경계 클램프), y는 고정

## 다음 단계 (바이브코딩 가이드)

- Kenney (kenney.nl) 등 CC0 PNG 에셋으로 교체: 이미지 로드 후 sprites.lua의 그리드만 맞추면 됨 (원작 마리오 에셋은 저작권 문제로 사용 금지)
- 추가 아이디어: ?블록/버섯, 사운드(love.audio), 멀티 레벨, 타임 리밋, 배경 패럴랙스

## 테스트

자동화 테스트는 별도 LÖVE 프로젝트로 만들어 `package.path`에 이 폴더를 추가한 뒤
`states.play`를 require해서 검증한다 (스크래치패드에서 실행). 우측 이동+주기 점프 6000스텝
시뮬레이션과 깃발 클리어/경계벽/스톰프 시나리오 테스트를 통과한 상태.
하네스가 상태 전환 후에도 stale한 play를 계속 update하면 가짜 사망 로그가 나오니 주의.
