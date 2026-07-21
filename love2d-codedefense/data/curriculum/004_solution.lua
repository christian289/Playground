-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 7, 3, "a")
build("printer", 11, 3, "b")

-- 004_solution.lua: 조건문 없이는 우선순위가 없습니다. 가장 가까운 적부터 공격하세요
function on_tick(self, world)
  self:attack(world.nearest())
end
