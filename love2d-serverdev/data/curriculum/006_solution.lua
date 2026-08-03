-- 데이터 영역 · 조건문: 널 포인터 러시가 중앙 길목으로 흐르는데, 건설칸은 모두 가장자리라
-- 프린터 사거리(120)로는 길목에 총알이 닿지 않는다. 컴파일러로 스나이퍼(사거리 240)를 열어
-- 가장자리에서 중앙을 저격한다. 조건문으로 널 포인터를 먼저 노린다.
build("compiler", 2, 10, "c")
build("sniper", 7, 2, "s1")
build("sniper", 13, 10, "s2")

function on_tick(self, world)
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "null-ptr" and (not danger or e.dist < danger.dist) then
      danger = e
    end
  end
  if danger then
    self:attack(danger)
  else
    self:attack(world.nearest())
  end
end
