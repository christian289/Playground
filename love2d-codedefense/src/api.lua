-- 전투 스크립트 env에 self/world/build/아이템 API를 구성한다
local sandbox = require("src.sandbox")

local api = {}

local function snapshot(e, tower)
    local dx, dy = e.x - tower.x, e.y - tower.y
    return { id = e.id, hp = e.hp, max_hp = e.max_hp, x = e.x, y = e.y,
        speed = e.def.speed, type = e.def.id, dist = math.sqrt(dx * dx + dy * dy) }
end

-- on_spawn 핸들러에 넘길 dist 없는 단일 적 스냅샷
function api.plainSnapshot(e)
    return { id = e.id, hp = e.hp, max_hp = e.max_hp, x = e.x, y = e.y,
        speed = e.def.speed, type = e.def.id }
end

-- 전투당 하나의 스크립트 env. build/아이템 API 노출.
-- 현재 타워는 env 안이 아니라 이 클로저의 업밸류(tower)로만 들고 있는다 — env는 유저 스크립트의
-- _G이므로 여기에 원시 Tower 객체를 넣으면 유저 코드가 tower.def(세션 전체가 공유하는 정의
-- 테이블)를 직접 변조할 수 있는 샌드박스 회귀가 된다. 대신 setTower(tw)로만 갱신하고,
-- selfApi.attack은 그 업밸류를 참조한다.
function api.buildEnv(battle)
    local env = sandbox.baseEnv()
    local tower  -- 클로저 업밸류: 이번 틱에 on_tick을 실행 중인 타워 (env에는 절대 노출 안 함)
    local function setTower(tw) tower = tw end
    env.build = function(typeId, r, c, name)
        local ok, err = battle:buildTower(typeId, r, c, name)
        if not ok then battle:say("[설치 실패] " .. tostring(err)) end
        return ok
    end
    for _, it in ipairs(battle.items) do
        if it == "cache" then
            local store = {}
            env.cache = { get = function(k) return store[k] end,
                          set = function(k, v) store[k] = v end }
        elseif it == "webhook" then
            env.on_spawn = function(fn)
                if type(fn) == "function" then env._spawnFn = fn end
            end
        end
    end
    local selfApi = {}
    function selfApi.attack(s, target)
        if type(target) == "table" and target.id and tower then
            tower.pendingTarget = target.id
        end
    end
    env._selfApi = selfApi
    return env, setTower
end

-- 틱 직전: env.self/world를 현재 타워 기준으로 갱신
function api.refresh(env, tower, enemies)
    local snaps = {}
    for _, e in ipairs(enemies) do
        if not e.dead and not e.reached then snaps[#snaps + 1] = snapshot(e, tower) end
    end
    table.sort(snaps, function(a, b) return a.dist < b.dist end)
    local world = {}
    function world.enemies() return snaps end
    function world.nearest() return snaps[1] end
    function world.weakest()
        local best
        for _, s in ipairs(snaps) do if not best or s.hp < best.hp then best = s end end
        return best
    end
    function world.fastest()
        local best
        for _, s in ipairs(snaps) do if not best or s.speed > best.speed then best = s end end
        return best
    end
    env.world = world
    local selfApi = env._selfApi
    selfApi.name = tower.name
    selfApi.x, selfApi.y = tower.x, tower.y
    selfApi.range, selfApi.damage = tower.def.range, tower.def.damage
    selfApi.charge, selfApi.overclock = tower.charge, tower.overclock
    selfApi.ready = tower.cd <= 0
    env.self = selfApi
    return selfApi, world
end

return api
