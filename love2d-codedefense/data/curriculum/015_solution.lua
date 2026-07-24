-- 스레드 · 안전 검사: 하이젠버그는 3초 보이고 2초 숨기를 반복한다. 숨어 있는 동안은
-- world.nearest()가 nil을 돌려준다 — 확인 없이 그대로 쓰면 다음 줄에서 필드 접근이 죽는다.
-- 보이는 순간에만 안전하게 조준한다.
build("printer", 6, 5, "a")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
