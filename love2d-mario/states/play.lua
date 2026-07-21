local Gamestate = require("lib.hump.gamestate")
local Camera = require("lib.hump.camera")
local bump = require("lib.bump")
local Level = require("src.level")
local Player = require("src.player")
local Enemy = require("src.enemy")
local fonts = require("src.fonts")
local sprites = require("src.sprites")

local play = {}

local STOMP_TOLERANCE = 16
local ENEMY_WAKE_DISTANCE = 520

-- carry: 사망 후 레벨 재시작 시 유지할 값 { score, coins, lives }
function play:enter(previous, carry)
    carry = carry or {}
    self.score = carry.score or 0
    self.coinsCount = carry.coins or 0
    self.lives = carry.lives or 3

    self.world = bump.newWorld(64)
    self.level = Level.build(self.world)
    self.player = Player(self.world, self.level.spawn.x, self.level.spawn.y)
    self.enemies = {}
    for _, e in ipairs(self.level.enemySpawns) do
        table.insert(self.enemies, Enemy(self.world, e.x, e.y))
    end
    self.cam = Camera(400, self.level.heightPx - 300)
    self.coinAnim = sprites.newCoinAnim()
    self.paused = false
    self.pendingDeath = false
end

function play:resolveEnemyContact(enemy)
    local p = self.player
    if p.vy > 0 and (p.y + p.h) - enemy.y < STOMP_TOLERANCE then
        enemy:die()
        self.score = self.score + 200
        p.vy = -330
    else
        self.pendingDeath = true
    end
end

function play:playerDie()
    if self.lives > 1 then
        Gamestate.switch(require("states.play"),
            { score = self.score, coins = self.coinsCount, lives = self.lives - 1 })
    else
        Gamestate.switch(require("states.gameover"), { score = self.score })
    end
end

function play:update(dt)
    if self.paused then return end
    dt = math.min(dt, 1 / 30)

    self.level.map:update(dt)
    self.coinAnim:update(dt)

    local dir = 0
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then dir = dir - 1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then dir = dir + 1 end

    local events = self.player:update(dt, dir)
    for _, col in ipairs(events) do
        local other = col.other
        if other.kind == "coin" and not other.collected then
            other.collected = true
            self.world:remove(other)
            self.score = self.score + 100
            self.coinsCount = self.coinsCount + 1
        elseif other.kind == "flag" then
            self.score = self.score + 1000
            Gamestate.switch(require("states.clear"), { score = self.score, coins = self.coinsCount })
            return
        elseif other.kind == "enemy" and not other.dead then
            self:resolveEnemyContact(other)
        end
    end

    for _, e in ipairs(self.enemies) do
        if not e.gone then
            if not e.dead and not e.active and math.abs(e.x - self.player.x) < ENEMY_WAKE_DISTANCE then
                e.active = true
            end
            if e.active or e.dead then
                if e:update(dt) then
                    self:resolveEnemyContact(e)
                end
                if not e.dead and e.y > self.level.heightPx + 100 then
                    e:die()
                end
            end
        end
    end

    if self.player.y > self.level.heightPx + 60 then
        self.pendingDeath = true
    end

    if self.pendingDeath then
        self.pendingDeath = false
        self:playerDie()
        return
    end

    local cx = math.max(400, math.min(self.player.x + self.player.w / 2, self.level.widthPx - 400))
    self.cam:lookAt(cx, self.level.heightPx - 300)
end

function play:keypressed(key)
    if key == "escape" then
        Gamestate.switch(require("states.title"))
        return
    end
    if key == "p" then
        self.paused = not self.paused
        return
    end
    if key == "space" or key == "z" or key == "up" or key == "w" then
        self.player:jump()
    end
end

function play:keyreleased(key)
    if key == "space" or key == "z" or key == "up" or key == "w" then
        self.player:cutJump()
    end
end

function play:draw()
    -- 구름 (고정 장식) — 지형보다 뒤에
    self.cam:attach()
    love.graphics.setColor(1, 1, 1, 0.85)
    for i = 0, 12 do
        local cx = i * 320 + 80
        local cy = 70 + (i * 53) % 70
        love.graphics.ellipse("fill", cx, cy, 46, 16)
        love.graphics.ellipse("fill", cx + 28, cy + 8, 34, 13)
    end
    self.cam:detach()

    -- STI 지형: 자체 캔버스에 그리므로 카메라 오프셋을 직접 넘긴다
    love.graphics.setColor(1, 1, 1)
    self.level.map:draw(math.floor(400 - self.cam.x), math.floor(300 - self.cam.y))

    -- 엔티티는 카메라 변환 안에서 그린다
    self.cam:attach()
    Level.drawEntities(self.level, sprites, self.coinAnim)
    for _, e in ipairs(self.enemies) do
        if not e.gone then e:draw() end
    end
    self.player:draw()
    self.cam:detach()

    -- HUD
    local w = love.graphics.getWidth()
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", 0, 0, w, 34)
    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("점수 %06d", self.score), 16, 5)
    love.graphics.print("코인 " .. self.coinsCount, 280, 5)
    love.graphics.print("목숨 " .. self.lives, 440, 5)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("P 일시정지  ESC 타이틀", 620, 8)

    if self.paused then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, w, love.graphics.getHeight())
        love.graphics.setFont(fonts.big)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("일시정지", 0, 260, w, "center")
    end
end

return play
