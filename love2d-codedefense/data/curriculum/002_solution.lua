-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 3, "a")
build("printer", 7, 3, "b")

-- 002_solution.lua: 전략 바꾸기 — 가장 약한(체력 낮은) 적 우선 공격
function on_tick(self, world)
    self:attack(world.weakest())
end
