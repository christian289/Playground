# love2d-tetris

LÖVE (Love2D) 11.5로 만드는 테트리스 클론입니다.

## 요구 사항

- [LÖVE 11.5](https://love2d.org/) — `winget install love` 로 설치 가능

## 실행

```powershell
cd love2d-tetris
& "C:\Program Files\LOVE\lovec.exe" .
```

## 조작 (예정)

| 키 | 동작 |
|----|------|
| ← / → | 좌우 이동 |
| ↓ | 소프트 드롭 |
| Space | 하드 드롭 |
| ↑ / X | 회전 |
| C | 홀드 |
| ESC | 종료 |

## 사용 라이브러리

| 라이브러리 | 용도 | 라이선스 |
|-----------|------|---------|
| [classic](https://github.com/rxi/classic) | 경량 OOP 클래스 | MIT |
| [hump](https://github.com/vrld/hump) | gamestate, timer, vector 유틸 | MIT |
