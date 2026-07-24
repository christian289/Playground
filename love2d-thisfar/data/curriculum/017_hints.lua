-- 브레이크포인트는 두 곳까지
build("debugger", _, _, "bp1")
build("printer", 5, 6, "p1")
build("debugger", _, _, "bp2")
build("printer", 13, 4, "p2")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
