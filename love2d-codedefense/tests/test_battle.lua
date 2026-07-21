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

    -- 전 스테이지 정답 코드 회귀: 4타워 표준 배치로 클리어 가능해야 한다
    for stageId = 1, 8 do
        local s = d.stages[stageId]
        local sol = readSolution(stageId)
        local g = require("src.grid").load(PROJECT_ROOT .. "/data/" .. s.maze_file)
        local spots = {}
        for r = 1, 16 do
            for c = 1, 12 do
                if g.build[r][c] and #spots < 6 then spots[#spots + 1] = { r = r, c = c } end
            end
        end
        local placements = {}
        for i = 1, math.min(4, #spots) do
            placements[i] = { r = spots[i].r, c = spots[i].c, tower = "printer", code = sol, items = { "cache", "webhook" } }
        end
        local b = Battle(d, stageId, placements)
        b:start()
        local dt = 1 / 30
        for _ = 1, math.floor(400 / dt) do
            if b.status == "prep" then b:start() end
            if b.status ~= "running" and b.status ~= "prep" then break end
            b:update(dt)
        end
        t.eq(b.status, "clear", ("스테이지 %d 정답 클리어"):format(stageId))
    end
end
