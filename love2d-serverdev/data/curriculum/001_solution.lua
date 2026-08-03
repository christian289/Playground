-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 10, "a")
build("printer", 11, 3, "b")

function on_tick(self, world)
    self:attack(world.nearest())
end
