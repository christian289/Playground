# Code Defense 튜토리얼 모드 설계서

- 날짜: 2026-07-21
- 대상 프로젝트: `love2d-codedefense` (0.1 병합 완료 상태 기준)
- 상태: 설계 승인됨 (구현 계획 대기)

## 1. 문제

신규 플레이어가 네 지점에서 전부 막힌다: ① 조작법을 모름 (B 건설, F5 시작 등),
② 목표가 불분명 (서버라인, 적의 출처), ③ 스테이지 3의 코딩 진입이 당황스러움
(world/self가 뭔지 안내 없음), ④ 전반적 온보딩 부재.

## 2. 해법 개요

**단계별 가이드 오버레이.** 별도 모드 없이 스테이지 1~4 위에 말풍선 안내가 뜨고,
해당 칸/요소가 하이라이트되며, 지시된 키만 입력되는 단계진행형. 스테이지마다
완료/스킵이 저장되어 재방문 시 나오지 않는다. 모든 스테이지에 상시 조작 힌트바 유지.

## 3. 플레이어 흐름 (스텝 시나리오)

### 스테이지 1 — 조작과 목표

1. (자유 진행) "버그들이 위에서 내려와요. 바닥의 파란 서버라인에 닿으면 서버가 다쳐요!"
2. (화살표만 허용, 목표 건설칸 깜빡임) "화살표로 커서를 노란 칸(건설칸)으로 옮기세요"
3. (B만 허용, `built` 이벤트로 진행) "B를 눌러 프린터 타워 건설! (예산 200)"
4. (화살표+B 허용, `built` 이벤트로 진행, 두 번째 목표 칸 깜빡임) "예산이 남았어요.
   한 기 더 지어서 협공해요!"
5. (Space만 허용) "Space로 타겟 전략을 골라보세요 — 이 버튼이 사실 코드예요"
6. (F5만 허용) "F5로 전투 시작!"
7. (전투 중, `speed_changed` 이벤트 진행) "1/2/4 키로 배속을 조절할 수 있어요"
8. (첫 pause_at 진입 이벤트) "전투가 잠시 멈췄어요. 준비를 다듬고 다시 F5!"

스텝 2·4의 앵커/목표 칸은 회귀 테스트로 클리어가 검증된 배치 좌표를 사용한다
(스테이지 1: (3,10)과 (11,3)).

### 스테이지 2 — 전략 변경

1. (Space 유도) "이번 적은 빨라요. Space로 '약한 적' 전략을 시험해보세요"

### 스테이지 3 — 코딩 입문

1. (Tab만 허용) "이제 진짜 코드를 만나요! Tab으로 에디터에 들어가세요"
2. (자유 진행) "world는 전장 전체, self는 이 타워예요. 위 주석의 코드를 그대로 따라 치면 됩니다"
3. (자유 진행) "틀려도 괜찮아요 — 문법 오류는 시작 전에 알려주고, 실행 중 오류는 그 타워만 잠깐 멈출 뿐이에요"
4. (F5 유도) "코드를 다 쳤으면 F5!"

### 스테이지 4 — 빈칸과 퀵바

1. (자유 진행) "빈칸(______)만 채우면 돼요"
2. (자유 진행) "F1~F4 퀵바로 코드 조각을 빠르게 넣을 수 있어요"

### 공통 규칙

- **Enter**: 자유 진행 스텝에서 다음으로. **X**: 이 스테이지 튜토리얼 전체 스킵.
- 완료/스킵 시 `progress.tutorial_done[stageId] = true` 저장 → 재방문 시 미표시.
- 리셋 수단은 0.1 범위에서 제공하지 않음 (저장 파일 삭제로만 가능).
- 상시 힌트바: prep/battle 하단 조작 요약 한 줄. 포커스 문맥에 맞게 표시
  (그리드 포커스면 그리드 키만, 에디터 포커스면 에디터 키만).

## 4. 아키텍처

### 4.1 신규 모듈 `src/tutorial.lua`

`Tutorial(steps)` 위젯 (classic 클래스). 스텝 스키마:

