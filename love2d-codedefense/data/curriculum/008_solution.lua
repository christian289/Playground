-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 3, "a")
build("printer", 7, 3, "b")
build("printer", 11, 3, "c")

-- 타겟 선택 로직을 함수로 분리하면 on_tick이 읽기 쉬워집니다
local function pick(world)
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
