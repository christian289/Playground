-- 스레드 · 정렬 기준: 메모리 릭은 시간이 지날수록 커진다. 방치된 릭부터 끊어야 한다.
build("printer", 4, 3, "a")

function on_tick(self, world)
  -- 가장 오래 버틴 적부터: oldest
  local e = world.______()
  if e then self:attack(e) end
end
