-- 프로세스 · 광역 방어: 포크 밤은 죽을 때마다 같은 자리에서 둘로, 다시 넷으로 자기복제한다.
-- 단일 표적 화력으로 하나씩 잡으면 산수에서 진다 — 분열체가 항상 더 빨리 늘어난다.
-- GC 수집기는 명중 지점 주변까지 함께 청소한다(splash 반경 60). 방금 갈라진 분열체는
-- 같은 자리에 겹쳐 있으므로, 한 발이 여러 마리를 한꺼번에 쓸어간다. 좁은 문(회랑)을 따라
-- GC 수집기를 늘어세워 통로 전체를 담당한다.
build("compiler", 5, 7, "comp")
build("gc-collector", 5, 5, "gc1")
build("gc-collector", 7, 5, "gc2")
build("gc-collector", 9, 5, "gc3")
build("gc-collector", 11, 5, "gc4")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
