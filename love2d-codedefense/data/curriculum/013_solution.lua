-- 스레드 · 정렬 기준: 메모리 릭은 스폰 후 시간이 지날수록 몸집(체력)이 불어난다.
-- 가까운 순으로 쏘면 방금 나온 릭에게 화력이 갈리고, 먼저 나온 릭은 자라난 채로 방치되다가
-- 결국 서버라인까지 밀고 온다. world.oldest()로 가장 오래 버틴 릭부터 끊는다.
build("printer", 4, 3, "a")

function on_tick(self, world)
  local e = world.oldest()
  if e then self:attack(e) end
end
