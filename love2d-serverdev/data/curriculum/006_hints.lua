-- 조건문 · 퍼즐: 건설칸은 모두 가장자리라 프린터 사거리로는 중앙 길목에 닿지 않습니다.
-- 컴파일러로 스나이퍼(사거리 240)를 열고, 가장자리에서 중앙을 저격하세요.
build("compiler", 2, 10, "c")
build("sniper", 7, 2, "s1")
build("sniper", 13, 10, "s2")

function on_tick(self, world)
  -- 조건문으로 널 포인터를 먼저 노려보세요
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "______" then danger = e end
  end
  self:attack(danger or world.nearest())
end
