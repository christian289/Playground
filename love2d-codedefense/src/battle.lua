local Object = require("lib.classic")
local grid = require("src.grid")
local sandbox = require("src.sandbox")
local api = require("src.api")
local Enemy = require("src.enemy")
local Tower = require("src.tower")
local Projectile = require("src.projectile")

local TICK = 0.1            -- 10Hz 의사결정
local BUDGET = 3000         -- 틱당 명령 예산
local TOTAL = 300           -- 일반 모드 전투 총 시간(초, clock 기준)
local WATCHDOG = 3          -- 크래시 후 재시작(초)
local CHARGE_MAX = 3

local Battle = Object:extend()
Battle.TOTAL = TOTAL

function Battle:new(d, stageId, opts)
    opts = opts or {}
    self.d = d
    self.stage = assert(d.stages[stageId], "없는 스테이지: " .. tostring(stageId))
    self.grid = grid.load(d.root .. "/data/" .. self.stage.maze_file)
    self.timeline = d.timeline(stageId)
    self.spawned = {}          -- timeline 이벤트별 스폰한 수
    self.countdown = self.stage.countdown or 15
    self.clock = -self.countdown
    self.tickAcc = 0
    self.serverHP = 10
    self.money = self.stage.budget
    self.items = opts.items or {}
    self.status = "prep"       -- start() 전 상태 (테스트 호환)
    self.enemies, self.towers, self.projectiles, self.log = {}, {}, {}, {}
    self.towersByName = {}
    self.nextEnemyId = 1
    self.env = nil
    self.setTower = nil
    self.script = nil
    self.scriptError = nil
end

function Battle:start()
    if self.status == "prep" then self.status = "running" end
end

function Battle:say(msg)
    self.log[#self.log + 1] = msg
    if #self.log > 8 then table.remove(self.log, 1) end
end

-- 실시간 스크립트로 타워를 짓는다. 멱등: 같은 이름이 이미 있으면 성공(no-op).
function Battle:buildTower(typeId, r, c, name)
    if typeId == "구구클래스" then typeId = "gugu-class" end
    if type(name) ~= "string" or name == "" then return false, "타워 이름(4번째 인자)이 필요합니다" end
    if self.towersByName[name] then return true end          -- 멱등
    local def = self.d.towers[typeId]
    if not def then return false, ("없는 타워 종류: %s"):format(tostring(typeId)) end
    if def.requires and def.requires ~= "" then
        local has = false
        for _, tw in ipairs(self.towers) do
            if tw.def.id == def.requires then has = true end
        end
        if not has then
            return false, ("'%s' 건설에는 '%s' 타워가 먼저 필요합니다")
                :format(def.name, self.d.towers[def.requires].name)
        end
    end
    if def.limit then
        local n = 0
        for _, tw in ipairs(self.towers) do
            if tw.def.id == def.id then n = n + 1 end
        end
        if n >= def.limit then
            return false, ("%s는 스테이지당 %d개뿐입니다"):format(def.name, def.limit)
        end
    end
    r, c = tonumber(r), tonumber(c)
    if not (r and c and self.grid.build[r] and self.grid.build[r][c]) then
        return false, ("(%s,%s)는 건설칸이 아닙니다"):format(tostring(r), tostring(c))
    end
    for _, tw in ipairs(self.towers) do
        if tw.r == r and tw.c == c then return false, ("(%d,%d)에는 이미 타워가 있습니다"):format(r, c) end
    end
    if self.money < def.cost then
        return false, ("예산 부족: %s는 %d 필요 (잔액 %d)"):format(def.name, def.cost, self.money)
    end
    self.money = self.money - def.cost
    local tw = Tower(def, r, c, {})
    tw.name = name
    if def.ability == "gugu" then tw.dan = 2; tw.danTimer = 0 end
    self.towersByName[name] = tw
    self.towers[#self.towers + 1] = tw
    self:say(("[설치] %s → \"%s\" (%d,%d)"):format(def.name, name, r, c))
    return true
end

-- 실시간 스크립트 저장: 새 env를 컴파일해서 성공 시에만 교체(build 재실행 포함).
-- 실패 시 기존 env/script는 그대로 유지된다.
function Battle:setScript(code)
    local env, setTower = api.buildEnv(self)
    local compiled, err = sandbox.compile(code, env, "script")
    if not compiled then
        self.scriptError = tostring(err)
        return false, self.scriptError
    end
    self.env, self.setTower = env, setTower
    self.script = code
    self.scriptError = nil
    for _, tw in ipairs(self.towers) do
        tw.crashed, tw.disabled, tw.recovering, tw.lastError = 0, nil, nil, nil
    end
    return true
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
            if self.env and self.env._spawnFn then
                local snap = api.plainSnapshot(e)
                local ok, herr = sandbox.call(function() self.env._spawnFn(snap) end, BUDGET)
                if not ok then self:say("[웹훅 오류] " .. tostring(herr)) end
            end
        end
        self.spawned[i] = n
    end
end

function Battle:runTick()
    for _, tw in ipairs(self.towers) do
        if self.env and self.env.on_tick and tw.crashed <= 0 and not tw.disabled then
            self.setTower(tw)
            local selfApi, world = api.refresh(self.env, tw, self.enemies)
            tw.pendingTarget = nil
            local ok, err, used = sandbox.call(self.env.on_tick, BUDGET, selfApi, world)
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
    local dmg = tw.def.damage * (tw.dan or 1)
    self.projectiles[#self.projectiles + 1] =
        Projectile(tw.x, tw.y, target, dmg * mult, tw.def.bullet_speed, 4 * mult)
    tw.charge = 0
    tw.cd = tw:effectiveCooldown()
end

function Battle:update(dt)
    if self.status ~= "running" then return end

    self.clock = self.clock + dt
    if self.clock >= 0 then self:spawnFromTimeline() end

    self.tickAcc = self.tickAcc + dt
    while self.tickAcc >= TICK do
        self.tickAcc = self.tickAcc - TICK
        self:runTick()
    end

    for _, tw in ipairs(self.towers) do
        tw.cd = math.max(0, tw.cd - dt)
        if tw.dan and self.clock >= 0 and tw.dan < 9 then
            tw.danTimer = tw.danTimer + dt
            if tw.danTimer >= 30 then
                tw.danTimer = tw.danTimer - 30
                tw.dan = tw.dan + 1
                self:say(("[구구 클래스] %d단 돌입! %d × 1 = %d..."):format(tw.dan, tw.dan, tw.dan))
            end
        end
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
            self.money = self.money + (e.def.reward or 0)
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
