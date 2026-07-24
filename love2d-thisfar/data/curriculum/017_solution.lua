-- 프로세스 · 브레이크포인트: 레이스 컨디션은 1.5초마다 0.3초씩 속도가 3배로 튄다(대시).
-- 감속 없이는 통로를 스쳐 지나가 프린터가 끝장내기 전에 서버라인에 닿아버린다.
-- 디버거(스테이지당 최대 2기)를 통로 양 끝에 걸어 전체 구간에 브레이크포인트를 걸고,
-- 그 틈에 프린터 두 기로 확실히 끝장낸다.
build("debugger", 5, 4, "bp1")
build("printer", 5, 6, "p1")
build("debugger", 13, 6, "bp2")
build("printer", 13, 4, "p2")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
