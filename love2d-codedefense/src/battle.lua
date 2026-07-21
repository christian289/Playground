local Object = require("lib.classic")
local grid = require("src.grid")
local sandbox = require("src.sandbox")
local api = require("src.api")
local Enemy = require("src.enemy")
local Tower = require("src.tower")
local Projectile = require("src.projectile")

local TICK = 0.1            -- 10Hz 의사결정
local BUDGET = 3000         -- 틱당 명령 예산
local TOTAL = 300           -- 일반 모드 전투 총 시간(초)
local WATCHDOG = 3          -- 크래시 후 재시작(초)
local CHARGE_MAX = 3

local Battle = Object:extend()

function Battle:new(d, stageId, placements)
    self.d = d
    self.stage = assert(d.stages[stageId], "없는 스테이지: " .. tostring(stageId))
    self.grid = grid.load(d.root .. "/data/" .. self.stage.maze_file)
    self.timeline = d.timeline(stageId)
    self.spawned = {}          -- timeline 이벤트별 스폰한 수
    self.clock, self.tickAcc = 0, 0
    self.serverHP = 10
    self.status = "prep"
    self.pauseIdx = 1          -- 다음 pause_at 인덱스
    self.enemies, self.towers, self.projectiles, self.log = {}, {}, {}, {}
    self.nextEnemyId = 1

    -- 배치 (테크 의존성 검증 포함)
    local placed = {}
    for _, p in ipairs(placements) do placed[p.tower] = true end
    for _, p in ipairs(placements) do
        local def = assert(d.towers[p.tower], "없는 타워: " .. tostring(p.tower))
        if def.requires and def.requires ~= "" then
            assert(placed[def.requires],
                ("'%s' 건설에는 '%s' 타워가 필요합니다"):format(def.name, def.requires))
        end
        assert(self.grid.build[p.r] and self.grid.build[p.r][p.c],
            ("(%d,%d)는 건설칸이 아닙니다"):format(p.r, p.c))
        local tw = Tower(def, p.r, p.c, p.items)
        if p.code and p.code ~= "" and def.damage > 0 then
            local env = api.buildEnv(tw, d.items)
            local ok, err = sandbox.compile(p.code, env, def.id)
            if ok then tw.env = env
            else tw.crashed = WATCHDOG; tw.lastError = err end
        end
        self.towers[#self.towers + 1] = tw
    end
end

function Battle:start()
    if self.status == "prep" then self.status = "running" end
end

function Battle:say(msg)
    self.log[#self.log + 1] = msg
    if #self.log > 8 then table.remove(self.log, 1) end
end

function Battle:spawnFromTimeline()
    for i, ev in ipairs(self.timeline) do
        local n = self.spawned[i] or 0
        while n < ev.count and self.clock >= ev.at + n * ev.interval do
            local def = self.d.enemies[ev.spawn]
            local e = Enemy(def, 1, ev.col)
            e.id = self.nextEnemyId
            self.nextEnemyId = self.nextEnemyId + 1
            self.enemies[#self.enemies + 1] = e
            n = n + 1
            -- 웹훅(on_spawn) 아이템: 등장 즉시 핸들러 호출
            for _, tw in ipairs(self.towers) do
                if tw.spawnHandler and tw.crashed <= 0 and tw.env then
                    local selfApi = select(1, api.refresh(tw.env, tw, self.enemies))
                    sandbox.call(function() tw.spawnHandler(selfApi) end, BUDGET)
                end
            end
        end
        self.spawned[i] = n
    end
end

function Battle:runTick()
    for _, tw in ipairs(self.towers) do
        if tw.env and tw.crashed <= 0 and not tw.disabled and tw.env.on_tick then
            local selfApi, world = api.refresh(tw.env, tw, self.enemies)
            tw.pendingTarget = nil
            local ok, err, used = sandbox.call(tw.env.on_tick, BUDGET, selfApi, world)
            if not ok then
                if tw.recovering then
                    -- 워치독 복구 직후 곧바로 재발한 결함: 영구 결함으로 보고 재시작을 그만둔다
                    tw.disabled = true
                    tw.lastError = tostring(err)
                    self:say(("[비활성화] %s: 복구 직후 재크래시, 재시작 중단"):format(tw.def.name))
                else
                    tw.crashed = WATCHDOG
                    tw.lastError = tostring(err)
                    self:say(("[크래시] %s: %s"):format(tw.def.name, tostring(err)))
                end
            else
                tw.recovering = false
                -- 오버클럭: 예산을 절반 미만으로 쓰면 효율 1.0에 수렴
                tw.overclock = math.max(0, 1 - (used / (BUDGET / 2)))
                self:resolveAttack(tw)
            end
        end
    end
end

function Battle:resolveAttack(tw)
    if tw.cd > 0 then return end
    -- 공격 안 함 → 차지 누적
    if not tw.pendingTarget then
        tw.charge = math.min(CHARGE_MAX, tw.charge + TICK)
        return
    end
    local target
    for _, e in ipairs(self.enemies) do
        if e.id == tw.pendingTarget and not e.dead and not e.reached then target = e break end
    end
    if not target then return end
    local dx, dy = target.x - tw.x, target.y - tw.y
    if dx * dx + dy * dy > tw.def.range * tw.def.range then return end
    local mult = 1 + tw.charge * 0.5
    self.projectiles[#self.projectiles + 1] =
        Projectile(tw.x, tw.y, target, tw.def.damage * mult, tw.def.bullet_speed, 4 * mult)
    tw.charge = 0
    tw.cd = tw:effectiveCooldown()
end

function Battle:update(dt)
    if self.status ~= "running" then return end

    -- pause_at 도달 → 준비 단계
    local nextPause = self.stage.pause_at[self.pauseIdx]
    if nextPause and self.clock >= nextPause then
        self.pauseIdx = self.pauseIdx + 1
        self.status = "prep"
        return
    end

    self.clock = self.clock + dt
    self:spawnFromTimeline()

    self.tickAcc = self.tickAcc + dt
    while self.tickAcc >= TICK do
        self.tickAcc = self.tickAcc - TICK
        self:runTick()
    end

    for _, tw in ipairs(self.towers) do
        tw.cd = math.max(0, tw.cd - dt)
        if tw.crashed > 0 then
            tw.crashed = math.max(0, tw.crashed - dt)
            if tw.crashed == 0 then
                tw.recovering = true    -- 복구 직후 1회 재발하면 영구 비활성화
                self:say(("[워치독] %s 재시작"):format(tw.def.name))
            end
        end
    end

    for _, e in ipairs(self.enemies) do
        if not e.dead and not e.reached then e:update(dt, self.grid) end
    end
    for _, p in ipairs(self.projectiles) do
        if not p.done then p:update(dt) end
    end

    -- 정리: 죽음/도달 처리
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        if e.hp <= 0 and not e.dead then
            e.dead = true
            -- split 능력: 죽으면 절반 체력 둘로
            if (e.def.abilities or ""):find("split") and not e.isSplit then
                for k = -1, 1, 2 do
                    local child = Enemy(e.def, e.r, e.c)
                    child.hp = math.floor(e.max_hp / 2)
                    child.max_hp = child.hp
                    child.x = e.x + k * 8
                    child.isSplit = true
                    child.id = self.nextEnemyId
                    self.nextEnemyId = self.nextEnemyId + 1
                    self.enemies[#self.enemies + 1] = child
                end
            end
        end
        if e.reached and not e.counted then
            e.counted = true
            self.serverHP = self.serverHP - 1
            -- crash_tower 능력: 도달 시 최근접 타워 크래시
            if (e.def.abilities or ""):find("crash_tower") then
                local best, bd
                for _, tw in ipairs(self.towers) do
                    local dx, dy = tw.x - e.x, tw.y - e.y
                    local dd = dx * dx + dy * dy
                    if not bd or dd < bd then bd, best = dd, tw end
                end
                if best then
                    best.crashed = WATCHDOG
                    self:say(("[널 포인터] %s 크래시!"):format(best.def.name))
                end
            end
        end
        if e.dead or e.counted then table.remove(self.enemies, i) end
    end
    for i = #self.projectiles, 1, -1 do
        if self.projectiles[i].done then table.remove(self.projectiles, i) end
    end

    if self.serverHP <= 0 then self.status = "defeat" return end
    if self.clock >= TOTAL then self.status = "clear" end
end

return Battle
