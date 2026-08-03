-- 순진한 배치: 프린터 세 기를 회랑(좁은 문)에 늘어세운 단일 표적 고화력 배치다.
-- 프린터 한 발은 딱 한 마리만 죽인다 -- 포크 밤은 죽을 때마다 둘로, 다시 넷으로
-- 자기복제하므로 한 마리씩 처리하는 속도로는 불어나는 물량을 절대 못 따라잡는다.
build("printer", 6, 5, "p1")
build("printer", 8, 5, "p2")
build("printer", 10, 5, "p3")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
