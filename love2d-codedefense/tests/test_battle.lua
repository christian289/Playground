return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local d = db.load(PROJECT_ROOT)

    local function readSolution(stageId)
        local s = d.stages[stageId]
        local f = assert(io.open(PROJECT_ROOT .. "/data/" .. s.solution_file, "rb"))
        local code = f:read("*a"); f:close()
        return code
    end

    local function run(placements, code, seconds)
        local b = Battle(d, 1, placements)
        b:start()
        local dt = 1 / 60
        for _ = 1, math.floor(seconds / dt) do
            if b.status == "prep" then b:start() end     -- 준비 단계 자동 재개
            if b.status == "clear" or b.status == "defeat" then break end
            b:update(dt)
        end
        return b
    end

    -- 타워 없이 방치 → 서버 HP 깎여 패배
    local b0 = run({}, nil, 300)
    t.eq(b0.status, "defeat", "무방비 시 패배")

    -- 정답 코드 배치 → 클리어
    local code = readSolution(1)
    local placements = {
        { r = 3, c = 3, tower = "printer", code = code, items = {} },
        { r = 3, c = 10, tower = "printer", code = code, items = {} },
        { r = 7, c = 3, tower = "printer", code = code, items = {} },
        { r = 7, c = 10, tower = "printer", code = code, items = {} },
    }
    local b1 = run(placements, code, 400)
    t.eq(b1.status, "clear", "스테이지1 정답 코드 클리어")
    t.ok(b1.serverHP > 0, "클리어 시 서버 생존")

    -- 오류 코드 → 타워 크래시 후 워치독 복구, 전투는 계속
    local crashCode = "function on_tick(self, world)\n  local x = nil\n  return x.y\nend"
    local b2 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = crashCode, items = {} } })
    b2:start()
    for _ = 1, 60 do b2:update(1 / 60) end
    t.ok(b2.towers[1].crashed > 0, "런타임 오류로 크래시 상태")
    for _ = 1, 240 do b2:update(1 / 60) end
    t.ok(b2.towers[1].crashed == 0, "워치독 3초 후 복구")

    -- 무한 루프 코드 → 타임아웃 (크래시 취급), 게임은 멈추지 않음
    local loopCode = "function on_tick(self, world)\n  while true do end\nend"
    local b3 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = loopCode, items = {} } })
    b3:start()
    for _ = 1, 30 do b3:update(1 / 60) end
    t.ok(b3.towers[1].crashed > 0, "무한 루프 타임아웃 크래시")

    -- 테크 의존성: compiler 없이 sniper 배치 시도 → 오류
    local ok = pcall(Battle, d, 1, { { r = 3, c = 3, tower = "sniper", code = code, items = {} } })
    t.ok(not ok, "requires 미충족 배치는 오류")

    -- 아이템 해금: cache 장착 시에만 env에 cache 존재
    local cacheCode = "function on_tick(self, world)\n  cache.set('n', (cache.get('n') or 0) + 1)\nend"
    local b4 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = cacheCode, items = { "cache" } } })
    b4:start()
    for _ = 1, 30 do b4:update(1 / 60) end
    t.eq(b4.towers[1].crashed, 0, "cache 장착 시 사용 가능")
    local b5 = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = cacheCode, items = {} } })
    b5:start()
    for _ = 1, 30 do b5:update(1 / 60) end
    t.ok(b5.towers[1].crashed > 0, "cache 미장착 시 크래시")

    -- 전 스테이지 정답 코드 회귀: 실제 예산 제약(printer 수 = floor(budget/100), 아이템 없음)
    -- 아래 배치는 예산 제약 하에 클리어 가능한 것으로 브루트포스로 확인한 좌표다.
    -- (배치 탐색 하네스: 8개 건설칸의 모든 k개 조합을 정답 코드로 시뮬레이션)
    local PLACEMENTS = {   -- 예산 제약 검증 배치 (브루트포스로 확인)
        [1] = { { 3, 10 }, { 11, 3 } },              -- budget 200 → 2기, 서버HP 10 잔존
        [2] = { { 3, 3 }, { 7, 3 } },                -- budget 200 → 2기, 서버HP 10 잔존
        [3] = { { 3, 3 }, { 7, 3 } },                -- budget 220 → 2기, 서버HP 10 잔존
        [4] = { { 7, 3 }, { 11, 3 } },               -- budget 220 → 2기, 서버HP 10 잔존
        [5] = { { 3, 3 }, { 7, 3 } },                -- budget 240 → 2기, 서버HP 10 잔존
        [6] = { { 3, 3 }, { 7, 3 } },                -- budget 260 → 2기, 서버HP 10 잔존
        [7] = { { 7, 10 }, { 15, 3 } },              -- budget 280 → 2기, 서버HP 8 잔존
        [8] = { { 3, 3 }, { 7, 3 }, { 11, 3 } },     -- budget 300 → 3기, 서버HP 10 잔존
    }
    for stageId = 1, 8 do
        local s = d.stages[stageId]
        local sol = readSolution(stageId)
        local expected = math.floor(s.budget / 100)
        local coords = PLACEMENTS[stageId]
        t.eq(#coords, expected, ("스테이지 %d 예산 내 타워 수(%d)"):format(stageId, expected))
        local placements = {}
        for i, rc in ipairs(coords) do
            placements[i] = { r = rc[1], c = rc[2], tower = "printer", code = sol, items = {} }
        end
        local b = Battle(d, stageId, placements)
        b:start()
        local dt = 1 / 30
        for _ = 1, math.floor(400 / dt) do
            if b.status == "prep" then b:start() end
            if b.status ~= "running" and b.status ~= "prep" then break end
            b:update(dt)
        end
        t.eq(b.status, "clear", ("스테이지 %d 예산 제약 배치로 클리어"):format(stageId))
    end

    -- Fix1: 일시정지 재개 시 recompileTowers로 수정 코드가 실제 반영되어야 한다
    do
        local noop = "function on_tick(self, world) end"
        local atk = "function on_tick(self, world)\n  self:attack(world.nearest())\nend"
        local rb = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = noop, items = {} } })
        rb:start()
        for _ = 1, 9 * 60 do rb:update(1 / 60) end   -- 적 등장(5초~) 후에도 무동작 코드는 발사 없음
        t.eq(#rb.projectiles, 0, "재컴파일 전(무동작 코드) 발사 없음")
        t.ok(#rb.enemies > 0, "재컴파일 시점에 적 생존")
        rb:recompileTowers(atk)
        t.eq(rb.towers[1].lastError, nil, "재컴파일 성공 시 오류 없음")
        local fired = false
        for _ = 1, 5 * 60 do
            rb:update(1 / 60)
            if #rb.projectiles > 0 then fired = true; break end
        end
        t.ok(fired, "재컴파일 후 실제 발사 발생")
    end

    -- Fix3: webhook on_spawn — 적 등장 즉시 반응 사격(핸들러 첫 인자가 등장한 적)
    do
        local whCode = "on_spawn(function(e, self) self:attack(e) end)"
        local wb = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = whCode, items = { "webhook" } } })
        wb:start()
        t.eq(wb.towers[1].crashed, 0, "webhook 장착 시 on_spawn 컴파일 성공")
        local fired = false
        for _ = 1, 6 * 60 do   -- 첫 스폰 5초 직후 쿨다운 없이 즉시 발사되어야 한다
            wb:update(1 / 60)
            if #wb.projectiles > 0 then fired = true; break end
        end
        t.ok(fired, "on_spawn 반응 사격 발생")
        -- 대조군: on_tick 없이 webhook도 없으면 발사 자체가 없다
        local ctrl = Battle(d, 1, { { r = 3, c = 3, tower = "printer", code = "function on_tick(self, world) end", items = {} } })
        ctrl:start()
        local ctrlFired = false
        for _ = 1, 6 * 60 do
            ctrl:update(1 / 60)
            if #ctrl.projectiles > 0 then ctrlFired = true; break end
        end
        t.ok(not ctrlFired, "on_spawn 없는 대조군은 발사 없음")
    end
end
