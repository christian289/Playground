function on_tick(self, world)
  -- 조건문 개념: 널 포인터(null-ptr)는 타워를 크래시시키니 우선 공격하세요
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "______" then danger = e end
  end
  if danger then
    self:attack(danger)
  else
    self:attack(world.______())
  end
end
