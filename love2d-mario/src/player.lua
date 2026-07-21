local Object = require("lib.classic")
local sprites = require("src.sprites")

local Player = Object:extend()

local GRAVITY = 1500
local MAX_FALL = 700
local JUMP_VY = -520
local JUMP_CUT_VY = -180
local ACCEL = 1400
local AIR_ACCEL = 900
local FRICTION = 1600
local AIR_FRICTION = 400
local MAX_SPEED = 230

function Player:new(world, x, y)
    self.kind = "player"
    self.world = world
    self.w, self.h = 24, 30
    self.x, self.y = x, y
    self.vx, self.vy = 0, 0
    self.onGround = false
    self.facing = 1
    self.anims = sprites.newPlayerAnims()
    self.anim = self.anims.idle
    world:add(self, x, y, self.w, self.h)
end

local function filter(item, other)
    local k = other.kind
    if k == "coin" or k == "flag" or k == "enemy" then
        return "cross"
    end
    return "slide"
end

-- dir: -1/0/1. 반환값: coin/flag/enemy와의 cross 충돌 목록 (play 상태에서 처리)
function Player:update(dt, dir)
    local accel = self.onGround and ACCEL or AIR_ACCEL
    if dir ~= 0 then
        self.vx = self.vx + dir * accel * dt
        self.vx = math.max(-MAX_SPEED, math.min(MAX_SPEED, self.vx))
        self.facing = dir
    else
        local fr = (self.onGround and FRICTION or AIR_FRICTION) * dt
        if self.vx > 0 then
            self.vx = math.max(0, self.vx - fr)
        else
            self.vx = math.min(0, self.vx + fr)
        end
    end

    self.vy = math.min(self.vy + GRAVITY * dt, MAX_FALL)

    local ax, ay, cols, len = self.world:move(self, self.x + self.vx * dt, self.y + self.vy * dt, filter)
    self.x, self.y = ax, ay

    self.onGround = false
    local events = {}
    for i = 1, len do
        local col = cols[i]
        local k = col.other.kind
        if k == "coin" or k == "flag" or k == "enemy" then
            table.insert(events, col)
        else
            if col.normal.y == -1 then
                self.onGround = true
                self.vy = 0
            elseif col.normal.y == 1 then
                self.vy = 0
            end
            if col.normal.x ~= 0 then
                self.vx = 0
            end
        end
    end

    -- 상태에 맞는 애니메이션 선택
    local target
    if not self.onGround then
        target = self.anims.jump
    elseif math.abs(self.vx) > 20 then
        target = self.anims.walk
    else
        target = self.anims.idle
    end
    if target ~= self.anim then
        self.anim = target
        self.anim:gotoFrame(1)
    end
    self.anim:update(dt)

    return events
end

function Player:jump()
    if self.onGround then
        self.vy = JUMP_VY
    end
end

-- 점프 키를 일찍 떼면 상승을 줄여 가변 점프 높이 구현
function Player:cutJump()
    if self.vy < JUMP_CUT_VY then
        self.vy = JUMP_CUT_VY
    end
end

function Player:draw()
    love.graphics.setColor(1, 1, 1)
    self.anim:draw(sprites.playerImg, self.x + self.w / 2, self.y + self.h / 2, 0, self.facing, 1, 16, 15)
end

return Player
