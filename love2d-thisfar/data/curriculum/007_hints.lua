build("printer", 6, 7, "a")
build("printer", 12, 8, "b")

function on_tick(self, world)
  -- 반복문 개념: world.enemies() 목록을 순회하며 조건에 맞는 대상을 직접 골라보세요
  local target = nil
  for _, e in ipairs(world.______()) do
    if not target or e.hp < target.hp then
      target = e
    end
  end
  if target then
    self:attack(target)
  end
end
