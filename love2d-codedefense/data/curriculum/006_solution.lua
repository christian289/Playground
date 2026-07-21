-- null-ptr가 있으면 그놈부터: if로 우선순위를 만듭니다
function on_tick(self, world)
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "null-ptr" then danger = e end
  end
  if danger then
    self:attack(danger)
  else
    self:attack(world.nearest())
  end
end
