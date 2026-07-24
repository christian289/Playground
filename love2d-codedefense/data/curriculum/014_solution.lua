-- 스레드 · 표적 분산: 데드락은 둘씩 짝지어 나타나고, 짝이 살아있는 동안은 받는 피해가
-- 40%로 줄어든다. 타워 한 기로 한쪽만 물고 늘어지면 시간이 모자라 나머지가 서버라인까지
-- 밀린다. 타워 두 기의 표적을 이름으로 갈라 짝을 동시에 두들기면, 경감이 걸린 채로도
-- 둘 다 무너뜨릴 수 있다 — 어느 한쪽이 죽는 순간 남은 쪽의 경감도 즉시 풀린다.
build("printer", 4, 3, "t1")
build("printer", 8, 3, "t2")

function on_tick(self, world)
  local first, second
  for _, e in ipairs(world.enemies()) do
    if not first or e.id < first.id then
      second = first
      first = e
    elseif not second or e.id < second.id then
      second = e
    end
  end
  if self.name == "t1" then
    if first then self:attack(first) end
  else
    if second then self:attack(second) end
  end
end
