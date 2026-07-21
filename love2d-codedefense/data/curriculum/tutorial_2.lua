-- 튜토리얼 설계서(2026-07-21) 3장 "스테이지 2 — 전략 버튼" 시나리오
return {
  { text = "이번 적은 빨라요. [3] 약한 적 우선 버튼으로 전략 코드를 바꿔보세요.",
    anchor = { type = "cell", r = 3, c = 3 }, allow = { "3" },
    advance = { on = "event", event = "built" } },
}
