local Object = require("lib.classic")

local Projectile = Object:extend()

function Projectile:new(x, y, target, damage, speed, size)
    self.x, self.y = x, y
    self.target = target       -- Enemy 참조 (죽으면 소멸)
    self.damage, self.speed, self.size = damage, speed, size
    self.done = false
end

function Projectile:update(dt)
    if self.target.dead or self.target.reached then self.done = true return end
    local dx, dy = self.target.x - self.x, self.target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.speed * dt
    if dist <= step then
        self.target.hp = self.target.hp - self.damage
        self.done = true
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Projectile
