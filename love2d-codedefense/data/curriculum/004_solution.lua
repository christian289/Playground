-- 데이터 영역: 블록 사이 통로를 지나는 적을 가장 가까운 순으로 처리합니다
build("printer", 7, 5, "a")
build("printer", 11, 7, "b")

-- 004_solution.lua: 조건문 없이는 우선순위가 없습니다. 가장 가까운 적부터 공격하세요
function on_tick(self, world)
  self:attack(world.nearest())
end
