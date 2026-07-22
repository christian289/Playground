-- 순진한 배치: 앞쪽 건설칸부터 프린터로 채운다. 앞쪽 네 칸은 전부 왼쪽 채널(col2)이라
-- 가운데·오른쪽 갈래에는 총알이 닿지 않는다 -> 두 갈래가 그대로 새서 패배한다.
build("printer", 6, 2, "p1")
build("printer", 7, 2, "p2")
build("printer", 8, 2, "p3")
build("printer", 9, 2, "p4")

function on_tick(self, world)
  self:attack(world.nearest())
end
