-- 튜토리얼 설계서(2026-07-21) 3장 "스테이지 4 — 빈칸과 퀵바" 시나리오
return {
  { text = "빈칸(______)만 채우면 돼요.",
    advance = { on = "enter" } },
  { text = "F1~F4 퀵바로 코드 조각을 빠르게 넣을 수 있어요.",
    anchor = { type = "ui", id = "quickbar" }, advance = { on = "enter" } },
}
