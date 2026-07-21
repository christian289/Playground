# love2d-mario

LÖVE (Love2D) 11.5로 만드는 슈퍼마리오 스타일 횡스크롤 플랫포머입니다.

## 요구 사항

- [LÖVE 11.5](https://love2d.org/) — `winget install love` 로 설치 가능
- (맵 제작 시) [Tiled Map Editor](https://www.mapeditor.org/)

## 실행

```powershell
cd love2d-mario
& "C:\Program Files\LOVE\lovec.exe" .
```

## 조작

| 키 | 동작 |
|----|------|
| ← / → 또는 A / D | 좌우 이동 |
| Space / Z / ↑ / W | 점프 (길게 누르면 높이 점프) |
| P | 일시정지 |
| ESC | 타이틀로 (타이틀에서는 종료) |

## 구현된 기능

bump.lua 기반 플랫포머 물리(가변 점프, 가속/마찰), 문자열로 정의한 1개 레벨(120x18 타일),
적 밟기(스톰프)/접촉 사망, 코인, 깃발 클리어, 라이프 3개와 레벨 재시작, hump 카메라 추적, HUD.

그래픽은 현재 도형 렌더링입니다. 다음 단계: Tiled 맵(STI)과 스프라이트 애니메이션(anim8) 적용.

## 사용 라이브러리

| 라이브러리 | 용도 | 라이선스 |
|-----------|------|---------|
| [bump.lua](https://github.com/kikito/bump.lua) | AABB 충돌 감지·해결 | MIT |
| [anim8](https://github.com/kikito/anim8) | 스프라이트시트 애니메이션 | MIT |
| [classic](https://github.com/rxi/classic) | 경량 OOP 클래스 | MIT |
| [STI](https://github.com/karai17/Simple-Tiled-Implementation) | Tiled 맵 로드/렌더링 | MIT |
| [hump](https://github.com/vrld/hump) | gamestate, camera, timer 유틸 | MIT |

## 에셋

원작 마리오의 그래픽/사운드는 저작권 보호 대상이므로 사용하지 않습니다.
[Kenney](https://kenney.nl/assets) 등 CC0 무료 에셋을 사용하세요.
