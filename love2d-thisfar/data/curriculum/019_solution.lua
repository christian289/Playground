-- 네트워크 · 물량 방어: DDoS 봇은 한 기 한 기는 하찮지만(HP 5), 러시 구간엔 0.4초 간격으로
-- 서른 기가 몰려온다. 단일 표적 화력은 발사 속도(쿨다운)에 갇혀 물량을 못 따라간다.
-- 길목(허브에서 좁아지는 통로)에 GC 수집기의 광역과 프린터의 연사를 겹쳐, 붙어서 오는
-- 봇 무리를 한 발에 여럿씩 쓸어담는다.
build("compiler", 7, 2, "c")
build("gc-collector", 9, 5, "gc")
build("printer", 9, 7, "p")

function on_tick(self, world)
  local e = world.nearest()
  if e then self:attack(e) end
end
