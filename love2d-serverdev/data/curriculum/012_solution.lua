-- 힙 · 최종 시험: 세 갈래(분할 지점)가 서로 멀어 한 곳에 몰면 다른 갈래가 샌다.
-- 채널마다 한 기씩 나눠 짓고(왼쪽 1 · 가운데 1 · 오른쪽 2), 위협도 테이블로 표적을 고른다.
build("printer", 7, 2, "left")
build("printer", 11, 5, "mid")
build("printer", 11, 8, "right1")
build("printer", 13, 8, "right2")

local PRIORITY = { ["null-ptr"] = 3, ["concat-nil"] = 2, ["bug"] = 1 }

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
