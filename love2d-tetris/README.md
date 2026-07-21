# love2d-tetris

LÖVE (Love2D) 11.5로 만드는 테트리스 클론입니다.

## 요구 사항

- [LÖVE 11.5](https://love2d.org/) — `winget install love` 로 설치 가능

## 실행

```powershell
cd love2d-tetris
& "C:\Program Files\LOVE\lovec.exe" .
```

## 조작

| 키 | 동작 |
|----|------|
| ← / → | 좌우 이동 (길게 누르면 자동 반복) |
| ↓ | 소프트 드롭 |
| Space | 하드 드롭 |
| ↑ / X | 시계 방향 회전 |
| Z | 반시계 방향 회전 |
| C / Shift | 홀드 |
| P | 일시정지 |
| ESC | 타이틀로 (타이틀에서는 종료) |

## 구현된 기능

SRS 회전 + 월킥, 7-bag 랜덤, NEXT 4개 미리보기, 홀드, 고스트 피스,
잠금 지연(무브 리셋), DAS, 소프트/하드 드롭 점수, 레벨별 낙하 속도, 일시정지.

## 사용 라이브러리

| 라이브러리 | 용도 | 라이선스 |
|-----------|------|---------|
| [classic](https://github.com/rxi/classic) | 경량 OOP 클래스 | MIT |
| [hump](https://github.com/vrld/hump) | gamestate, timer, vector 유틸 | MIT |
