-- 데이터 영역: 변수에 가장 가까운 적을 담아두면 여러 번 다시 찾지 않아도 됩니다
build("printer", 5, 5, "a")
build("printer", 9, 7, "b")

function on_tick(self, world)
    local t = world.nearest()
    self:attack(t)
end
