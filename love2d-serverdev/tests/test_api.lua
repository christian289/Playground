return function(t)
    local api = require("src.api")
    local sandbox = require("src.sandbox")

    local expected = {
        "build", "demolish", "self:attack",
        "world.enemies", "world.nearest", "world.weakest", "world.fastest", "world.oldest",
        "cache.get", "cache.set", "on_spawn",
        "enemy.id", "enemy.type", "enemy.hp", "enemy.speed", "enemy.dist", "enemy.age",
    }
    local catalog = api.docsByName()
    for _, name in ipairs(expected) do
        t.ok(catalog[name] ~= nil, "API 카탈로그에 " .. name .. " 선언")
        t.ok(catalog[name].sig and catalog[name].lines and catalog[name].example,
            name .. " 문서 메타데이터 완전")
    end
    t.eq(catalog["cache.get"].reward, "캐시", "cache 보상 잠금 표기")
    t.eq(catalog.on_spawn.reward, "웹훅", "on_spawn 보상 잠금 표기")


    local play = require("states.play")
    local dictView = {
        dictBuiltinsOpen = false,
        dictOpen = "build",
        dictRows = { { action = "toggleBuiltins", x0 = 0, x1 = 20, y0 = 0, y1 = 20 } },
        editor = { x = 999, y = 999, w = 1, h = 1 },
        isShellStage = function() return false end,
    }
    play.mousepressed(dictView, 1, 1, 1)
    t.ok(dictView.dictBuiltinsOpen, "기본 API 접기/펼치기 행 클릭")
    t.eq(dictView.dictOpen, "build", "기본 API를 펼쳐도 열린 카드 유지")

    dictView.dictRows = { { name = "helper", x0 = 0, x1 = 20, y0 = 0, y1 = 20 } }
    play.mousepressed(dictView, 1, 1, 1)
    t.eq(dictView.dictOpen, "helper", "기본 API 17개를 펼친 상태에서도 내 함수 행 클릭")
    local calls = {}
    local battle = {
        items = { "cache", "webhook" },
        buildTower = function(_, typeId, r, c, name)
            calls.build = { typeId, r, c, name }
            return true
        end,
        demolishTower = function(_, name)
            calls.demolish = name
            return true
        end,
        say = function(_, message) calls.message = message end,
    }
    local env, setTower = api.buildEnv(battle)
    local onSpawnExample = catalog.on_spawn.example
    local compiled, err = sandbox.compile([[
        build("printer", 3, 4, "alpha")
        cache.set("seen", 1)
        ]] .. onSpawnExample .. [[
        function on_tick(self, world)
            self:attack(world.nearest())
        end
    ]], env, "api-normal")
    t.ok(compiled ~= nil, "읽기 전용 API의 정상 호출 컴파일: " .. tostring(err))
    t.eq(calls.build[4], "alpha", "build 호출 전달")
    t.eq(env.cache.get("seen"), 1, "cache 호출 전달")

    local tower = {
        name = "alpha", x = 5, y = 7, cd = 0, charge = 0, overclock = false,
        def = { range = 4, damage = 2 },
    }
    local enemy = {
        id = 9, hp = 10, max_hp = 10, x = 6, y = 7, speed = 1.5, age = 4,
        def = { id = "bug" },
        isPhased = function() return false end,
    }
    setTower(tower)
    local selfApi, world = api.refresh(env, tower, { enemy }, 0)
    local called, callErr = sandbox.call(env.on_tick, 1000, selfApi, world)
    t.ok(called, "읽기 전용 API의 정상 호출 실행: " .. tostring(callErr))
    t.eq(tower.pendingTarget, enemy.id, "self:attack 호출 전달")
    t.eq(world.nearest().id, enemy.id, "world.nearest 스냅샷 반환")
    local listEnv, listSetTower = api.buildEnv(battle)
    local listCompiled, listErr = sandbox.compile([[
        function on_tick(self, world)
            local count = 0
            for _, e in ipairs(world.enemies()) do count = count + 1 end
            cache.set("enemy_count", count)
        end
    ]], listEnv, "api-enemies-list")
    t.ok(listCompiled ~= nil, "world.enemies 목록 순회 코드 컴파일: " .. tostring(listErr))
    listSetTower(tower)
    local listSelf, listWorld = api.refresh(listEnv, tower, { enemy }, 0)
    local listOk, listCallErr = sandbox.call(listEnv.on_tick, 1000, listSelf, listWorld)
    t.ok(listOk, "world.enemies 목록을 ipairs로 순회: " .. tostring(listCallErr))
    t.eq(listEnv.cache.get("enemy_count"), 1, "world.enemies 목록의 적 수")

    local hookOk, hookErr = sandbox.call(function()
        env._spawnFn(api.plainSnapshot(enemy))
    end, 1000)
    t.ok(hookOk, "on_spawn 문서 예시 콜백 실행: " .. tostring(hookErr))


    local protected = { "build", "demolish", "self", "world", "cache", "on_spawn" }
    for _, name in ipairs(protected) do
        local assignEnv = api.buildEnv(battle)
        local result, assignErr = sandbox.compile(name .. " = nil", assignEnv, "api-protected-" .. name)
        t.ok(result == nil and tostring(assignErr):find("읽기 전용"), name .. " 전역 재대입 거부")
    end

    local memberCases = {
        "self.name = 'changed'", "world.nearest = function() end", "cache.get = function() end",
        "local e = world.nearest(); e.hp = 0", "world.enemies()[1] = nil",
    }
    for i, source in ipairs(memberCases) do
        local memberEnv, memberSetTower = api.buildEnv(battle)
        local memberCompiled, memberErr = sandbox.compile("function on_tick(self, world) " .. source .. " end", memberEnv, "api-member-" .. i)
        t.ok(memberCompiled ~= nil, "멤버 재대입 검사 코드 컴파일 " .. i .. ": " .. tostring(memberErr))
        memberSetTower(tower)
        local memberSelf, memberWorld = api.refresh(memberEnv, tower, { enemy }, 0)
        local memberOk, memberCallErr = sandbox.call(memberEnv.on_tick, 1000, memberSelf, memberWorld)
        t.ok(not memberOk and tostring(memberCallErr):find("읽기 전용"), "API 멤버 재대입 거부 " .. i)
    end

    local internalEnv, internalSetTower = api.buildEnv(battle)
    local secondTower = {
        name = "beta", x = 8, y = 9, cd = 1, charge = 2, overclock = true,
        def = { range = 6, damage = 4 },
    }
    internalSetTower(tower)
    local firstSelf = api.refresh(internalEnv, tower, { enemy }, 0)
    internalSetTower(secondTower)
    local secondSelf = api.refresh(internalEnv, secondTower, { enemy }, 0)
    t.eq(firstSelf.name, "beta", "이전에 받은 self도 현재 타워 정보를 반영")
    t.eq(secondSelf.range, 6, "게임 내부 self 멤버 갱신 허용")
end
