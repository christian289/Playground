local Object = require("lib.classic")
local grid = require("src.grid")

local Enemy = Object:extend()

function Enemy:new(def, r, c)
    self.def = def
    self.id = nil          -- battle이 부여
    self.hp, self.max_hp = def.hp, def.hp
    self.r, self.c = r, c
    self.x, self.y = grid.toXY(r, c)
    self.x = self.x + grid.CELL / 2
    self.y = self.y + grid.CELL / 2
    self.dead, self.reached = false, false
end

-- 플로우필드를 따라 칸 중심에서 칸 중심으로 이동
function Enemy:update(dt, g)
    local tx, ty = grid.toXY(self.r, self.c)
    tx, ty = tx + grid.CELL / 2, ty + grid.CELL / 2
    local dx, dy = tx - self.x, ty - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.def.speed * dt
    if dist <= step then
        self.x, self.y = tx, ty
        if g.dist[self.r][self.c] == 0 then
            self.reached = true              -- 서버라인 도달
            return
        end
        local f = g.flow[self.r][self.c]
        if f then self.r, self.c = self.r + f[1], self.c + f[2] end
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Enemy
