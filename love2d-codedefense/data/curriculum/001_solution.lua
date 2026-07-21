-- 001_solution.lua: 버튼 모드 생성 코드와 동일
function on_tick(self, world)
    self:attack(world.nearest())
end
