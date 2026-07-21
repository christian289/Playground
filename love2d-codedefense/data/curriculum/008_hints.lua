build("printer", 3, 3, "a")
build("printer", 7, 3, "b")
build("printer", 11, 3, "c")

-- 빈칸을 채우세요: 타겟을 고르는 함수를 직접 선언합니다 (힌트: local function 이름(world))
local ______ pick(world)
  local best = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "concat-nil" then
      if not best or e.hp < best.hp then best = e end
    end
  end
  return best or world.nearest()
end

function on_tick(self, world)
  self:attack(pick(world))
end
