-- 튜토리얼 설계서(2026-07-21) 3장 "스테이지 3 — 코딩 입문 (직접 타이핑)" 시나리오
return {
  { text = "이제 진짜 코드를 만나요! 이번엔 버튼 없이 직접 칩니다.",
    advance = { on = "enter" } },
  { text = "world는 전장 전체, self는 이 타워예요. 위 주석의 코드를 그대로 따라 치면 됩니다 — build로 설치, on_tick으로 조종.",
    anchor = { type = "ui", id = "editor" }, advance = { on = "enter" } },
  { text = "틀려도 괜찮아요 — 저장할 때 문법 오류면 기존 코드가 계속 돌고, 실행 중 오류는 그 타워만 잠깐 멈출 뿐이에요.",
    advance = { on = "enter" } },
  { text = "다 쳤으면 F5로 저장 — 저장하는 순간 전장에 반영돼요!",
    advance = { on = "event", event = "saved" } },
}
