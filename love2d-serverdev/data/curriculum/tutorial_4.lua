-- 튜토리얼 설계서(2026-07-21) 3장 "스테이지 4 — 빈칸과 퀵바" 시나리오
-- 설명 스텝은 allow = {}로 타이핑을 잠그고, 타이핑 스텝은 saved 이벤트로 진행한다.
return {
  { text = "빈칸(______)만 채우면 돼요.",
    allow = {}, advance = { on = "enter" } },
  { text = "F1~F4 퀵바로 코드 조각을 빠르게 넣을 수 있어요. 다 채웠으면 F5로 저장하세요.",
    anchor = { type = "ui", id = "quickbar" },
    allow = { "textinput", "f5", "f1", "f2", "f3", "f4", "up", "down", "left", "right",
              "home", "end", "backspace", "delete", "return", "tab", "s", "z", "y", "k", "u", "reload_hint" },
    advance = { on = "event", event = "saved" } },
}
