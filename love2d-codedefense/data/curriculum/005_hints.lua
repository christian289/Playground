build("printer", 5, 5, "a")
build("printer", 9, 7, "b")

function on_tick(self, world)
  -- 빈칸을 채우세요: 가장 가까운 적을 변수에 담습니다
  local ______ = world.nearest()
  self:attack(target)
end
