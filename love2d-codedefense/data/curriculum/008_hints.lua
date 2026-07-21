local function pick(world)
  -- 함수 개념: 보조 함수를 정의해 재사용하세요 (concat-nil은 죽으면 둘로 분열합니다)
  local best = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "concat-nil" then
      if not best or e.hp < best.hp then best = e end
    end
  end
  return best or world.______()
end

function on_tick(self, world)
  self:attack(pick(world))
end
