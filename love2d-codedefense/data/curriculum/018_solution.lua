-- 프로세스 · 정밀 타격: 레거시 코드는 프린터 공격에 절반만 다친다(resist:printer).
-- 프린터를 아무리 늘려도 사거리 안에 머무는 시간(느린 이동) 대비 필요한 발수가 너무 많아
-- 끝장내기 전에 서버라인에 닿는다. 컴파일러로 스나이퍼를 열어 급소를 저격한다 —
-- 스나이퍼는 저항이 없고 사거리도 두 배라 통로 전체를 커버한다.
build("compiler", 9, 5, "c")
build("sniper", 9, 7, "s")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
