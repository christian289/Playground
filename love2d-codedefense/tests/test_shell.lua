-- Wave D Task 1: 타워 표적 전략 4종(nearest/oldest/strongest/first) + autoAttack(코어)
-- 이 스위트는 셸 진영(Task 2 파서·Task 4 러너)이 스크립트 없이도 싸울 수 있도록 battle
-- 코어에 추가된 Battle:setTargetStrategy / Battle:selectTarget / opts.autoAttack만 다룬다.
-- Task 2가 이 파일에 셸 파서 절을 이어붙일 예정이라 전략/autoAttack 부분만 담당한다.
return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local Enemy = require("src.enemy")
    local Shell = require("src.shell")
    local stageinfo = require("src.stageinfo")
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

    ------------------------------------------------------------------
    -- Wave D Task 2: src/shell.lua 파서·명령 9종·별칭·cron(코어)
    -- 아래부터는 Shell.new(battle)/shell:exec/shell:tick 계약을 다룬다. battle 코어는
    -- 위 Task 1 절이 이미 검증했으므로, 여기서는 "셸이 battle API를 정확히 호출하고
    -- 결과를 정확한 한글 포맷으로 되돌려주는가"에 집중한다. 브리프 지시(헛단언 4회
    -- 적발 이력)에 따라 build/rm/target/cron은 battle의 실제 상태(타워 수·money·
    -- strategy·cronJobs·nextAt)를 값으로 단언한다.
    ------------------------------------------------------------------

    ------------------------------------------------------------------
    -- ① 토크나이저: 따옴표 인자 분리 + 다중 공백 처리. tokenize()는 shell.lua의 비공개
    --    함수라 공개 계약(exec)을 통해서만 검증한다 — 파싱 결과가 실제 battle 상태
    --    변화(타워 생성·비용)와 cron 등록 필드(job.line)로 실측된다.
    ------------------------------------------------------------------
    local b1s = Battle(d, 1, {})
    b1s:start()
    local shell1 = Shell.new(b1s)

    -- 다중 공백: "ls    enemies"가 "ls enemies"와 동일하게 파싱되어야 한다(다르게
    -- 잘리면 usage 오류나 다른 출력이 나온다 — 실제 출력으로 비교)
    local resSpace = shell1:exec("ls    enemies")
    t.eq(resSpace.ok, true, "①: 다중 공백 토큰화 성공(ls enemies로 정확히 인식)")
    t.eq(resSpace.output[1], "필드에 적이 없습니다", "①: 다중 공백 처리 후 ls enemies 정상 출력(빈 목록)")

    -- 앞뒤 공백 + 다중 공백이 섞인 명령도 정확히 5토큰(build/printer/3/10/a)으로
    -- 잘려야 한다 — 실제 타워 생성·비용 차감으로 실측(헛단언 방지)
    local moneyBeforeTok = b1s.money
    local resPad = shell1:exec("   build   printer   3   10   a   ")
    t.eq(resPad.ok, true, "①: 앞뒤·다중 공백이 섞인 명령도 build 성공")
    t.ok(b1s.towersByName["a"] ~= nil, "①: 공백 다중 처리 후 실제로 타워 생성됨(실측)")
    t.eq(b1s.money, moneyBeforeTok - d.towers["printer"].cost,
        "①: 정확히 5토큰으로 분리되어 비용이 정확히 차감됨(실측)")

    -- 따옴표 인자: cron의 두 번째 인자(명령 전체)가 공백을 포함해도 한 토큰으로
    -- 유지되어야 한다 — job.line이 "target a nearest"와 정확히 일치함을 실측
    local resCronTok = shell1:exec('cron 2 "target a nearest"')
    t.eq(resCronTok.ok, true, "①: 따옴표 인자를 포함한 cron 등록 성공")
    t.eq(#shell1.cronJobs, 1, "①: cron 작업 1건 등록(실측)")
    t.eq(shell1.cronJobs[1].line, "target a nearest",
        "①: 따옴표 안 공백이 보존된 채 한 토큰으로 캡처됨(토크나이저 핵심 증거)")

    ------------------------------------------------------------------
    -- ② build: 성공 시 battle 상태(타워 생성·비용 차감) 실측 + 기존 한글 설치 로그
    --    재사용, 인자 부족 시 usage 출력(오류 시 상태 불변까지 실측)
    ------------------------------------------------------------------
    local b2s = Battle(d, 1, {})
    b2s:start()
    local shell2 = Shell.new(b2s)
    local moneyBefore2 = b2s.money
    local resBuild = shell2:exec("build printer 3 10 a")
    t.eq(resBuild.ok, true, "②: build 성공")
    t.ok(b2s.towersByName["a"] ~= nil, "②: 실제로 battle에 타워 생성됨(실측)")
    t.eq(#b2s.towers, 1, "②: 타워 수 1(실측)")
    t.eq(b2s.money, moneyBefore2 - d.towers["printer"].cost, "②: 비용(printer cost) 정확히 차감(실측)")
    t.eq(resBuild.output[1], b2s.log[#b2s.log], "②: build 성공 출력이 battle의 기존 설치 로그를 그대로 재사용")
    t.eq(resBuild.output[1], ("[설치] %s → \"%s\" (%d,%d)"):format(d.towers["printer"].name, "a", 3, 10),
        "②: 설치 로그 형식이 기존 buildTower 포맷과 정확히 일치")

    local resBuildUsage = shell2:exec("build printer 3 10")
    t.eq(resBuildUsage.ok, false, "②: 인자 부족(3개) → 실패")
    t.eq(resBuildUsage.output[1], "usage: build <타워> <행> <열> <이름>", "②: usage 문구 정확 일치")
    t.eq(#b2s.towers, 1, "②: usage 오류 시 타워 수 불변(실측 — buildTower가 호출되지 않았음)")
    t.eq(b2s.money, moneyBefore2 - d.towers["printer"].cost, "②: usage 오류 시 잔액도 불변(실측)")

    ------------------------------------------------------------------
    -- ③ rm: 철거+환불(Wave A demolish 경로) 실측, 미존재 타워 → 기존 한글 오류 재사용
    ------------------------------------------------------------------
    local b3s = Battle(d, 1, {})
    b3s:start()
    local shell3 = Shell.new(b3s)
    t.ok(b3s:buildTower("printer", 3, 10, "x"), "③: 철거 대상 사전 건설")
    local moneyAfterBuild3 = b3s.money
    local resRm = shell3:exec("rm x")
    t.eq(resRm.ok, true, "③: rm 성공")
    t.eq(b3s.towersByName["x"], nil, "③: 실제로 타워 제거됨(실측)")
    t.eq(#b3s.towers, 0, "③: 타워 수 0(실측)")
    t.eq(b3s.money, moneyAfterBuild3 + math.floor(d.towers["printer"].cost * 0.5),
        "③: 환불액(cost의 50%, 내림) 정확 반영(실측)")
    t.eq(resRm.output[1], '[철거] 프린터 → "x" · +50 환불', "③: rm 출력이 기존 철거 로그(Wave A demolish) 그대로")

    local resRmMissing = shell3:exec("rm 없는이름")
    t.eq(resRmMissing.ok, false, "③: 존재하지 않는 타워 → 실패")
    t.eq(resRmMissing.output[1], '[오류] 철거 실패 — "없는이름" 타워가 없습니다',
        "③: 기존 한글 오류 로그 그대로 재사용")
    t.eq(#b3s.towers, 0, "③: 실패 시에도 상태 불변(실측)")

    local resRmUsage = shell3:exec("rm")
    t.eq(resRmUsage.ok, false, "③: 인자 없음 → usage 오류")
    t.eq(resRmUsage.output[1], "usage: rm <이름>", "③: rm usage 문구 정확 일치")

    ------------------------------------------------------------------
    -- ④-a ls: 빈 목록과 타워 1건 스냅샷을 문자 단위로 단언
    ------------------------------------------------------------------
    local b4a = Battle(d, 1, {})
    b4a:start()
    local shell4a = Shell.new(b4a)
    local resLsEmpty = shell4a:exec("ls")
    t.eq(resLsEmpty.ok, true, "④-a: 빈 상태 ls 성공")
    t.eq(resLsEmpty.output[1], "배치된 타워가 없습니다", "④-a: 빈 목록 문구 정확 일치")
    t.eq(#resLsEmpty.output, 1, "④-a: 빈 목록은 한 줄")

    t.ok(b4a:buildTower("printer", 11, 3, "z"), "④-a: ls 스냅샷용 타워 건설")
    local resLs = shell4a:exec("ls")
    t.eq(#resLs.output, 1, "④-a: 타워 1기 → 한 줄")
    t.eq(resLs.output[1], '"z" 프린터 (11,3) · 전략 nearest',
        "④-a: ls 타워 목록 포맷 정확 일치(이름/표시명/좌표/전략)")

    ------------------------------------------------------------------
    -- ④-b ls enemies: 스폰 순(spawnedAt 낮은 순) 정렬 + 은신 적 제외, 빈 목록 문구
    ------------------------------------------------------------------
    local b4b = Battle(d, 1, {})
    b4b:start()
    b4b.clock = 10
    local shell4b = Shell.new(b4b)
    local resEnemyEmpty = shell4b:exec("ls enemies")
    t.eq(resEnemyEmpty.output[1], "필드에 적이 없습니다", "④-b: 빈 목록 문구 정확 일치")

    local eLate = Enemy(bugDef, 9, 9)
    eLate.id, eLate.spawnedAt = 12, 2
    eLate.hp = 30
    local eEarly = Enemy(bugDef, 7, 2)
    eEarly.id, eEarly.spawnedAt = 7, 1
    eEarly.hp = 12
    local ePhased = Enemy(heisenDef, 3, 3)
    ePhased.id, ePhased.spawnedAt = 1, b4b.clock - 4   -- age4, 4%5=4>=3 → 은신 중
    ePhased.hp = 999
    t.ok(ePhased:isPhased(b4b.clock), "④-b게이트: ePhased가 이 시각 실제로 은신 중(제외 대상 검증)")
    b4b.enemies = { eLate, ePhased, eEarly }   -- 배열 순서를 스폰 순과 다르게 섞음

    local resEnemies = shell4b:exec("ls enemies")
    t.eq(#resEnemies.output, 2, "④-b: 은신 적 1기 제외되어 정확히 2줄(실측)")
    t.eq(resEnemies.output[1], ("%s HP %d (%d,%d)"):format(bugDef.name, eEarly.hp, eEarly.r, eEarly.c),
        "④-b: 스폰 순 첫 줄이 먼저 스폰된(spawnedAt 낮은) eEarly")
    t.eq(resEnemies.output[2], ("%s HP %d (%d,%d)"):format(bugDef.name, eLate.hp, eLate.r, eLate.c),
        "④-b: 둘째 줄이 나중 스폰된 eLate")

    ------------------------------------------------------------------
    -- ④-c top: 서버 HP·잔액·처치/총량 한 줄 요약(실제 처치로 kills가 증가하는 것까지
    --    실측 — 초기값만 확인하는 헛단언 방지), opts.speed 유무에 따른 배속 표기
    ------------------------------------------------------------------
    local b4c = Battle(d, 1, {})
    b4c:start()
    t.eq(b4c.kills, 0, "④-c게이트: 신규 kills 카운터 초기값 0")
    local moneyBefore4c = b4c.money
    local eKillTop = Enemy(bugDef, 11, 4)
    eKillTop.id, eKillTop.spawnedAt = 950, 0
    eKillTop.hp = 0   -- 이미 치명타를 입은 상태 — 공격 시뮬레이션 없이 update()의 정리
                      -- 루프만으로 kills 증가를 검증(신규 카운터 자체를 순수하게 실측)
    b4c.enemies = { eKillTop }
    b4c:update(1 / 30)
    t.eq(b4c.kills, 1, "④-c: 적 처치 시 battle.kills가 실제로 1 증가(실측 — 신규 카운터)")
    t.eq(b4c.money, moneyBefore4c + (bugDef.reward or 0), "④-c: 처치 보상이 money에 실제 반영(실측)")

    local shell4c = Shell.new(b4c)
    local expectedTotal4c = stageinfo.totals(d.timeline(1)).total
    local expectedTopLine = ("서버 HP %d · 잔액 $%d · 처치 %d/%d")
        :format(b4c.serverHP, b4c.money, b4c.kills, expectedTotal4c)
    local resTop = shell4c:exec("top")
    t.eq(#resTop.output, 1, "④-c: top은 한 줄 출력")
    t.eq(resTop.output[1], expectedTopLine, "④-c: top 포맷이 실측값(HP/잔액/처치/총량) 기준으로 정확 일치")

    local resTopSpeed = shell4c:exec("top", { speed = 2 })
    t.eq(resTopSpeed.output[1], expectedTopLine .. " · 배속 x2", "④-c: opts.speed 지정 시 배속 접미 추가")

    local resTopNoSpeed = shell4c:exec("top", {})
    t.eq(resTopNoSpeed.output[1], expectedTopLine, "④-c: opts 없음/opts.speed 미지정 시 배속 부분 생략")

    ------------------------------------------------------------------
    -- ④-d history: 번호 매김 포맷("N  명령") — history 자기 자신의 실행도 이력에 포함
    ------------------------------------------------------------------
    local b4d = Battle(d, 1, {})
    b4d:start()
    local shell4d = Shell.new(b4d)
    shell4d:exec("ls")
    shell4d:exec("top")
    local resHist = shell4d:exec("history")
    t.eq(#resHist.output, 3, "④-d: 이력 3건(ls/top/history 자신 포함) 정확 일치(실측)")
    t.eq(resHist.output[1], "1  ls", "④-d: 1번째 항목 번호매김 정확")
    t.eq(resHist.output[2], "2  top", "④-d: 2번째 항목 번호매김 정확")
    t.eq(resHist.output[3], "3  history", "④-d: history 자신도 이력에 포함되어 3번째로 기록(실측)")

    ------------------------------------------------------------------
    -- ④-e clear: 신호 필드 { clear = true } 반환(뷰가 소비 — 여기선 신호만 검증)
    ------------------------------------------------------------------
    local b4e2 = Battle(d, 1, {})
    b4e2:start()
    local shell4e = Shell.new(b4e2)
    local resClear = shell4e:exec("clear")
    t.eq(resClear.ok, true, "④-e: clear 성공")
    t.eq(resClear.clear, true, "④-e: clear 신호 필드 true(뷰 소비용)")
    t.eq(#resClear.output, 0, "④-e: clear는 출력 없음")

    ------------------------------------------------------------------
    -- ⑤ target: 전략 지정이 실제 tw.strategy에 반영되는지 실측(헛단언 방지),
    --    오류 전파(battle.log 재사용) + 실패 시 상태 불변까지 실측
    ------------------------------------------------------------------
    local b5s = Battle(d, 1, {})
    b5s:start()
    local shell5 = Shell.new(b5s)
    t.ok(b5s:buildTower("printer", 11, 3, "t1"), "⑤: 대상 타워 건설")
    local tw5s = b5s.towersByName["t1"]
    t.eq(tw5s.strategy, "nearest", "⑤게이트: 기본 전략 nearest(변경 전 확인)")

    local resTarget = shell5:exec("target t1 oldest")
    t.eq(resTarget.ok, true, "⑤: target 성공")
    t.eq(tw5s.strategy, "oldest", "⑤: 실제 tw.strategy가 oldest로 변경됨(실측 — 헛단언 방지)")

    local resTargetMissing = shell5:exec("target 없는타워 nearest")
    t.eq(resTargetMissing.ok, false, "⑤: 존재하지 않는 타워 → 실패")
    t.eq(resTargetMissing.output[1], '[오류] 타워가 없습니다 — "없는타워"',
        "⑤: battle 로그의 오류를 output에 동일하게 전달")
    t.eq(tw5s.strategy, "oldest", "⑤: 실패 후에도 t1의 전략은 그대로(실측 — 부작용 없음)")

    local resTargetBad = shell5:exec("target t1 fastest")
    t.eq(resTargetBad.ok, false, "⑤: 정의되지 않은 전략명 → 실패")
    t.eq(resTargetBad.output[1], '[오류] 알 수 없는 전략 — "fastest" (nearest/oldest/strongest/first)',
        "⑤: 알 수 없는 전략 오류도 battle 로그 그대로 전달")
    t.eq(tw5s.strategy, "oldest", "⑤: 잘못된 전략명 실패 후에도 기존 전략 유지(실측)")

    local resTargetUsage = shell5:exec("target t1")
    t.eq(resTargetUsage.ok, false, "⑤: 인자 부족 → usage 오류")
    t.eq(resTargetUsage.output[1], "usage: target <타워> <전략>", "⑤: target usage 문구 정확 일치")
    t.eq(tw5s.strategy, "oldest", "⑤: usage 오류 시에도 전략 불변(실측)")

    ------------------------------------------------------------------
    -- ⑥ cron: 등록→tick 결정론(실행 시각열을 nextAt 값으로 직접 비교), -l/-r,
    --    간격<1 거부(등록 자체가 안 됨까지 실측 — 헛단언 방지)
    ------------------------------------------------------------------
    local b6s = Battle(d, 1, {})
    b6s:start()
    t.ok(b6s:buildTower("printer", 11, 3, "u"), "⑥: cron 대상 타워 건설")
    b6s.clock = 0   -- 등록 시각 기준선을 직접 통제(shell:tick은 이 필드를 읽지 않고 인자만 사용)
    local shell6 = Shell.new(b6s)

    local resCronReg = shell6:exec('cron 2 "target u oldest"')
    t.eq(resCronReg.ok, true, "⑥: cron 등록 성공")
    t.eq(#shell6.cronJobs, 1, "⑥: cronJobs 1건(실측)")
    local job1 = shell6.cronJobs[1]
    t.eq(job1.id, 1, "⑥: 첫 등록 id=1")
    t.eq(job1.interval, 2, "⑥: interval 2 저장")
    t.eq(job1.line, "target u oldest", "⑥: 명령 문자열 정확 보존")
    t.eq(job1.nextAt, 2, "⑥: nextAt = 등록시각(clock=0) + interval(2) = 2(결정론 산술)")
    t.eq(b6s.towersByName["u"].strategy, "nearest", "⑥: 등록 직후에는 아직 미실행(전략 불변, 실측)")

    local outNotDue = shell6:tick(1.0)
    t.eq(#outNotDue, 0, "⑥: clock 1.0 < nextAt 2 → 미실행(출력 없음)")
    t.eq(job1.nextAt, 2, "⑥: 미실행 시 nextAt 불변")
    t.eq(b6s.towersByName["u"].strategy, "nearest", "⑥: 미실행 시 전략도 불변(실측)")

    local outDue1 = shell6:tick(2.0)
    t.eq(#outDue1, 2, "⑥: 실행 시 헤더+명령 결과 2줄")
    t.eq(outDue1[1], "[cron#1] target u oldest", "⑥: cron 실행 출력 접두 [cron#id] 명령 정확 일치")
    t.eq(outDue1[2], '전략 변경 — "u" → oldest', "⑥: cron이 대신 실행한 target 결과 출력")
    t.eq(b6s.towersByName["u"].strategy, "oldest", "⑥: 실제 battle 상태(전략) 변경 확인(실측 — 헛단언 방지 핵심)")
    t.eq(job1.nextAt, 4, "⑥: 실행 후 nextAt = 이전 nextAt(2) + interval(2) = 4(드리프트 없는 산술)")

    local outNotDue2 = shell6:tick(3.9)
    t.eq(#outNotDue2, 0, "⑥: clock 3.9 < nextAt 4 → 아직 미실행")
    t.eq(job1.nextAt, 4, "⑥: 불변")

    local outDue2 = shell6:tick(4.0)
    t.eq(#outDue2, 2, "⑥: 두 번째 실행")
    t.eq(job1.nextAt, 6, "⑥: 실행 시각열 확정 — nextAt 2→4→6(등록 시각 기준 산술, 매번 동일 간격)")

    -- 캐치업(한 tick 호출에서 여러 간격을 건너뛴 경우) — id 순 실행 + 각 잡의 실행
    -- 횟수를 nextAt 진행량으로 정확히 역산해 "실행 시각열"을 값으로 검증한다.
    b6s.clock = 4.0   -- 두 번째 cron 등록 시각 기준선(위 tick 타임라인과 정합)
    local resCronReg2 = shell6:exec('cron 1 "top"')
    t.eq(resCronReg2.ok, true, "⑥: 두 번째 cron(top) 등록 성공")
    local job2 = shell6.cronJobs[2]
    t.eq(job2.id, 2, "⑥: 두 번째 등록 id=2(재사용 없이 순증)")
    t.eq(job2.nextAt, 5.0, "⑥: nextAt = 등록시각(4.0) + interval(1) = 5.0")

    local outCatchup = shell6:tick(8.0)
    t.eq(job1.nextAt, 10, "⑥: job1(간격2) 캐치업 — 6→8→10, 즉 2회 실행")
    t.eq(job2.nextAt, 9, "⑥: job2(간격1) 캐치업 — 5→6→7→8→9, 즉 4회 실행")
    t.eq(outCatchup[1], "[cron#1] target u oldest", "⑥: id 순 실행 — job1(id1)이 job2(id2)보다 먼저 처리됨")
    local cnt1, cnt2 = 0, 0
    for _, l in ipairs(outCatchup) do
        if l == "[cron#1] target u oldest" then cnt1 = cnt1 + 1 end
        if l == "[cron#2] top" then cnt2 = cnt2 + 1 end
    end
    t.eq(cnt1, 2, "⑥: job1 헤더가 정확히 2회 등장(nextAt 진행량과 일치)")
    t.eq(cnt2, 4, "⑥: job2 헤더가 정확히 4회 등장(nextAt 진행량과 일치)")

    local resCronList = shell6:exec("cron -l")
    t.eq(#resCronList.output, 2, "⑥: cron -l 목록 2건(실측)")
    t.eq(resCronList.output[1],
        ("cron#%d · %g초마다 · 다음 %g · \"%s\""):format(job1.id, job1.interval, job1.nextAt, job1.line),
        "⑥: cron -l이 job1의 실제(갱신된) nextAt을 정확히 반영")
    t.eq(resCronList.output[2],
        ("cron#%d · %g초마다 · 다음 %g · \"%s\""):format(job2.id, job2.interval, job2.nextAt, job2.line),
        "⑥: cron -l이 job2의 실제(갱신된) nextAt을 정확히 반영")

    local resCronRm = shell6:exec("cron -r 1")
    t.eq(resCronRm.ok, true, "⑥: cron -r 1 삭제 성공")
    t.eq(resCronRm.output[1], "cron#1 삭제됨", "⑥: 삭제 확인 문구")
    t.eq(#shell6.cronJobs, 1, "⑥: 삭제 후 1건만 남음(실측)")
    t.eq(shell6.cronJobs[1].id, 2, "⑥: 남은 작업은 job2(id=2)(실측)")

    local resCronRmAgain = shell6:exec("cron -r 1")
    t.eq(resCronRmAgain.ok, false, "⑥: 이미 삭제된 id 재삭제 → 실패")
    t.eq(resCronRmAgain.output[1], "[오류] cron#1 없음", "⑥: 존재하지 않는 cron id 오류 문구")
    t.eq(#shell6.cronJobs, 1, "⑥: 재삭제 실패 시에도 상태 불변(실측)")

    local resCronTooFast = shell6:exec('cron 0.5 "ls"')
    t.eq(resCronTooFast.ok, false, "⑥: 간격 1초 미만 → 거부")
    t.eq(resCronTooFast.output[1], "[오류] 간격은 1초 이상이어야 합니다", "⑥: 간격 오류 문구 정확 일치")
    t.eq(#shell6.cronJobs, 1, "⑥: 거부된 등록은 실제로 cronJobs에 추가되지 않음(실측 — 헛단언 방지)")

    ------------------------------------------------------------------
    -- ⑦ 오타 제안: 레벤슈타인 거리 1 이내 후보 제시, 2 이상은 제안 없음(명령어에만
    --    적용). command not found 시 battle 상태 불변까지 실측
    ------------------------------------------------------------------
    local b7s = Battle(d, 1, {})
    b7s:start()
    local shell7 = Shell.new(b7s)
    local moneyBefore7 = b7s.money

    local resTypo = shell7:exec("buld printer 3 10 a")
    t.eq(resTypo.ok, false, "⑦: 오타 명령 실패")
    t.eq(resTypo.output[1], "command not found: buld — 'build'를 의미했나요?", "⑦: 거리1 오타 제안 문구 정확 일치")
    t.eq(#b7s.towers, 0, "⑦: 오타 명령은 실제로 build를 실행하지 않음(실측 — 헛단언 방지)")
    t.eq(b7s.money, moneyBefore7, "⑦: 잔액도 불변(실측)")

    -- "topxx"는 "top"과 편집 거리 정확히 2(끝에 두 글자 삽입)이고 다른 8개 명령과는
    -- 그보다 멀다 — 최근접 후보가 있어도 임계값(<=1) 밖이라 제안이 없어야 한다
    local resFar = shell7:exec("topxx")
    t.eq(resFar.ok, false, "⑦: 거리 2 이상 오타는 실패")
    t.eq(resFar.output[1], "command not found: topxx", "⑦: 거리 2 이상이면 제안 문구 없이 그대로(정확 일치)")

    local resWayFar = shell7:exec("zzzzzzzzzz")
    t.eq(resWayFar.output[1], "command not found: zzzzzzzzzz", "⑦: 전혀 무관한 입력도 제안 없이 그대로")

    ------------------------------------------------------------------
    -- ⑧ ps1 별칭: Remove-Item/dir/Get-Process/Get-Content가 원 명령과 동일 코드
    --    경로로 라우팅되는지 battle 상태로 실측 + 최초 1회 환영 메시지
    ------------------------------------------------------------------
    local b8s = Battle(d, 1, {})
    b8s:start()
    t.ok(b8s:buildTower("printer", 3, 10, "a"), "⑧: 별칭 대상 타워 사전 건설")
    local moneyAfterBuild8 = b8s.money
    local shell8 = Shell.new(b8s)

    local resAliasRm = shell8:exec("Remove-Item a")
    t.eq(resAliasRm.ok, true, "⑧: Remove-Item(별칭) → rm 성공")
    t.eq(#resAliasRm.output, 2, "⑧: 최초 별칭 사용 시 환영 문구 1줄 + rm 결과 1줄")
    t.eq(resAliasRm.output[1], "PowerShell 사용자를 환영합니다", "⑧: 최초 1회 환영 문구 정확 일치")
    t.eq(resAliasRm.output[2], '[철거] 프린터 → "a" · +50 환불', "⑧: rm과 동일한 철거 로그 재사용(동일 코드 경로 증거)")
    t.eq(b8s.towersByName["a"], nil, "⑧: 실제로 타워가 철거됨(실측 — rm과 동일 부작용)")
    t.eq(b8s.money, moneyAfterBuild8 + 50, "⑧: 환불도 rm과 동일하게 반영(실측)")

    local resAliasDir = shell8:exec("dir")
    t.eq(resAliasDir.ok, true, "⑧: dir(별칭) → ls 성공")
    t.eq(#resAliasDir.output, 1, "⑧: 이미 환영 문구를 봤으므로 이번엔 결과 1줄뿐(중복 없음)")
    t.eq(resAliasDir.output[1], "배치된 타워가 없습니다", "⑧: dir → ls와 동일 출력(타워가 이미 철거되어 빈 목록)")

    local resAliasPs = shell8:exec("Get-Process")
    t.eq(resAliasPs.ok, true, "⑧: Get-Process(별칭) → ls enemies 성공")
    t.eq(resAliasPs.output[1], "필드에 적이 없습니다", "⑧: ls enemies와 동일 출력")

    local resAliasMan = shell8:exec("Get-Content build")
    t.eq(resAliasMan.ok, true, "⑧: Get-Content build(별칭) → man build 성공")
    t.eq(resAliasMan.open, "build", "⑧: man과 동일하게 open 신호 필드에 명령 인자 전달(동일 코드 경로 증거)")

    ------------------------------------------------------------------
    -- ⑨ 출력 절단: 21줄 이상(history 22건: 21회 실행 + history 자신) → 20줄 + "…외 n건"
    ------------------------------------------------------------------
    local b9s = Battle(d, 1, {})
    b9s:start()
    local shell9 = Shell.new(b9s)
    for _ = 1, 21 do shell9:exec("ls") end
    local resHistBig = shell9:exec("history")
    t.eq(#shell9.history, 22, "⑨게이트: history 자신의 호출까지 포함해 실제로 22건 누적됨(실측)")
    t.eq(resHistBig.ok, true, "⑨: 절단되어도 ok는 true")
    t.eq(#resHistBig.output, 21, "⑨: 20줄 + 절단 안내 1줄 = 21줄(실측)")
    t.eq(resHistBig.output[20], "20  ls", "⑨: 20번째 줄까지는 정상 내용(실측)")
    t.eq(resHistBig.output[21], "…외 2건", "⑨: 22건 중 20건 초과분 2건 정확 표기")
end
