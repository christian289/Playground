-- 스택 · 복합(반복+조건): 유효 사거리 칸이 극소수다. 아래쪽 세 자리에서만 길이 닿으므로
-- 그 자리에 몰아 짓고, 반복문 안 조건으로 널 포인터를 가장 가까운 순으로 먼저 처리한다.
build("printer", 9, 8, "a")
build("printer", 12, 9, "b")
build("printer", 15, 9, "c")

function on_tick(self, world)
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "null-ptr" and (not danger or e.dist < danger.dist) then
      danger = e
    end
  end
  self:attack(danger or world.nearest())
end
