function on_tick(self, world)
  -- 변수 개념: world.nearest()의 결과를 변수에 담아두면 재사용하기 편합니다
  local target = world.______()
  self:attack(target)
end
