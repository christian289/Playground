local Object = require("lib.classic")
local grid = require("src.grid")

local Tower = Object:extend()

function Tower:new(def, r, c, items)
    self.def = def
    self.r, self.c = r, c
    self.x, self.y = grid.toXY(r, c)
    self.x = self.x + grid.CELL / 2
    self.y = self.y + grid.CELL / 2
    self.items = items or {}
    self.cd = 0            -- 남은 쿨다운(초)
    self.charge = 0        -- 차지샷 누적(초, 최대 3)
    self.overclock = 0     -- 0..1 (직전 틱 효율)
    self.crashed = 0       -- 워치독 남은 초
    self.env = nil         -- battle이 샌드박스 env 부여
    self.pendingTarget = nil
    self.lastError = nil
    self.strategy = "nearest"  -- 표적 전략(autoAttack용, Wave D Task 1). 기본값 nearest.
end

function Tower:effectiveCooldown()
    return self.def.cooldown * (1 - 0.3 * self.overclock)
end

return Tower
