-- 테이블 활용: 빈칸에 적 종류별 위협도를 담은 테이블을 넣으세요.
-- 더 긴급한 적 종류에 더 큰 값을 할당해, 점수가 가장 높은 적이 선택되게 하세요.
build("printer", 5, 3, "a")
build("printer", 9, 5, "b")
build("printer", 13, 9, "c")

function on_tick(self, world)
  local count = {}
  local PRIORITY = ______
  local target, bestScore = nil, -1
  for _, e in ipairs(world.enemies()) do
    count[e.type] = (count[e.type] or 0) + 1
    local score = (PRIORITY[e.type] or 0) * 1000 - e.dist
    if score > bestScore then target, bestScore = e, score end
  end
  if target then self:attack(target) end
end
