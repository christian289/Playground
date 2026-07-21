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
├─ main.lua           ← 엔트리 포인트 (love.load / update / draw)
├─ conf.lua           ← 창 크기(800x600), 타이틀 등 설정
├─ assets/
│  ├─ images/         ← 스프라이트시트, 타일셋 이미지
│  └─ maps/           ← Tiled(.lua로 export한) 맵 파일
└─ lib/               ← 외부 라이브러리 (직접 수정 금지)
   ├─ bump.lua        ← kikito/bump: AABB 충돌 감지·해결
   ├─ anim8.lua       ← kikito/anim8: 스프라이트시트 애니메이션
   ├─ classic.lua     ← rxi/classic: 경량 OOP
   ├─ sti/            ← Simple Tiled Implementation: Tiled 맵 로드/렌더
   └─ hump/           ← vrld/hump: gamestate, timer, camera 등
```

## 코딩 규칙

- 라이브러리 로드: `require("lib.bump")`, `require("lib.sti")`, `require("lib.hump.camera")` 형태
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지)
- 충돌은 **bump.lua 월드 하나로 통일** — 물리엔진(love.physics/Box2D)은 쓰지 않는다. 플랫포머에는 bump의 `world:move(item, goalX, goalY, filter)` 방식이 적합
- 맵은 Tiled 에디터로 제작 후 **Lua 형식으로 export**해서 `assets/maps/`에 두고 STI로 로드: `sti("assets/maps/level1.lua", { "bump" })` — STI의 bump 플러그인으로 충돌 레이어 자동 등록
- 화면 전환은 hump `Gamestate`, 스크롤은 hump `Camera` 사용
- 플레이어/적/아이템은 classic 클래스로 정의, 애니메이션은 anim8 그리드 사용
- 스프라이트는 픽셀아트 기준 `love.graphics.setDefaultFilter("nearest", "nearest")` 를 love.load 초반에 설정

## 게임 설계 메모 (바이브코딩 가이드)

- 물리: 중력 상수 + 수직 속도 누적, 점프는 위 방향 초기 속도. 가변 점프(키를 떼면 상승 감쇠) 권장
- 이동: 가속/감속(마찰) 기반, 최대 속도 제한
- bump 충돌 필터로 구분: 지형 = "slide", 코인 등 아이템 = "cross", 밟을 수 있는 적 = 위에서 충돌 시 처치
- 순서: ① 사각형 플레이어 + 지형 충돌 + 점프 → ② STI 맵 로드 → ③ 카메라 추적 → ④ 애니메이션 → ⑤ 적/아이템
- 에셋이 준비되기 전에는 도형 렌더링으로 먼저 완성하고, 이후 스프라이트로 교체
- 무료 에셋: Kenney (kenney.nl) 등 CC0 에셋 사용 권장 (원작 마리오 에셋은 저작권 문제로 사용 금지)
