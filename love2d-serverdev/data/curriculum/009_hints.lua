-- 복합(반복+조건) · 퍼즐: 유효 사거리 칸이 극소수입니다. 위쪽 칸은 경로에서 멀어 총알이
-- 닿지 않아요. 아래쪽 세 자리(9,8)/(12,9)/(15,9)에 몰아 짓고, 반복문 안 조건으로
-- 널 포인터를 먼저 처리하세요.
build("printer", 9, 8, "a")
build("printer", 12, 9, "b")
build("printer", 15, 9, "c")

function on_tick(self, world)
  local danger = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "null-ptr" and (not danger or e.dist < danger.dist) then
      danger = e
    end
  end
  self:attack(danger or world.______())
end
