local Object = require("lib.classic")

local Projectile = Object:extend()

function Projectile:new(x, y, target, damage, speed, size)
    self.x, self.y = x, y
    self.target = target       -- Enemy 참조 (죽으면 소멸)
    self.damage, self.speed, self.size = damage, speed, size
    self.done = false
end

-- clock: phase(은신) 판정용 battle clock. 명중 순간 대상이 은신 중이면 데미지는 무효화되고
-- 투사체는 그대로 통과·소멸한다(발사 자체는 막지 않는다 — 자동 타겟 선택 단계에서 이미
-- world.enemies()/nearest() 등이 은신 적을 제외하므로, 여기서는 이미 발사된 투사체가
-- 도중에 대상이 은신으로 들어간 경우만 걸러낸다).
function Projectile:update(dt, clock)
    if self.target.dead or self.target.reached then self.done = true return end
    local dx, dy = self.target.x - self.x, self.target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.speed * dt
    if dist <= step then
        if not self.target:isPhased(clock) then
            self.target.hp = self.target.hp - self.damage
        end
        self.done = true
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Projectile
