-- 003_solution.lua: 함수 호출의 반환값을 직접 인수로 전달합니다
function on_tick(self, world)
  self:attack(world.nearest())
end
