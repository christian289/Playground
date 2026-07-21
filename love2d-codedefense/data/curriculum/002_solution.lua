-- 002_solution.lua: 전략 바꾸기 — 가장 약한(체력 낮은) 적 우선 공격
function on_tick(self, world)
    self:attack(world.weakest())
end