```lua
{
  text = "B를 눌러 타워 건설!",           -- 말풍선 텍스트 (한글)
  anchor = { type = "cell", r = 3, c = 3 } -- 하이라이트 대상 (선택)
         | { type = "ui", id = "editor" }  -- ui id: "editor"|"quickbar"|"serverline"|"budget"
         | nil,
  allow = { "b" },                          -- 허용 키 목록 (nil = 전부 허용)
  advance = { on = "key",   key = "b" }     -- 진행 조건 셋 중 하나:
          | { on = "enter" }                --   Enter로 넘김
          | { on = "event", event = "built" } -- 게임 이벤트로 넘김
}
```

메서드:

- `:allows(key) → bool` — 현재 스텝의 allow 검사 (X와 Enter는 항상 통과)
- `:keypressed(key)` — Enter 진행, X 스킵, advance.on=="key" 판정
- `:notify(event)` — advance.on=="event" 판정. 이벤트 어휘: `built`(건설 성공),
  `battle_start`(F5 성공), `paused`(pause_at 진입), `speed_changed`(배속 변경)
- `:draw(fonts, gridX, gridY)` — 말풍선(화면 하단 고정 박스) + 앵커 하이라이트
  (셀은 노란 테두리 깜빡임, ui는 해당 영역 테두리)
- `:done() → bool` — 전 스텝 완료 또는 스킵됨

### 4.2 스텝 데이터

- `data/curriculum/tutorial_1.lua` ~ `tutorial_4.lua` — 스텝 배열을 반환하는 Lua 파일
  (여러 줄 한글 텍스트이므로 CSV가 아닌 커리큘럼 파일 컨벤션).
- `data/stages.csv`에 `tutorial_file` 열 추가 (스테이지 5~8은 빈 값).

### 4.3 상태 통합 (최소 침습)

- prep/battle의 `keypressed` 최상단: `if self.tut and not self.tut:done() and not self.tut:allows(key) then return end`
  이후 `self.tut:keypressed(key)`.
- 이벤트 지점에서 `self.tut:notify("built" | "battle_start" | "paused" | "speed_changed")`.
- `draw` 마지막에 `self.tut:draw(...)` (말풍선이 최상위 레이어).
- battle→prep 재개 시 tutorial 객체를 ctx로 전달해 스텝 연속성 유지.
- 스테이지 진입 시 `progress.tutorial_done[stageId]`이면 tut = nil.
- 완료/스킵 시점에 `progress.save`.

### 4.4 저장 스키마 추가

`progress` 테이블에 `tutorial_done = { [stageId] = true }`. 기존 파일에 필드가 없으면
`load()`가 빈 테이블로 보강 (기존 세이브 호환).

## 5. 에러 처리·경계

- `tutorial_file`이 빈 값이면 오버레이 없음 (nil 안전).
- 스텝 파일 로드 실패(문법 오류 등) 시 튜토리얼 없이 진행 + 콘솔 경고 한 줄 —
  튜토리얼 데이터가 게임을 막아서는 안 된다.
- allow 게이팅은 ESC(뒤로가기)를 막지 않는다 — 플레이어가 언제든 나갈 수 있어야 함.
- X 스킵 즉시 저장 — 사망 후 재도전 시 다시 나오지 않음.

## 6. 테스트

- `tests/test_tutorial.lua` (신규, suites 등록): 헤드리스로 스텝 로직 검증 —
  allows 게이팅(허용 외 키 차단, X/Enter/ESC 통과), key/enter/event 진행, X 스킵 → done,
  전 스텝 소진 → done, 깨진 스텝 파일 로드 실패 안전성.
- `db.validate()`에 `tutorial_file` 실재 검사 추가 (+ baddata 픽스처 대응 없음 —
  빈 값 스킵 가드만).
- 기존 96개 테스트 무손상: Battle 시뮬은 변경하지 않으며(이벤트 notify는 상태 계층에서 호출),
  회귀 테스트는 상태 계층을 거치지 않는다.
- 수동 검증: 스테이지 1~4를 새 저장 파일로 실제 플레이하며 스텝 진행·하이라이트·스킵 확인.

## 7. 범위 제외 (0.2+)

- 튜토리얼 리셋 메뉴, 스테이지 5~8 심화 안내, 코딩 개념 인터랙티브 강의(입력 검사형),
  다국어.
