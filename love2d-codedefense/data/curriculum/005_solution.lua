-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 3, "a")
build("printer", 7, 3, "b")

-- 변수에 가장 가까운 적을 담아두면 여러 번 다시 찾지 않아도 됩니다
function on_tick(self, world)
    local t = world.nearest()
    self:attack(t)
end
