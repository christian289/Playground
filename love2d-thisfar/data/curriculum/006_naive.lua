-- 순진한 배치: 앞쪽 건설칸부터 프린터로 채우고 가장 가까운 적을 친다.
-- 하지만 이 스테이지의 건설칸은 모두 가장자리(중앙 길목에서 128px)라 프린터 사거리(120)로는
-- 총알이 닿지 않는다 -> 널 포인터가 그대로 서버라인에 도달해 패배한다.
build("printer", 2, 2, "p1")
build("printer", 4, 2, "p2")
build("printer", 7, 2, "p3")

function on_tick(self, world)
  self:attack(world.nearest())
end
