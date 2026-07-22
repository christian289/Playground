-- 힙 · 테이블 활용: 테이블에 적 종류별 수를 세어 위협을 판단하고, 널 포인터가 있으면 우선한다
build("printer", 5, 3, "a")
build("printer", 9, 5, "b")
build("printer", 13, 9, "c")

function on_tick(self, world)
  local count = {}
  local target = nil
  for _, e in ipairs(world.enemies()) do
    count[e.type] = (count[e.type] or 0) + 1
    if not target or e.dist < target.dist then target = e end
  end
  for _, e in ipairs(world.enemies()) do
    if e.type == "null-ptr" then target = e break end
  end
  if target then self:attack(target) end
end
