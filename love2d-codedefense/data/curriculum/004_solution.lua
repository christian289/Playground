-- 004_solution.lua: 조건문 없이는 우선순위가 없습니다. 가장 가까운 적부터 공격하세요
function on_tick(self, world)
  self:attack(world.nearest())
end
