local Object = require("lib.classic")
local sprites = require("src.sprites")

local Enemy = Object:extend()

local GRAVITY = 1500
local MAX_FALL = 700
local SPEED = 60
local SQUASH_TIME = 0.4

function Enemy:new(world, x, y)
    self.kind = "enemy"
    self.world = world
    self.w, self.h = 26, 26
    self.x, self.y = x, y
    self.vx = -SPEED
    self.vy = 0
    self.dead = false   -- 밟힌 상태 (충돌 제거됨, 납작한 모습으로 잠시 표시)
    self.gone = false   -- 완전히 사라짐
    self.active = false -- 플레이어가 가까이 오면 활성화
    self.deadTimer = 0
    self.anims = sprites.newEnemyAnims()
    world:add(self, x, y, self.w, self.h)
end

local function filter(item, other)
    local k = other.kind
    if k == "player" then
        return "cross"
    end
    if k == "coin" or k == "flag" or k == "enemy" then
        return nil
    end
    return "slide"
end

-- 반환값: 이번 프레임에 플레이어와 겹쳤는지
function Enemy:update(dt)
    if self.dead then
        self.deadTimer = self.deadTimer - dt
        if self.deadTimer <= 0 then
            self.gone = true
        end
        return false
    end

    self.anims.walk:update(dt)
    self.vy = math.min(self.vy + GRAVITY * dt, MAX_FALL)
    local ax, ay, cols, len = self.world:move(self, self.x + self.vx * dt, self.y + self.vy * dt, filter)
    self.x, self.y = ax, ay

    local touchedPlayer = false
    for i = 1, len do
        local col = cols[i]
        if col.other.kind == "player" then
            touchedPlayer = true
        else
            if col.normal.x ~= 0 then
                self.vx = -self.vx
            end
            if col.normal.y == -1 then
                self.vy = 0
            end
        end
    end
    return touchedPlayer
end

function Enemy:die()
    if self.dead then return end
    self.dead = true
    self.deadTimer = SQUASH_TIME
    self.world:remove(self)
end

function Enemy:draw()
    love.graphics.setColor(1, 1, 1)
    local anim = self.dead and self.anims.squash or self.anims.walk
    anim:draw(sprites.enemyImg, self.x + self.w / 2, self.y + self.h / 2, 0, 1, 1, 16, 15)
end

return Enemy
