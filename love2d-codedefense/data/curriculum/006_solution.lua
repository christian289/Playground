-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 3, 3, "a")
build("printer", 7, 3, "b")

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
