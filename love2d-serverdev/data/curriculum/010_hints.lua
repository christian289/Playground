-- 테이블 활용: 테이블에 적 종류별 수를 세어 위협을 판단해 보세요.
-- 널 포인터가 있으면 우선 공격하도록 만들면 좋습니다.
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
  -- 여기에 조건을 추가해 널 포인터를 우선해 보세요
  if target then self:attack(target) end
end
