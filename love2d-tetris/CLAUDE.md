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
├─ main.lua        ← 엔트리 포인트 (love.load / update / draw)
├─ conf.lua        ← 창 크기(480x640), 타이틀 등 설정
├─ assets/         ← 폰트, 사운드 등 리소스
└─ lib/            ← 외부 라이브러리 (직접 수정 금지)
   ├─ classic.lua  ← rxi/classic: 경량 OOP (Object:extend())
   └─ hump/        ← vrld/hump: gamestate, timer, vector, signal, camera
```

## 코딩 규칙

- 라이브러리는 `require("lib.hump.gamestate")`, `require("lib.classic")` 형태로 로드
- `lib/` 아래 파일은 수정하지 않는다 (업스트림 원본 유지)
- 화면 전환은 hump의 `Gamestate` 사용 (title / play / gameover 상태 분리)
- 게임 오브젝트가 필요하면 classic으로 클래스 정의
- 낙하 타이밍·잠금 지연 등 시간 처리는 `dt` 누적 또는 hump `Timer` 사용
- 에셋 없이 `love.graphics.rectangle` 등 도형 렌더링만으로 완성 가능한 게임이므로, 스프라이트 이미지는 필수가 아님

## 게임 설계 메모 (바이브코딩 가이드)

- 보드: 10 x 20 그리드, 2차원 테이블로 표현 (0 = 빈 칸, 그 외 = 블록 색 인덱스)
- 테트로미노 7종(I, O, T, S, Z, J, L)과 회전 상태를 테이블로 정의
- 7-bag 랜덤 시스템 권장 (7개 한 세트를 섞어서 순서대로 지급)
- 조작: ←→ 이동, ↓ 소프트드롭, Space 하드드롭, ↑/X 회전, C 홀드, ESC 종료
- 라인 클리어 → 점수/레벨 → 낙하 속도 증가 순으로 단계적으로 구현
