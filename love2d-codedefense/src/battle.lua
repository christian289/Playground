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
local RESIST_MULT = 0.5     -- resist:<타워id> 감쇄 배율(직격·splash 피해자 공통)
local PAIR_MULT = 0.4       -- pair 동반 경감 배율(직격·splash 피해자 공통)

-- 표적 전략(Wave D Task 1, autoAttack용): nearest=거리 최소·oldest=age 최대·
-- strongest=현재 hp 최대·first=서버라인 잔여 거리 최소(grid.dist). 기본값은 "nearest".
local STRATEGIES = { nearest = true, oldest = true, strongest = true, first = true }

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
    self.autoAttack = opts.autoAttack == true  -- true면 스크립트 없이 tw.strategy대로 자동 공격
    self.status = "prep"       -- start() 전 상태 (테스트 호환)
    self.enemies, self.towers, self.projectiles, self.log = {}, {}, {}, {}
    self.towersByName = {}
    self.reachedByType = {}
    self.pairPending = {}      -- pair: 타임라인 이벤트 인덱스별 "짝을 기다리는 중"인 적(홀짝 매칭용)
    self.nextEnemyId = 1
    self.env = nil
    self.setTower = nil
    self.script = nil
    self.scriptError = nil
    self.userFuncs = {}
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

-- 이름으로 타워를 철거한다. 성공 시 towers/점유/멱등 빌드 캐시에서 제거하고 환불(cost의 절반,
-- 내림)을 money에 가산한다. 유저 스크립트(env.demolish)가 호출할 때만 상태가 바뀐다.
function Battle:demolishTower(name)
    local idx, tw
    for i, t in ipairs(self.towers) do
        if t.name == name then idx, tw = i, t break end
    end
    if not tw then
        self:say(("[오류] 철거 실패 — \"%s\" 타워가 없습니다"):format(tostring(name)))
        return false
    end
    table.remove(self.towers, idx)
    self.towersByName[name] = nil
    tw.demolished = true -- runTick 스냅샷 순회 중 "이번 틱에 이미 철거됨" 판정용
    local refund = math.floor(tw.def.cost * 0.5)
    self.money = self.money + refund
    self:say(("[철거] %s → \"%s\" · +%d 환불"):format(tw.def.name, name, refund))
    return true
end

-- 이름으로 타워의 표적 전략을 바꾼다(nearest/oldest/strongest/first). autoAttack 모드에서
-- runTick이 매 틱 이 전략으로 selectTarget을 호출한다. 실패해도 tw.strategy는 그대로 둔다.
function Battle:setTargetStrategy(name, strat)
    local tw = self.towersByName[name]
    if not tw then
        self:say(("[오류] 타워가 없습니다 — \"%s\""):format(tostring(name)))
        return false
    end
    if not STRATEGIES[strat] then
        self:say(("[오류] 알 수 없는 전략 — \"%s\" (nearest/oldest/strongest/first)"):format(tostring(strat)))
        return false
    end
    tw.strategy = strat
    return true
end

-- autoAttack용 표적 선택: tw.strategy(기본 nearest)에 따라 이 타워 사거리 안 + 은신 제외
-- 후보 중 하나를 고른다. 동률은 항상 먼저 스폰된(낮은 id) 적. self.enemies를 직접 순회하며
-- (api.refresh의 world.* 스냅샷과 달리) 스크립트 env 없이도 동작해야 하므로 별도 구현이다.
-- "bigger key wins" 한 형태로 통일해 네 전략의 비교·동률 로직을 하나의 분기로 다룬다:
--   nearest  → key = -dist2(거리 최소 = key 최대)
--   oldest   → key =  age (age 최대)
--   strongest→ key =  hp  (hp 최대)
--   first    → key = -잔여거리(grid.dist, 서버라인 잔여 거리 최소 = key 최대)
function Battle:selectTarget(tw)
    local strategy = tw.strategy or "nearest"
    local range2 = tw.def.range * tw.def.range
    local best, bestKey
    for _, e in ipairs(self.enemies) do
        if not e.dead and not e.reached and not e:isPhased(self.clock) then
            local dx, dy = e.x - tw.x, e.y - tw.y
            local dist2 = dx * dx + dy * dy
            if dist2 <= range2 then
                local key
                if strategy == "oldest" then
                    key = e.age
                elseif strategy == "strongest" then
                    key = e.hp
                elseif strategy == "first" then
                    local d = self.grid.dist[e.r] and self.grid.dist[e.r][e.c]
                    if d then key = -d end
                else -- "nearest"(기본값 및 미지정 포함)
                    key = -dist2
                end
                if key ~= nil and (not best or key > bestKey or (key == bestKey and e.id < best.id)) then
                    best, bestKey = e, key
                end
            end
        end
    end
    return best
