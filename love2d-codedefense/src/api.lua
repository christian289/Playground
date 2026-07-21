-- 타워 스크립트 env에 self/world/아이템 API를 구성한다
local sandbox = require("src.sandbox")

local api = {}

local function snapshot(e, tower)
    local dx, dy = e.x - tower.x, e.y - tower.y
    return {
        id = e.id, hp = e.hp, max_hp = e.max_hp, x = e.x, y = e.y,
        speed = e.def.speed, type = e.def.id,
        dist = math.sqrt(dx * dx + dy * dy),
    }
end

-- battle이 틱마다 호출: env에 최신 world/self를 주입
function api.buildEnv(tower, itemsById)
    local env = sandbox.baseEnv()

    -- 읽기 전용 self + attack 명령 (실제 발사는 battle이 검증 후 수행)
    local selfApi = {}
    function selfApi.attack(_, target)
        if type(target) == "table" and target.id then
            tower.pendingTarget = target.id
        end
    end
    env._selfApi = selfApi

    -- 아이템 해금 API
    for _, itemId in ipairs(tower.items) do
        if itemId == "cache" then
            local store = {}
            env.cache = {
                get = function(k) return store[k] end,
                set = function(k, v) store[k] = v end,
            }
        elseif itemId == "webhook" then
            env.on_spawn = function(fn)
                if type(fn) == "function" then tower.spawnHandler = fn end
            end
        end
    end
    return env
end

-- 틱 직전 world 스냅샷 갱신 (env 재사용, 상태 유지)
function api.refresh(env, tower, enemies)
    local snaps = {}
    for _, e in ipairs(enemies) do
        if not e.dead and not e.reached then
            snaps[#snaps + 1] = snapshot(e, tower)
        end
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
    selfApi.x, selfApi.y = tower.x, tower.y
    selfApi.range, selfApi.damage = tower.def.range, tower.def.damage
    selfApi.charge, selfApi.overclock = tower.charge, tower.overclock
    selfApi.ready = tower.cd <= 0
    env.self = selfApi
    return env.self, world
end

return api
