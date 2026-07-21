-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 3, "a")
build("printer", 7, 3, "b")

-- 003_solution.lua: 함수 호출의 반환값을 직접 인수로 전달합니다
function on_tick(self, world)
  self:attack(world.nearest())
end
