-- 힙 · 종합: 함수 + 반복 + 조건 + 테이블을 모두 써서 위협도 우선순위를 만든다
build("printer", 6, 4, "a")
build("printer", 9, 4, "b")
build("printer", 13, 5, "c")

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
