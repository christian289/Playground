-- 순진한 배치: 앞줄 건설칸에 프린터만 단일 차선으로 채운다. 광역도 없고 테크 체인(스나이퍼)도
-- 없다. 포크 밤·커널 패닉은 죽을 때마다 분열해 물량이 불어나고, 레거시는 프린터 저항이 있으며,
-- 커널 패닉은 방치하면 몸집(체력)까지 불어난다 -- 단일 표적 프린터만으로는 이 조합을 못 뚫고
-- 서버라인이 뚫린다.
build("printer", 8, 5, "p1")
build("printer", 8, 7, "p2")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