end

-- 실시간 스크립트 저장: 새 env를 컴파일해서 성공 시에만 교체(build 재실행 포함).
-- 실패 시 기존 env/script는 그대로 유지된다.
function Battle:setScript(code)
    local env, setTower = api.buildEnv(self)
    local known = {}
    for k in pairs(env) do known[k] = true end
    local compiled, err = sandbox.compile(code, env, "script")
    if not compiled then
        self.scriptError = tostring(err)
        return false, self.scriptError
    end
    self.env, self.setTower = env, setTower
    self.script = code
    self.scriptError = nil
    local funcs = {}
    for k, v in pairs(env) do
        if not known[k] and type(v) == "function" then funcs[#funcs + 1] = k end
    end
    table.sort(funcs)
    self.userFuncs = funcs
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
            e.spawnedAt = self.clock          -- 결정론: 스폰 시각(clock) 기준 산술만 사용
            self.nextEnemyId = self.nextEnemyId + 1
            -- pair 능력: 같은 타임라인 이벤트(i) 안에서 스폰 순서(홀짝)로 둘씩 짝짓는다.
            -- 홀수 스폰의 마지막 1기는 짝이 없어 pairId/pairAlive가 끝까지 nil로 남는다.
            if e.abilities.pair then
                local pending = self.pairPending[i]
                if pending then
                    if not (pending.dead or pending.reached) then -- 짝이 스폰 전 이미 제거됐으면 죽은 참조로 연결하지 않는다
                        e.pairId, e.pairAlive = pending.id, true
                        pending.pairId, pending.pairAlive = e.id, true
                    end
                    self.pairPending[i] = nil
                else
                    self.pairPending[i] = e
                end
            end
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

-- 이번 틱에 순회할 타워 명단을 미리 스냅샷 복사해 둔다. self.towers를 직접 ipairs로 돌면,
-- 순회 도중 어떤 타워의 on_tick이 demolish()로 "이미 지나온" 타워를 철거할 때 table.remove가
-- 배열을 앞으로 당겨서 아직 차례가 오지 않은 뒤쪽 타워의 on_tick이 그 틱에서 통째로
-- 스킵되는 문제가 있었다(테스트: tests/test_demolish.lua ⑥). 스냅샷은 self.towers의 변경에
-- 영향받지 않으므로 이 문제가 사라지고, 대신 스냅샷 안의 타워가 이번 틱 중에 이미 철거됐는지는
-- tw.demolished 플래그로 별도 확인해 그 타워의 on_tick은 실행하지 않는다(⑦).
function Battle:runTick()
    local snapshot = {}
    for i, tw in ipairs(self.towers) do snapshot[i] = tw end
    for _, tw in ipairs(snapshot) do
        -- slowfield(디버거)는 공격하지 않는 순수 필드 타워다. damage가 0이라 결과적으로
        -- 피해가 안 나가는 것과는 무관하게, ability로 직접 분기해 타겟팅·on_tick 호출·명령
        -- 예산 소비 자체를 건너뛴다(우연히 0 데미지라서가 아니라 의도적으로 발사 루프 제외).
        -- 이 조건(eligible)은 스크립트 경로·autoAttack 경로 둘 다에 공통으로 적용된다.
        local eligible = not tw.demolished and tw.crashed <= 0 and not tw.disabled
            and tw.def.ability ~= "slowfield"
        if eligible and self.env and self.env.on_tick then
            self.setTower(tw)
            local selfApi, world = api.refresh(self.env, tw, self.enemies, self.clock)
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
        elseif eligible and self.autoAttack then
            -- autoAttack(스크립트 없는 셸 진영 등, Wave D Task 1): 스크립트 경로와 배타적이다
            -- (self.env.on_tick이 있으면 항상 스크립트 경로가 우선한다 — 위 elseif). tw.strategy로
            -- 표적을 고른 뒤 쿨다운·오버클럭·투사체 생성은 기존 resolveAttack을 그대로 재사용해
            -- 스크립트 공격과 동일한 판정을 받는다. on_tick 호출이 없으므로 오버클럭은 갱신하지
            -- 않는다(예산을 쓰지 않았으니 자연스러운 결과 — 기존 tw.overclock 값 그대로 유지).
            local target = self:selectTarget(tw)
            tw.pendingTarget = target and target.id or nil
            self:resolveAttack(tw)
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
    local dmg = tw.def.damage * (tw.dan or 1) * mult
    -- resist:<타워id> 능력: 그 타워 종류의 데미지만 절반으로 감쇄(내림, 최소 1). 무관한
    -- 타워 종류의 데미지는 기존과 동일(반올림 없이) 그대로 적용된다.
    if target.abilities.resist == tw.def.id then
        dmg = math.max(1, math.floor(dmg * RESIST_MULT))
    end
    -- pair 능력: 짝(pairId)이 아직 생존해 있는 동안(pairAlive)은 받는 데미지가 ×0.4(내림,
    -- 최소 1) — 신규 능력 경로라 floor·min1을 적용한다(기존 파이프라인은 그대로 둔다).
    -- 복합 시 resist 다음 pair 순서로 각각 floor 적용(순서가 결과를 바꿈).
    if target.abilities.pair and target.pairAlive then
        dmg = math.max(1, math.floor(dmg * PAIR_MULT))
    end
    -- splash 피해자별 경감(최종 리뷰 반영): splash 투사체는 명중 시점에 각 피해자마다 이
    -- 타워 def.id·같은 RESIST_MULT/PAIR_MULT로 resist→pair를 독립 재판정해야 하므로,
    -- 생성 인자에 tw.def.id와 두 상수를 함께 넘긴다(Projectile:update의 splash 루프 참고).
    self.projectiles[#self.projectiles + 1] =
        Projectile(tw.x, tw.y, target, dmg, tw.def.bullet_speed, 4 * mult, tw.def.ability == "splash",
            tw.def.id, RESIST_MULT, PAIR_MULT)
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
        if not e.dead and not e.reached then
            -- slowfield: 디버거(ability="slowfield") 사거리 안이면 감속. 여러 디버거가 겹쳐도
            -- 불리언 OR 판정이라 배율은 한 번만 적용되고(중첩 불가), 사거리를 벗어나면 다음
            -- 프레임 즉시 원복된다(상태를 누적 저장하지 않고 매 프레임 다시 판정하므로).
            local slowed = false
            for _, tw in ipairs(self.towers) do
                if tw.def.ability == "slowfield" then
                    local dx, dy = e.x - tw.x, e.y - tw.y
                    if dx * dx + dy * dy <= tw.def.range * tw.def.range then slowed = true break end
                end
            end
            e.slowed = slowed
            e:update(dt, self.grid, self.clock)
        end
    end
    for _, p in ipairs(self.projectiles) do
        if not p.done then p:update(dt, self.clock, self.enemies) end
    end

    -- 정리: 죽음/도달 처리
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        if e.hp <= 0 and not e.dead then
            e.dead = true
            self.money = self.money + (e.def.reward or 0)
            -- pair 능력: 짝이 죽으면 남은 쪽의 pairAlive를 즉시 false로 내려 데미지 경감을 해제한다.
            if e.abilities.pair and e.pairId then
                for _, other in ipairs(self.enemies) do
                    if other.id == e.pairId then other.pairAlive = false break end
                end
            end
            -- split/split2 능력: 죽으면 절반 체력 둘로 분열한다. split=최대 깊이 1(기존
            -- concat-nil 동작, 바이트 동일), split2=최대 깊이 2(깊이1 자식이 죽으면 한 번 더
            -- 분열, 깊이2는 분열하지 않음). 자식은 splitDepth를 상속해 깊이를 추적한다.
            -- (토큰 완전 일치이므로 "split2"가 "split" 판정에 오탐되지 않는다)
            local splitMaxDepth
            if e.abilities.split2 then splitMaxDepth = 2
            elseif e.abilities.split then splitMaxDepth = 1 end
            if splitMaxDepth then
                local depth = e.splitDepth or 0
                if depth < splitMaxDepth then
                    for k = -1, 1, 2 do
                        local child = Enemy(e.def, e.r, e.c)
                        child.hp = math.floor(e.max_hp / 2)
                        child.max_hp = child.hp
                        child.x = e.x + k * 8
                        child.isSplit = true
                        child.splitDepth = depth + 1
                        child.id = self.nextEnemyId
                        child.spawnedAt = self.clock
                        self.nextEnemyId = self.nextEnemyId + 1
                        self.enemies[#self.enemies + 1] = child
                    end
                end
            end
        end
        if e.reached and not e.counted then
            e.counted = true
            self.serverHP = self.serverHP - 1
            self.reachedByType[e.def.id] = (self.reachedByType[e.def.id] or 0) + 1
            -- pair 능력: 짝이 서버라인 도달로 제거될 때도 남은 쪽의 pairAlive를 즉시 false로
            -- 내려 데미지 경감을 해제한다(원 설계 "쌍이 모두 살아있으면 경감" — 사망뿐 아니라
            -- 도달로 필드에서 사라지는 경우도 동일하게 취급).
            if e.abilities.pair and e.pairId then
                for _, other in ipairs(self.enemies) do
                    if other.id == e.pairId then other.pairAlive = false break end
                end
            end
            -- crash_tower 능력: 도달 시 최근접 타워 크래시 (토큰 완전 일치)
            if e.abilities.crash_tower then
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
