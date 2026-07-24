-- 순진한 배치: 앞쪽 건설칸부터 프린터로 채운다. 하지만 위쪽 세 칸은 적 경로에서 멀리 떨어진
-- 함정 자리(프린터 사거리 밖)라 총알이 닿지 않는다 -> 브루트포스는 시간초과처럼 무너진다.
build("printer", 2, 2, "p1")
build("printer", 3, 2, "p2")
build("printer", 3, 3, "p3")

function on_tick(self, world)
  self:attack(world.nearest())
end
