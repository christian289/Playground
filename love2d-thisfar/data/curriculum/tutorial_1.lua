-- 튜토리얼 설계서(2026-07-21) 3장 "스테이지 1 — 목표와 첫 설치" 시나리오
return {
  { text = "버그들이 위에서 내려와요. 바닥의 파란 서버라인에 닿으면 서버가 다쳐요!",
    anchor = { type = "ui", id = "serverline" }, advance = { on = "enter" } },
  { text = "카운트다운 동안 첫 타워를 설치할 코드를 준비해요. 이 게임에서 타워는 오직 코드로만 지을 수 있어요.",
    advance = { on = "enter" } },
  { text = "[1] 버튼을 눌러보세요 — 코드가 자동으로 타이핑되고 저장되는 걸 지켜보세요!",
    anchor = { type = "cell", r = 3, c = 10 }, allow = { "1" },
    advance = { on = "event", event = "built" } },
  { text = "예산이 남았어요. [2] 버튼으로 한 기 더!",
    anchor = { type = "cell", r = 11, c = 3 }, allow = { "2" },
    advance = { on = "event", event = "built" } },
  { text = "1/2/4 키로 배속을 조절할 수 있어요. (Ctrl을 누른 채 눌러보세요)",
    advance = { on = "event", event = "speed_changed" } },
  { text = "적이 잠깐 끊겼어요. 이 틈에 코드를 다듬는 게 이 게임의 리듬이에요.",
    advance = { on = "enter" } },
}
