-- 전투 스크립트 env와 함수 사전이 공유하는 읽기 전용 API 정의.
local sandbox = require("src.sandbox")

local api = {}

api.CATALOG = {
    { name = "build", sig = 'build(종류, 행, 열, "이름")', lines = { "타워를 짓는 유일한 수단", "같은 이름 재호출은 무시(멱등)", "예산 차감 · 건설칸(B) 전용" }, example = 'build("printer", 3, 10, "a")' },
    { name = "demolish", sig = 'demolish("이름")', lines = { "이름으로 타워를 철거하고 비용의 50%를 환불한다", "없는 이름이면 false와 오류 로그를 반환한다" }, example = 'demolish("a")' },
    { name = "self:attack", sig = "self:attack(적)", lines = { "현재 타워의 다음 공격 대상을 지정한다", "self는 게임이 매 틱 갱신하는 읽기 전용 정보다" }, example = "self:attack(world.nearest())" },
    { name = "world.enemies", sig = "world.enemies()", lines = { "보이는 적 스냅샷 목록을 반환한다", "반환 목록과 적 스냅샷은 읽기 전용이다" }, example = "for _, e in ipairs(world.enemies()) do end" },
    { name = "world.nearest", sig = "world.nearest()", lines = { "가장 가까운 적 스냅샷을 반환한다(없으면 nil)" }, example = "local e = world.nearest()" },
    { name = "world.weakest", sig = "world.weakest()", lines = { "HP가 가장 낮은 적 스냅샷을 반환한다(없으면 nil)" }, example = "local e = world.weakest()" },
    { name = "world.fastest", sig = "world.fastest()", lines = { "속도가 가장 빠른 적 스냅샷을 반환한다(없으면 nil)" }, example = "local e = world.fastest()" },
    { name = "world.oldest", sig = "world.oldest()", lines = { "필드에서 가장 오래 버틴 적 스냅샷을 반환한다(없으면 nil)", "동률이면 더 먼저 스폰된 적을 고른다" }, example = "local e = world.oldest()" },
    { name = "cache.get", sig = "cache.get(키)", lines = { "공유 캐시에서 값을 읽는다", "cache는 타워 사이에서 공유된다" }, example = 'local n = cache.get("count")', requires = "cache", reward = "캐시" },
    { name = "cache.set", sig = "cache.set(키, 값)", lines = { "공유 캐시에 값을 저장한다" }, example = 'cache.set("count", n)', requires = "cache", reward = "캐시" },
    { name = "on_spawn", sig = "on_spawn(function(적) ... end)", lines = { "적이 등장할 때 실행할 콜백을 등록한다", "콜백 적 스냅샷에는 dist가 없다" }, example = 'on_spawn(function(e) if e.type == "bug" then end end)', requires = "webhook", reward = "웹훅" },
    { name = "enemy.id", sig = "적.id", lines = { "적의 스폰 순번" }, example = "if e.id == 1 then end", snapshot = true },
    { name = "enemy.type", sig = "적.type", lines = { "적 종류 ID" }, example = 'if e.type == "bug" then end', snapshot = true },
    { name = "enemy.hp", sig = "적.hp", lines = { "현재 체력" }, example = "if e.hp < 10 then end", snapshot = true },
    { name = "enemy.speed", sig = "적.speed", lines = { "현재 적용 속도" }, example = "if e.speed > 1 then end", snapshot = true },
    { name = "enemy.dist", sig = "적.dist", lines = { "현재 타워와의 거리", "on_spawn 콜백의 적에는 없다" }, example = "if e.dist < self.range then end", snapshot = true },
    { name = "enemy.age", sig = "적.age", lines = { "등장 뒤 지난 시간" }, example = "if e.age > 5 then end", snapshot = true },
}

function api.docsByName()
    local docs = {}
    for _, doc in ipairs(api.CATALOG) do docs[doc.name] = doc end
    return docs
end

local function readonly(values, label)
    return setmetatable({}, {
        __index = values,
        __newindex = function(_, key)
            error(label .. "." .. tostring(key) .. "은 읽기 전용입니다", 2)
        end,
        __metatable = false,
    })
end

local readonlyLists = setmetatable({}, { __mode = "k" })

local function readonlyList(values, label)
    local list = setmetatable({}, {
        __index = values,
        __newindex = function(_, key)
            error(label .. "[" .. tostring(key) .. "]은 읽기 전용입니다", 2)
        end,
        __metatable = false,
    })
    readonlyLists[list] = values
    return list
