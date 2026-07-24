-- Wave D Task 1: 타워 표적 전략 4종(nearest/oldest/strongest/first) + autoAttack(코어)
-- 이 스위트는 셸 진영(Task 2 파서·Task 4 러너)이 스크립트 없이도 싸울 수 있도록 battle
-- 코어에 추가된 Battle:setTargetStrategy / Battle:selectTarget / opts.autoAttack만 다룬다.
-- Task 2가 이 파일에 셸 파서 절을 이어붙일 예정이라 전략/autoAttack 부분만 담당한다.
return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local Enemy = require("src.enemy")
    local d = db.load(PROJECT_ROOT)

    -- 공용: 스테이지1(001.txt) 타워 (11,3)의 실제 픽셀 좌표 — grid.toXY((c-1)*32, (r-1)*32)+16
    -- printer.range=120이므로 range^2=14400. 아래 모든 배치는 이 반경 안에서 설계한다.
    local TW_X, TW_Y = 80, 336
    local RANGE2 = 120 * 120

    ------------------------------------------------------------------
    -- ① 고정 배치(적 3기: 가까운 신입/오래된 원거리/고HP 원거리) — nearest/oldest/strongest가
    --    각각 다른 적을 고른다(전략 간 표적이 실제로 갈리는 배치 — 헛단언 방지).
    ------------------------------------------------------------------
    local b1 = Battle(d, 1, {})
    b1:start()
    t.ok(b1:buildTower("printer", 11, 3, "p1"), "①: 프린터 건설")
    local tw1 = b1.towersByName["p1"]
    t.eq(tw1.x, TW_X, "①: 타워 x 좌표 가정 확인")
    t.eq(tw1.y, TW_Y, "①: 타워 y 좌표 가정 확인")

    local bugDef = d.enemies["bug"]
    local nearFresh = Enemy(bugDef, 11, 4)   -- r,c는 이 서브테스트에서 사용 안 함(더미)
    nearFresh.id, nearFresh.spawnedAt = 301, 0
    nearFresh.x, nearFresh.y = TW_X + 10, TW_Y          -- dist2=100(가장 가까움)
    nearFresh:updateStats(0)                             -- age=0(가장 어림)

    local oldFar = Enemy(bugDef, 11, 4)
    oldFar.id, oldFar.spawnedAt = 302, -50
    oldFar.x, oldFar.y = TW_X + 110, TW_Y                -- dist2=12100(<14400, 사거리 안)
    oldFar:updateStats(0)                                -- age=50(가장 늙음)

    local hpFar = Enemy(bugDef, 11, 4)
    hpFar.id, hpFar.spawnedAt = 303, -10
    hpFar.x, hpFar.y = TW_X, TW_Y - 115                  -- dist2=13225(<14400, 사거리 안)
    hpFar:updateStats(0)                                 -- age=10(중간)
    hpFar.hp, hpFar.max_hp = 200, 200                    -- 가장 강함

    -- 게이트 자가검증: 세 축(거리/age/hp)이 실제로 서로 다르고, 셋 다 사거리 안임을 값으로 확인
    local dNear = (nearFresh.x - TW_X) ^ 2 + (nearFresh.y - TW_Y) ^ 2
    local dOld = (oldFar.x - TW_X) ^ 2 + (oldFar.y - TW_Y) ^ 2
    local dHp = (hpFar.x - TW_X) ^ 2 + (hpFar.y - TW_Y) ^ 2
    t.ok(dNear < dOld and dNear < dHp, "①게이트: nearFresh가 실제로 가장 가까움(dist2 비교)")
    t.ok(oldFar.age > nearFresh.age and oldFar.age > hpFar.age, "①게이트: oldFar가 실제로 가장 나이 많음(age 비교)")
    t.ok(hpFar.hp > nearFresh.hp and hpFar.hp > oldFar.hp, "①게이트: hpFar가 실제로 hp 최대(hp 비교)")
    t.ok(dNear <= RANGE2 and dOld <= RANGE2 and dHp <= RANGE2, "①게이트: 셋 다 사거리 안(dist2<=RANGE2)")

    b1.enemies = { hpFar, nearFresh, oldFar }  -- 배열 순서를 일부러 섞어 스폰순/순회순 의존이 아님을 확인

    tw1.strategy = "nearest"
    local pickNearest = b1:selectTarget(tw1)
    t.eq(pickNearest.id, nearFresh.id, "①: nearest는 거리 최소(nearFresh) 선택")

    tw1.strategy = "oldest"
    local pickOldest = b1:selectTarget(tw1)
    t.eq(pickOldest.id, oldFar.id, "①: oldest는 age 최대(oldFar) 선택")

    tw1.strategy = "strongest"
    local pickStrongest = b1:selectTarget(tw1)
    t.eq(pickStrongest.id, hpFar.id, "①: strongest는 hp 최대(hpFar) 선택")

    t.ok(pickNearest.id ~= pickOldest.id and pickOldest.id ~= pickStrongest.id and pickNearest.id ~= pickStrongest.id,
        "①: 세 전략이 실제로 서로 다른 표적을 고름(전략 간 차이 확인)")

    ------------------------------------------------------------------
    -- ①-2 first: 서버라인 잔여 거리(grid.dist) 최소를 고른다. r,c(그리드 칸)와 x,y(사거리
    --    판정)를 분리 제어해 "first"만 순수하게 관측한다. 001.txt 플로우필드 실측값을 먼저
    --    자가검증(row10,col4=6 / row2,col3=19 — BFS 재계산이 아니라 실제 grid.dist를 읽음)한다.
    ------------------------------------------------------------------
    local b1f = Battle(d, 1, {})
    b1f:start()
    t.ok(b1f:buildTower("printer", 11, 3, "pf"), "①-2: 프린터 건설")
    local twf = b1f.towersByName["pf"]

    t.eq(b1f.grid.dist[10][4], 6, "①-2게이트: (10,4) 실측 잔여거리=6(001.txt 플로우필드)")
    t.eq(b1f.grid.dist[2][3], 19, "①-2게이트: (2,3) 실측 잔여거리=19(001.txt 플로우필드)")
    t.ok(b1f.grid.dist[10][4] < b1f.grid.dist[2][3], "①-2게이트: (10,4)가 (2,3)보다 진행도 높음(잔여거리 작음)")

    local leadEnemy = Enemy(bugDef, 10, 4)     -- 실제 그리드 칸(10,4), 잔여거리 6
    leadEnemy.id, leadEnemy.spawnedAt = 311, 0
    leadEnemy.x, leadEnemy.y = twf.x + 5, twf.y   -- 사거리 안(사실상 거리0)

    local trailEnemy = Enemy(bugDef, 2, 3)     -- 실제 그리드 칸(2,3), 잔여거리 19
    trailEnemy.id, trailEnemy.spawnedAt = 312, 0
    trailEnemy.x, trailEnemy.y = twf.x + 6, twf.y  -- 마찬가지로 사거리 안(거리로는 leadEnemy와 거의 동일)

    b1f.enemies = { trailEnemy, leadEnemy }
    twf.strategy = "first"
    local pickFirst = b1f:selectTarget(twf)
    t.eq(pickFirst.id, leadEnemy.id, "①-2: first는 서버라인 잔여거리 최소(leadEnemy, dist=6) 선택")

    ------------------------------------------------------------------
    -- ② 동률 시 먼저 스폰된 적(낮은 id) 선택 — nearest 동률과 first 동률 두 축에서 확인
    ------------------------------------------------------------------
    -- ②-a nearest 동률: 거리 완전히 동일, id만 다름
    local b2 = Battle(d, 1, {})
    b2:start()
    t.ok(b2:buildTower("printer", 11, 3, "p2"), "②-a: 프린터 건설")
    local tw2 = b2.towersByName["p2"]
    local tieLate = Enemy(bugDef, 11, 4)
    tieLate.id, tieLate.spawnedAt = 402, 0
    tieLate.x, tieLate.y = TW_X + 50, TW_Y
    local tieEarly = Enemy(bugDef, 11, 4)
    tieEarly.id, tieEarly.spawnedAt = 401, 0
    tieEarly.x, tieEarly.y = TW_X + 50, TW_Y   -- tieLate와 완전히 동일한 좌표(거리 동률)
    t.eq(tieEarly.x, tieLate.x, "②-a게이트: 두 적의 거리(x좌표)가 실제로 동률")
    t.ok(tieEarly.id < tieLate.id, "②-a게이트: tieEarly가 먼저 스폰됨(낮은 id)")
    b2.enemies = { tieLate, tieEarly }   -- 배열 순서는 나중 스폰(tieLate)이 먼저 오도록 섞음
    tw2.strategy = "nearest"
    local pickTieNearest = b2:selectTarget(tw2)
    t.eq(pickTieNearest.id, tieEarly.id, "②-a: nearest 동률 시 먼저 스폰된(낮은 id) 적 선택")

    -- ②-b first 동률: 001.txt에서 (6,3)과 (6,7) 모두 잔여거리 13(실측 자가검증)
    local b2f = Battle(d, 1, {})
    b2f:start()
    t.ok(b2f:buildTower("printer", 11, 3, "p2f"), "②-b: 프린터 건설")
    local tw2f = b2f.towersByName["p2f"]
    t.eq(b2f.grid.dist[6][3], 13, "②-b게이트: (6,3) 실측 잔여거리=13")
    t.eq(b2f.grid.dist[6][7], 13, "②-b게이트: (6,7) 실측 잔여거리=13(동률)")

    local tieFirstLate = Enemy(bugDef, 6, 7)
    tieFirstLate.id, tieFirstLate.spawnedAt = 412, 0
    tieFirstLate.x, tieFirstLate.y = tw2f.x + 20, tw2f.y
    local tieFirstEarly = Enemy(bugDef, 6, 3)
    tieFirstEarly.id, tieFirstEarly.spawnedAt = 411, 0
    tieFirstEarly.x, tieFirstEarly.y = tw2f.x + 21, tw2f.y
    t.ok(tieFirstEarly.id < tieFirstLate.id, "②-b게이트: tieFirstEarly가 먼저 스폰됨(낮은 id)")
    b2f.enemies = { tieFirstLate, tieFirstEarly }
    tw2f.strategy = "first"
    local pickTieFirst = b2f:selectTarget(tw2f)
    t.eq(pickTieFirst.id, tieFirstEarly.id, "②-b: first 동률(잔여거리 13) 시 먼저 스폰된(낮은 id) 적 선택")

    ------------------------------------------------------------------
    -- ③ 은신(phase) 적은 어느 전략에서도 선택되지 않는다 — 은신 적이 거리/age/hp/잔여거리
    --    "전부"에서 압도적으로 유리하도록 배치해, 제외되지 않았다면 반드시 이겼을 상황에서도
    --    실제로 배제되고 대조군(control)이 선택되는지 확인한다.
    ------------------------------------------------------------------
    local b3 = Battle(d, 1, {})
    b3:start()
    t.ok(b3:buildTower("printer", 11, 3, "p3"), "③: 프린터 건설")
    local tw3 = b3.towersByName["p3"]
    b3.clock = 4.0   -- heisenbug: spawnedAt=-10 → age14 → 14%5=4>=3 → 은신 중

    local heisenDef = d.enemies["heisenbug"]
    local phased = Enemy(heisenDef, 16, 2)      -- 잔여거리 0(최소) — first에서도 압도적으로 유리
    phased.id, phased.spawnedAt = 501, -10
    phased.x, phased.y = TW_X + 5, TW_Y          -- dist2=25(가장 가까움)
    phased:updateStats(b3.clock)                 -- age=14

    local control = Enemy(bugDef, 11, 4)         -- 잔여거리 5(001.txt 실측)
    control.id, control.spawnedAt = 502, 0
    control.x, control.y = TW_X + 100, TW_Y       -- dist2=10000(phased보다 멀지만 사거리 안<14400)
    control:updateStats(b3.clock)                 -- age=4

    t.ok(phased:isPhased(b3.clock), "③게이트: phased가 이 시각(clock4.0) 실제로 은신 중")
    t.ok(not control:isPhased(b3.clock), "③게이트: control은 은신 능력 없음(항상 가시)")
    t.ok(b3.grid.dist[16][2] < b3.grid.dist[11][4], "③게이트: phased 칸(16,2)이 control 칸(11,4)보다 잔여거리 작음")
    local dPhased = (phased.x - TW_X) ^ 2 + (phased.y - TW_Y) ^ 2
    local dControl = (control.x - TW_X) ^ 2 + (control.y - TW_Y) ^ 2
    t.ok(dPhased < dControl, "③게이트: phased가 control보다 실제로 더 가까움(제외 없으면 nearest도 이김)")
    t.ok(phased.age > control.age, "③게이트: phased가 control보다 실제로 나이 많음(제외 없으면 oldest도 이김)")
    t.ok(phased.hp > control.hp, "③게이트: phased(heisenbug hp45)가 control(bug hp30)보다 실제로 강함(제외 없으면 strongest도 이김)")

    b3.enemies = { phased, control }
    for _, strat in ipairs({ "nearest", "oldest", "strongest", "first" }) do
        tw3.strategy = strat
        local pick = b3:selectTarget(tw3)
        t.ok(pick ~= nil, ("③: %s 전략도 대조군이 선택됨(nil 아님)"):format(strat))
        if pick then
            t.eq(pick.id, control.id, ("③: %s 전략에서도 은신 적은 제외되고 control이 선택됨"):format(strat))
        end
    end

    ------------------------------------------------------------------
    -- ④ autoAttack=false(기존 Lua 스테이지, 스크립트 없음)에서는 공격이 전혀 발생하지 않는다
    --    (기존 동작 불변) — 같은 배치를 autoAttack=true로 다시 실행해 "애초에 발사가 불가능한
    --    배치"가 아니라 "false라서 진짜로 억제됨"임을 A/B로 증명한다(헛단언 방지).
    ------------------------------------------------------------------
    local function buildSingleTargetBattle(autoAttack)
        local b = Battle(d, 1, { autoAttack = autoAttack })
        b:start()
        b.timeline, b.spawned = {}, {}   -- 실제 스폰 유입 차단(순수 관측)
        assert(b:buildTower("printer", 11, 3, "p4"))
        local tw = b.towersByName["p4"]
        local e = Enemy(bugDef, 11, 4)
        e.id, e.spawnedAt = 601, 0
        e.x, e.y = tw.x + 5, tw.y   -- 항상 사거리 안(거리 사실상 0)
        b.enemies = { e }
        return b, tw, e
    end

    local bOff, twOff, eOff = buildSingleTargetBattle(false)
    t.eq(bOff.autoAttack, false, "④게이트: opts.autoAttack 미지정 시 self.autoAttack이 false로 정규화됨")
    t.eq(bOff.env, nil, "④게이트: 스크립트가 설정되지 않음(self.env nil) — 셸/무스크립트 상황 재현")
    for _ = 1, 5 do bOff:runTick() end
    t.eq(#bOff.projectiles, 0, "④: autoAttack=false·스크립트 없음 → 투사체 0(공격 안 함, 기존 동작 불변)")
    t.eq(twOff.cd, 0, "④: autoAttack=false → 쿨다운 갱신 없음(resolveAttack 호출 안 됨)")
    t.eq(eOff.hp, bugDef.hp, "④: autoAttack=false → 적 hp 무피해(공격 자체가 없었다는 근거)")

    local bOn, twOn, eOn = buildSingleTargetBattle(true)
    t.eq(bOn.autoAttack, true, "④게이트(대조군): 같은 배치, opts.autoAttack=true로 재구성")
    twOn.strategy = "nearest"
    for _ = 1, 5 do bOn:runTick() end
    t.ok(#bOn.projectiles > 0, "④대조군: 완전히 같은 배치에서도 autoAttack=true면 실제로 발사됨(false가 진짜 억제였다는 근거)")

    ------------------------------------------------------------------
    -- ④-2 slowfield(디버거) 타워는 autoAttack 모드에서도 절대 공격하지 않는다(스크립트 경로와
    --    동일한 배타 규칙 재사용 확인 — ability 분기가 autoAttack 앞단에서도 여전히 걸린다).
    ------------------------------------------------------------------
    local bDbg = Battle(d, 6, { autoAttack = true })
    bDbg:start()
    bDbg.timeline, bDbg.spawned = {}, {}
    t.ok(bDbg:buildTower("debugger", 2, 2, "dbg1"), "④-2: 디버거 건설")
    local twDbg = bDbg.towersByName["dbg1"]
    twDbg.strategy = "nearest"
    local eDbg = Enemy(bugDef, twDbg.r, twDbg.c)
    eDbg.id, eDbg.spawnedAt = 701, 0
    eDbg.x, eDbg.y = twDbg.x, twDbg.y   -- 거리0(항상 사거리 안)
    bDbg.enemies = { eDbg }
    for _ = 1, 5 do bDbg:runTick() end
    t.eq(#bDbg.projectiles, 0, "④-2: slowfield(디버거)는 autoAttack=true여도 발사하지 않음")
    t.eq(twDbg.cd, 0, "④-2: slowfield 타워는 autoAttack에서도 resolveAttack 자체가 호출 안 됨(cd 무갱신)")

    ------------------------------------------------------------------
    -- ⑤ setTargetStrategy: 없는 타워 → false+한글 로그, 잘못된 전략명 → false+한글 로그
    --    (기존 상태는 변경되지 않음까지 값으로 확인), 정상 케이스 → true+반영, 기본값 확인
    ------------------------------------------------------------------
    local b5 = Battle(d, 1, {})
    b5:start()
    t.ok(b5:buildTower("printer", 11, 3, "p5"), "⑤: 프린터 건설")
    local tw5 = b5.towersByName["p5"]
    t.eq(tw5.strategy, "nearest", "⑤: 새로 지은 타워의 기본 전략은 nearest")

    local okMissing = b5:setTargetStrategy("없는이름", "nearest")
    t.eq(okMissing, false, "⑤: 존재하지 않는 타워 이름 → false")
    t.eq(b5.log[#b5.log], '[오류] 타워가 없습니다 — "없는이름"',
        "⑤: 타워 없음 한글 오류 로그 정확히 일치")

    local strategyBefore = tw5.strategy
    local okBadStrat = b5:setTargetStrategy("p5", "fastest")
    t.eq(okBadStrat, false, "⑤: 정의되지 않은 전략명 → false")
    t.eq(b5.log[#b5.log], '[오류] 알 수 없는 전략 — "fastest" (nearest/oldest/strongest/first)',
        "⑤: 알 수 없는 전략 한글 오류 로그 정확히 일치")
    t.eq(tw5.strategy, strategyBefore, "⑤: 실패 시 기존 tw.strategy가 그대로 유지됨(부작용 없음)")

    local okGood = b5:setTargetStrategy("p5", "oldest")
    t.eq(okGood, true, "⑤: 유효한 타워+전략명 → true")
    t.eq(tw5.strategy, "oldest", "⑤: 성공 시 tw.strategy가 실제로 갱신됨")
end
