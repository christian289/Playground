-- 최종 시험 · 퍼즐: 세 갈래(왼쪽 c3 · 가운데 c6 · 오른쪽 c9)가 서로 멀어 한 곳에 몰면
-- 다른 갈래가 샙니다. 채널마다 나눠서 짓고(분할 지점 배치), 위협도로 표적을 고르세요.
build("printer", 7, 2, "left")
build("printer", 11, 5, "mid")
build("printer", 11, 8, "right1")
build("printer", 13, 8, "right2")

local PRIORITY = ______

local function pick(world)
  local best, bestScore = nil, -1
  for _, e in ipairs(world.enemies()) do
    local score = (PRIORITY[e.type] or 0) * 1000 - e.dist
    if score > bestScore then best, bestScore = e, score end
  end
  return best
end

function on_tick(self, world)
  local t = pick(world)
  if t then self:attack(t) end
end