end

local function listIpairs(list)
    local values = readonlyLists[list]
    if not values then return ipairs(list) end
    local function iterate(_, index)
        index = index + 1
        local value = values[index]
        if value ~= nil then return index, value end
    end
    return iterate, list, 0
end

local function snapshot(e, tower)
    local dx, dy = e.x - tower.x, e.y - tower.y
    return readonly({
        id = e.id,
        hp = e.hp,
        speed = e.speed,
        age = e.age,
        type = e.def.id,
        dist = math.sqrt(dx * dx + dy * dy),
    }, "적 스냅샷")
end

-- on_spawn 핸들러에 넘길 dist 없는 단일 적 스냅샷
function api.plainSnapshot(e)
    return readonly({
        id = e.id,
        hp = e.hp,
        speed = e.speed,
        age = e.age,
        type = e.def.id,
    }, "적 스냅샷")
end

local states = setmetatable({}, { __mode = "k" })

-- 전투당 하나의 스크립트 env. 유저 전역은 env 원본에, 기본 API는 metatable에 분리한다.
function api.buildEnv(battle)
    local env = sandbox.baseEnv()
    env.ipairs = listIpairs
    local tower
    local spawnFn
    local selfValues, worldValues = {}, {}
    selfValues.attack = function(_, target)
        if type(target) == "table" and target.id and tower then
            tower.pendingTarget = target.id
        end
    end
    local selfApi = readonly(selfValues, "self")
    local worldApi = readonly(worldValues, "world")
    local protected = { build = true, demolish = true, self = true, world = true, cache = true, on_spawn = true, _spawnFn = true }
    local exposed = {
        build = function(typeId, r, c, name)
            local ok, err = battle:buildTower(typeId, r, c, name)
            if not ok then battle:say("[설치 실패] " .. tostring(err)) end
            return ok
        end,
        demolish = function(name)
            return battle:demolishTower(name)
        end,
        self = selfApi,
        world = worldApi,
    }

    for _, item in ipairs(battle.items) do
        if item == "cache" then
            local store = {}
            exposed.cache = readonly({
                get = function(key) return store[key] end,
                set = function(key, value) store[key] = value end,
            }, "cache")
        elseif item == "webhook" then
            exposed.on_spawn = function(fn)
                if type(fn) == "function" then spawnFn = fn end
            end
        end
    end

    setmetatable(env, {
        __index = function(_, key)
            if key == "_spawnFn" then return spawnFn end
            return exposed[key]
        end,
        __newindex = function(t, key, value)
            if protected[key] then error(tostring(key) .. "은 읽기 전용입니다", 2) end
            rawset(t, key, value)
        end,
        __metatable = false,
    })
    states[env] = { selfValues = selfValues, worldValues = worldValues, selfApi = selfApi, worldApi = worldApi }
    return env, function(tw) tower = tw end
end

-- 틱 직전: 내부 저장소만 갱신하고 플레이어에는 동일한 읽기 전용 프록시를 계속 노출한다.
function api.refresh(env, tower, enemies, clock)
    local state = assert(states[env], "api.buildEnv로 만든 env가 아닙니다")
    local snaps = {}
    for _, e in ipairs(enemies) do
        if not e.dead and not e.reached and not e:isPhased(clock) then
            snaps[#snaps + 1] = snapshot(e, tower)
        end
    end
    table.sort(snaps, function(a, b) return a.dist < b.dist end)

    state.worldValues.enemies = function() return readonlyList(snaps, "적 목록") end
    state.worldValues.nearest = function() return snaps[1] end
    state.worldValues.weakest = function()
        local best
        for _, snap in ipairs(snaps) do if not best or snap.hp < best.hp then best = snap end end
        return best
    end
    state.worldValues.fastest = function()
        local best
        for _, snap in ipairs(snaps) do if not best or snap.speed > best.speed then best = snap end end
        return best
    end
    state.worldValues.oldest = function()
        local best
        for _, snap in ipairs(snaps) do
            if not best or snap.age > best.age or (snap.age == best.age and snap.id < best.id) then best = snap end
        end
        return best
    end

    local selfValues = state.selfValues
    selfValues.name = tower.name
    selfValues.x, selfValues.y = tower.x, tower.y
    selfValues.range, selfValues.damage = tower.def.range, tower.def.damage
    selfValues.charge, selfValues.overclock = tower.charge, tower.overclock
    selfValues.ready = tower.cd <= 0
    return state.selfApi, state.worldApi
end

return api
