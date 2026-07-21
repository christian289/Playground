# love2d-tetris

LÖVE (Love2D) 11.5 기반 테트리스. 바이브코딩으로 게임 로직을 채워 나가는 프로젝트입니다.

## 실행 방법

```powershell
& "C:\Program Files\LOVE\lovec.exe" .   # 콘솔 출력(print) 확인 가능 — 개발 시 권장
& "C:\Program Files\LOVE\love.exe" .    # 콘솔 없이 실행
```

프로젝트 루트(이 폴더)에서 실행해야 합니다. `main.lua`가 엔트리 포인트입니다.

## 구조

```
love2d-tetris/
├─ main.lua           ← 엔트리 포인트: 폰트 로드 후 title 상태로 전환
├─ conf.lua           ← 창 크기(480x640), 타이틀 등 설정
├─ src/
│  ├─ tetromino.lua   ← 7종 모양(SRS)·색·회전 생성·월킥 테이블
│  ├─ board.lua       ← 10x20 그리드, fits/place/clearLines (classic 클래스)
│  └─ fonts.lua       ← 공용 폰트 (기본 폰트는 한글 미지원 → 게임 내 텍스트는 영문)
├─ states/
│  ├─ title.lua       ← 타이틀/조작법
│  ├─ play.lua        ← 핵심 게임 로직 (중력, DAS, 잠금 지연, 홀드, 고스트, 점수)
│  └─ gameover.lua    ← 결과 표시, 재시작
├─ assets/            ← 폰트, 사운드 등 리소스 (현재 미사용)
└─ lib/               ← 외부 라이브러리 (직접 수정 금지)
   ├─ classic.lua     ← rxi/classic: 경량 OOP (Object:extend())
   └─ hump/           ← vrld/hump: gamestate, timer, vector, signal, camera
```

## 코딩 규칙

- 라이브러리는 `require("lib.hump.gamestate")`, `require("lib.classic")` 형태로 로드
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지)
- 화면 전환은 hump의 `Gamestate` 사용 (title / play / gameover 상태 분리)
- 게임 오브젝트가 필요하면 classic으로 클래스 정의
- 낙하 타이밍·잠금 지연 등 시간 처리는 `dt` 누적 또는 hump `Timer` 사용
- 에셋 없이 `love.graphics.rectangle` 등 도형 렌더링만으로 완성 가능한 게임이므로, 스프라이트 이미지는 필수가 아님

## 구현된 게임 규칙

- 보드 10x20, 좌표는 1-기반 (col 1..10, row 1..20). row < 1 은 필드 위 숨김 영역으로 스폰에 사용
- 피스는 `{ type, rot(0-3), x, y }` 테이블 — x, y는 회전 박스 좌상단의 보드 좌표
- SRS 회전 + 월킥 (tetromino.lua의 킥 테이블은 화면 좌표계로 y 부호 반전됨)
- 7-bag 랜덤, NEXT 4개 표시, 홀드(피스당 1회), 고스트 피스
- 잠금 지연 0.5초, 이동/회전 시 리셋 (최대 15회) — `onSuccessfulShift()`
- DAS: 0.17초 지연 후 0.05초 간격 반복 이동
- 점수: 1/2/3/4줄 = 100/300/500/800 x 레벨, 소프트드롭 +1/칸, 하드드롭 +2/칸. 10줄마다 레벨업, 낙하 간격 `0.8 * 0.85^(level-1)`
- 게임오버: 스폰 위치 충돌 또는 필드 위(전부 row < 1)에서 잠금

## 테스트

자동화 테스트는 별도 LÖVE 프로젝트로 만들어 `package.path`에 이 폴더를 추가한 뒤
`src.board` / `states.play`를 require해서 검증한다 (스크래치패드에서 실행).
라인클리어·월킥·하드드롭 단위 검증과 랜덤 입력 3600스텝 시뮬레이션을 통과한 상태.
