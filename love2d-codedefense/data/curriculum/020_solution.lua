-- 네트워크 · 복합 방어: 전 종이 뒤섞여 몰려오고 마지막엔 커널 패닉(성장+분열 복합 보스)이
-- 온다. 이중 방어선으로 대응한다 — 앞줄(디버거+프린터)은 대시를 묶고 가장 오래 버틴(오래
-- 자란) 적부터 끊어 릭·커널 패닉이 몸집을 불리기 전에 끊는다. 뒷줄(컴파일러+GC 수집기 두
-- 기+스나이퍼)은 분열체(포크 밤·커널 패닉의 분신)를 광역 두 겹으로 쓸어담고, 저항이 있는
-- 레거시는 스나이퍼로 급소를 저격한다.
build("debugger", 8, 5, "bp1")
build("printer", 8, 7, "p1")
build("debugger", 11, 5, "bp2")
build("compiler", 11, 7, "c")
build("gc-collector", 12, 5, "gc1")
build("gc-collector", 12, 7, "gc2")
build("sniper", 14, 5, "s")

function on_tick(self, world)
  if self.name == "p1" then
    local e = world.oldest()
    if e then self:attack(e) end
  else
    local e = world.nearest()
    if e then self:attack(e) end
  end
end
