build("printer", 3, 3, "a")
build("printer", 9, 9, "b")
build("printer", 12, 6, "c")

-- 빈칸을 채우세요: 적이 없을 때의 기본 표적을 반환합니다 (힌트: nearest)
local function pick(world)
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
