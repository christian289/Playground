-- 적 능력 grow·dash·resist + 스냅샷 age/speed + world.oldest() (Wave B Task 2)
return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local Enemy = require("src.enemy")
    local api = require("src.api")
    local Projectile = require("src.projectile")
    local d = db.load(PROJECT_ROOT)

    ------------------------------------------------------------------
    -- ① grow: 스폰 후 GROW_EVERY(1.0s)마다 maxHP/HP += GROW_AMOUNT(2), 상한(base×5) 불변
    ------------------------------------------------------------------
    local growDef = d.enemies["memory-leak"]  -- abilities="grow"
    local eg = Enemy(growDef, 1, 1)
    eg.spawnedAt = 0
    local clock = 0
    for _ = 1, 30 do          -- 0.1s 틱 누적 × 30 = 3.0s
        clock = clock + 0.1
        eg:updateStats(clock)
    end
    t.eq(eg.max_hp, growDef.hp + 6, "grow: 3초 경과 시 maxHP +6(=3×GROW_AMOUNT)")
    t.eq(eg.hp, growDef.hp + 6, "grow: 3초 경과 시 hp도 +6")

    local cap = growDef.hp * 5
    for _ = 1, math.floor(1000 / 0.1) do
        clock = clock + 0.1
        eg:updateStats(clock)
    end
    t.eq(eg.max_hp, cap, "grow: 상한(base maxHP×5) 도달")
    local capSnapshot = eg.max_hp
    clock = clock + 100
    eg:updateStats(clock)
    t.eq(eg.max_hp, capSnapshot, "grow: 상한 도달 후 추가 성장 없음(불변)")
    t.eq(eg.hp, capSnapshot, "grow: 상한 도달 후 hp도 max_hp와 일치")

    ------------------------------------------------------------------
    -- ② dash: age 0.1s(대시 창 DASH_LEN=0.3 안)에서 실효 speed=기본×3,
    --    age 0.5s(창 밖)에서 기본×1 — 틱 단위 결정론 확인
    ------------------------------------------------------------------
    local dashDef = d.enemies["race-cond"]  -- abilities="dash"
    local ed = Enemy(dashDef, 1, 1)
    ed.spawnedAt = 0
    local c2 = 0
    for _ = 1, 1 do c2 = c2 + 0.1 end   -- 0.1s 경과(대시 창 안)
    ed:updateStats(c2)
    t.eq(ed.speed, dashDef.speed * 3, "dash: 창 안(age 0.1s) 실효 speed ×3")
    for _ = 1, 4 do c2 = c2 + 0.1 end   -- 추가 0.4s → 총 age 0.5s(대시 창 밖)
    ed:updateStats(c2)
    t.eq(ed.speed, dashDef.speed, "dash: 창 밖(age 0.5s) 실효 speed 기본값")
    local c3 = 0.3   -- age 정확히 0.3s(DASH_LEN 경계, 배타적 끝)
    ed:updateStats(c3)
    t.eq(ed.speed, dashDef.speed, "dash: 경계 age 0.3s(DASH_LEN)에서 NOT 대시")

    ------------------------------------------------------------------
    -- ③ resist:printer — 프린터 데미지는 절반(floor·min1), 스나이퍼 데미지는 그대로
    ------------------------------------------------------------------
    local b = Battle(d, 6, {})   -- 스테이지6: 예산 360으로 printer+compiler+sniper 감당
    b:start()
    t.ok(b:buildTower("printer", 2, 2, "p"), "프린터 건설")
    t.ok(b:buildTower("compiler", 4, 2, "c"), "컴파일러 건설")
    t.ok(b:buildTower("sniper", 7, 2, "s"), "스나이퍼 건설")

    local legacyDef = d.enemies["legacy"]  -- abilities="resist:printer"
    local function targetFor(tw, id)
        local e = Enemy(legacyDef, tw.r, tw.c)
        e.id = id
        e.spawnedAt = b.clock
        e.x, e.y = tw.x, tw.y   -- 거리 0 → 항상 사거리 안
        return e
    end

    local twP = b.towersByName["p"]
    local eP = targetFor(twP, 9001)
    b.enemies = { eP }
    twP.pendingTarget = eP.id
    b:resolveAttack(twP)
    local dmgP = b.projectiles[#b.projectiles].damage
    t.eq(dmgP, math.max(1, math.floor(d.towers.printer.damage * 0.5)),
        "resist:printer — 프린터 데미지 절반(floor·min1)")

    local twS = b.towersByName["s"]
    local eS = targetFor(twS, 9002)
    b.enemies = { eS }
    twS.pendingTarget = eS.id
    b:resolveAttack(twS)
    local dmgS = b.projectiles[#b.projectiles].damage
    t.eq(dmgS, d.towers.sniper.damage, "resist:printer — 스나이퍼 데미지는 그대로(무관계 타워는 감쇄 없음)")

    -- resist 소수 데미지 내림(5.25→5): charge=0.1 → 10×1.05=10.5 → resist 5.25 → floor → 5
    local eFrac = targetFor(twP, 9003)
    b.enemies = { eFrac }
    twP.cd = 0   -- 쿨다운 리셋
    twP.pendingTarget = eFrac.id
    twP.charge = 0.1   -- mult = 1 + 0.1*0.5 = 1.05
    b:resolveAttack(twP)
    local dmgFrac = b.projectiles[#b.projectiles].damage
    t.eq(dmgFrac, 5, "resist 소수 데미지 내림(5.25→5)")

    -- resist 최소값 1: damage=1 → 1×0.5=0.5 → floor→0 → max(1,0)=1
    -- 합성 타워 정의로 테스트 (id="printer"로 설정해 target.abilities.resist와 매칭)
    local syntheticDef = {
        id = "printer",
        name = "Test Low Dmg",
        damage = 1,
        range = 200,
        cooldown = 1,
        bullet_speed = 100,
        color = "1;1;1"
    }
    local twSynth = {
        def = syntheticDef,
        x = 0, y = 0, r = 1, c = 1,
        charge = 0,
        cd = 0,
        pendingTarget = nil,
        dan = nil,
        effectiveCooldown = function() return 1 end
    }
    local eMin = Enemy(legacyDef, 1, 1)
    eMin.id = 9004
    eMin.spawnedAt = b.clock
    eMin.x, eMin.y = 0, 0
    b.enemies = { eMin }
    twSynth.pendingTarget = eMin.id
    b:resolveAttack(twSynth)
    local dmgMin = b.projectiles[#b.projectiles].damage
    t.eq(dmgMin, 1, "resist 최소값 1(0.5→floor→0 → max(1,0)=1)")

    ------------------------------------------------------------------
    -- ④ 스냅샷 age/speed: world.enemies()가 실제 e.age/e.speed(실효)와 일치
    ------------------------------------------------------------------
    local b2 = Battle(d, 1, {})
    t.ok(b2:buildTower("printer", 3, 10, "p"), "프린터 건설")
    local twP2 = b2.towersByName["p"]
    local eSnap = Enemy(dashDef, twP2.r, twP2.c)
    eSnap.id = 42
    eSnap.spawnedAt = 0
    eSnap.x, eSnap.y = twP2.x, twP2.y
    eSnap:updateStats(0.1)   -- 대시 창 안 → speed=기본×3, age=0.1
    b2.enemies = { eSnap }

    local env2, setTower2 = api.buildEnv(b2)
    setTower2(twP2)
    local _, world2 = api.refresh(env2, twP2, b2.enemies)
    local snaps2 = world2.enemies()
    t.eq(#snaps2, 1, "스냅샷 1개")
    t.eq(snaps2[1].age, eSnap.age, "스냅샷 age가 e.age와 일치")
    t.eq(snaps2[1].speed, eSnap.speed, "스냅샷 speed가 e.speed(실효 속도)와 일치")
    t.eq(snaps2[1].speed, dashDef.speed * 3, "스냅샷 speed에 대시 배율 반영")

    ------------------------------------------------------------------
    -- ⑤ world.oldest(): age 최대(=먼저 스폰)인 적 반환, 동률 시 더 먼저 스폰(=낮은 id),
    --    적이 없으면 nil
    ------------------------------------------------------------------
    local b3 = Battle(d, 1, {})
    t.ok(b3:buildTower("printer", 3, 10, "p"), "프린터 건설")
    local tw3 = b3.towersByName["p"]
    local env3, setTower3 = api.buildEnv(b3)
    setTower3(tw3)

    local _, world3empty = api.refresh(env3, tw3, b3.enemies)
    t.eq(world3empty.oldest(), nil, "적이 없으면 world.oldest() nil")

    local bugDef = d.enemies["bug"]
    local older = Enemy(bugDef, 1, 1); older.id = 1; older.spawnedAt = 0
    local middle = Enemy(bugDef, 1, 1); middle.id = 2; middle.spawnedAt = 1
    local newer = Enemy(bugDef, 1, 1); newer.id = 3; newer.spawnedAt = 2
    older:updateStats(5); middle:updateStats(5); newer:updateStats(5)
    b3.enemies = { newer, middle, older }   -- 순서를 뒤섞어 배열 순서 의존이 아님을 확인
    local _, world3 = api.refresh(env3, tw3, b3.enemies)
    local oldest = world3.oldest()
    t.eq(oldest.id, older.id, "world.oldest()는 가장 먼저 스폰된(age 최대) 적")

    local tieA = Enemy(bugDef, 1, 1); tieA.id = 10; tieA.spawnedAt = 3
    local tieB = Enemy(bugDef, 1, 1); tieB.id = 11; tieB.spawnedAt = 3
    tieA:updateStats(5); tieB:updateStats(5)
    b3.enemies = { tieB, tieA }
    local _, world3tie = api.refresh(env3, tw3, b3.enemies)
    local tieOldest = world3tie.oldest()
    t.eq(tieOldest.id, tieA.id, "동률 시 더 먼저 스폰된(낮은 id) 적")

    ------------------------------------------------------------------
    -- split2 오탐 회귀: fork-bomb(split2)은 split(concat-nil) 능력을 갖지 않는다
    -- (부분 문자열 검사였다면 "split2"가 "split"에 오탐됨)
    ------------------------------------------------------------------
    local forkDef = d.enemies["fork-bomb"]  -- abilities="split2"
    t.eq(forkDef.abilities, "split2", "fork-bomb abilities 원본 확인")
    local ef = Enemy(forkDef, 1, 1)
    t.eq(ef.abilities.split, nil, "split2는 split 능력으로 오탐되지 않음")
    t.ok(ef.abilities.split2, "split2 토큰 자체는 파싱됨")

    local concatDef = d.enemies["concat-nil"]  -- abilities="split"
    local ec = Enemy(concatDef, 1, 1)
    t.ok(ec.abilities.split, "concat-nil은 여전히 split 능력을 가짐(기존 동작 불변)")

    ------------------------------------------------------------------
    -- ⑥ pair: 같은 스폰 이벤트의 홀짝 인덱스로 쌍(e.pairId), 둘 다 생존 시 데미지 ×0.4
    --    (floor·min1), 한쪽 사망 즉시(실제 사망 처리 경로) 경감 해제, 홀수 마지막 1기는 쌍 없음
    ------------------------------------------------------------------
    local bp = Battle(d, 1, {})
    bp:start()
    bp.timeline = { { at = 0, spawn = "deadlock", count = 3, interval = 0, col = 4 } }
    bp.spawned = {}
    bp.clock = 0
    bp:spawnFromTimeline()
    t.eq(#bp.enemies, 3, "pair: 3기 스폰(같은 이벤트)")
    local d1, d2, d3 = bp.enemies[1], bp.enemies[2], bp.enemies[3]
    t.eq(d1.pairId, d2.id, "pair: 홀짝 인덱스 0↔1 쌍 연결(1번→2번)")
    t.eq(d2.pairId, d1.id, "pair: 홀짝 인덱스 0↔1 쌍 연결(2번→1번)")
    t.eq(d3.pairId, nil, "pair: 홀수 스폰 마지막 1기는 쌍 없음")

    t.ok(bp:buildTower("printer", 3, 3, "pp"), "pair 테스트용 프린터 건설")
    local twPair = bp.towersByName["pp"]
    d1.x, d1.y = twPair.x, twPair.y
    d2.x, d2.y = twPair.x, twPair.y
    bp.enemies = { d1, d2 }
    twPair.pendingTarget = d1.id
    bp:resolveAttack(twPair)
    local dmgPaired = bp.projectiles[#bp.projectiles].damage
    local rawDmg = twPair.def.damage   -- charge=0 → mult=1, dan 없음
    t.eq(dmgPaired, math.max(1, math.floor(rawDmg * 0.4)),
        "pair: 둘 다 생존 시 데미지 ×0.4(floor·min1) — 실제 resolveAttack 경로")

    -- 파트너(d2) 사망을 실제 사망 처리 경로(Battle:update 정리 루프)로 유발
    d2.hp = 0
    bp:update(1 / 60)
    t.ok(d2.dead, "pair: 파트너가 실제 사망 처리 경로로 dead=true")
    t.eq(d1.pairAlive, false, "pair: 파트너 사망 즉시 pairAlive=false(실 사망 처리에서 설정됨)")

    twPair.cd = 0
    twPair.pendingTarget = d1.id
    bp:resolveAttack(twPair)
    local dmgAfter = bp.projectiles[#bp.projectiles].damage
    t.eq(dmgAfter, rawDmg, "pair: 상대 사망 후 데미지 경감 해제(전체 데미지로 복귀)")

    ------------------------------------------------------------------
    -- ⑥-2 pair 해제를 도달(reached)에도 적용(최종 리뷰 반영): 짝이 서버라인 도달로
    --    제거될 때도 남은 쪽의 pairAlive가 즉시 해제된다(원 설계 "쌍이 모두 살아있으면
    --    경감" — 사망뿐 아니라 도달도 "필드에서 사라짐"이므로 동일하게 취급해야 한다).
    ------------------------------------------------------------------
    local bpr = Battle(d, 1, {})
    bpr:start()
    bpr.timeline = { { at = 0, spawn = "deadlock", count = 2, interval = 0, col = 4 } }
    bpr.spawned = {}
    bpr.clock = 0
    bpr:spawnFromTimeline()
    local r1, r2 = bpr.enemies[1], bpr.enemies[2]
    t.eq(r1.pairId, r2.id, "pair 도달 해제 게이트: r1↔r2 실제로 쌍 연결됨")
    t.eq(r1.pairAlive, true, "pair 도달 해제 게이트: 스폰 직후 r1.pairAlive=true(전제 조건 확인)")

    t.ok(bpr:buildTower("printer", 3, 3, "ppr"), "pair 도달 해제 테스트용 프린터 건설")
    local twPairR = bpr.towersByName["ppr"]
    r1.x, r1.y = twPairR.x, twPairR.y
    r2.x, r2.y = twPairR.x, twPairR.y
    twPairR.pendingTarget = r1.id
    bpr:resolveAttack(twPairR)
    local dmgBeforeReach = bpr.projectiles[#bpr.projectiles].damage
    local rawDmgR = twPairR.def.damage
    t.eq(dmgBeforeReach, math.max(1, math.floor(rawDmgR * 0.4)),
        "pair 도달 해제 게이트: 도달 전에는 여전히 ×0.4 경감 중(비교 기준값)")

    -- r2를 도달 처리(사망이 아니라 reached)로 제거 — 실제 정리 루프 경로
    r2.reached = true
    bpr:update(1 / 60)
    t.ok(r2.counted, "pair 도달 해제: r2가 실제 도달 처리 경로로 counted=true")
    t.eq(r1.pairAlive, false, "pair 도달 해제: 짝이 도달로 제거되면 남은 쪽 pairAlive 즉시 false")

    twPairR.cd = 0
    twPairR.pendingTarget = r1.id
    bpr:resolveAttack(twPairR)
    local dmgAfterReach = bpr.projectiles[#bpr.projectiles].damage
    t.eq(dmgAfterReach, rawDmgR, "pair: 짝 도달 제거 후 받는 데미지가 즉시 전액으로 복귀")

    ------------------------------------------------------------------
    -- ⑥-3 pairPending 죽은 참조 방지: 짝이 스폰되기 전에 먼저 스폰된 쪽이 이미
    --    제거(사망/도달)됐다면, 나중에 스폰되는 쪽은 죽은 참조와 연결되지 않고
    --    쌍 없이(경감 없이) 스폰돼야 한다.
    ------------------------------------------------------------------
    local bpg = Battle(d, 1, {})
    bpg:start()
    bpg.timeline = { { at = 0, spawn = "deadlock", count = 1, interval = 0, col = 4 } }
    bpg.spawned = {}
    bpg.clock = 0
    bpg:spawnFromTimeline()
    t.eq(#bpg.enemies, 1, "pairPending 가드 게이트: 첫 번째 개체만 스폰(짝 대기 중)")
    local first = bpg.enemies[1]
    t.eq(bpg.pairPending[1], first, "pairPending 가드 게이트: 짝을 기다리는 중(pairPending에 등록됨)")

    -- 짝이 스폰되기 전에 first가 도달로 제거된다(사망도 동일 경로).
    first.reached = true
    bpg:update(1 / 60)
    t.ok(first.counted, "pairPending 가드: first가 짝 스폰 전 실제로 도달 제거됨")
    t.eq(#bpg.enemies, 0, "pairPending 가드 게이트: first는 정리 루프에서 실제로 제거됨")

    -- 두 번째 개체를 같은 이벤트(i=1)로 스폰한다 — pairPending[1]은 여전히 죽은 first를
    -- 참조하고 있었지만, 가드가 이를 걸러 second는 쌍 없이 스폰돼야 한다.
    bpg.timeline[1].count = 2
    bpg:spawnFromTimeline()
    t.eq(#bpg.enemies, 1, "pairPending 가드: second가 실제로 스폰됨(먼저 스폰된 first는 이미 제거됨)")
    local second = bpg.enemies[1]
    t.eq(second.pairId, nil, "pairPending 가드: 죽은 first와 연결되지 않음(pairId nil)")
    t.eq(second.pairAlive, nil, "pairPending 가드: 경감 없이 스폰(pairAlive nil)")
    t.eq(bpg.pairPending[1], nil, "pairPending 가드: 대기 슬롯이 정리됨(죽은 참조가 남지 않음)")

    ------------------------------------------------------------------
    -- ⑦ phase: 스폰 기준 0~3s 가시 / 3~5s 은신(재출현 5s, 순수 산술·상태 저장 없음),
    --    은신 중 world.enemies()/nearest()/oldest() 제외 + 투사체 명중 무효,
    --    서버라인 도달 판정은 은신과 무관
    ------------------------------------------------------------------
    local phaseDef = d.enemies["heisenbug"]  -- abilities="phase"
    local ep = Enemy(phaseDef, 1, 1)
    ep.spawnedAt = 10   -- 임의의 스폰 시각 — clock 산술만 쓰는지 확인
    t.eq(ep:isPhased(10 + 0), false, "phase: 스폰 직후(age0) 가시")
    t.eq(ep:isPhased(10 + 2.9), false, "phase: age 2.9s 가시")
    t.eq(ep:isPhased(10 + 3.0), true, "phase: age 3.0s(경계) 은신 시작")
    t.eq(ep:isPhased(10 + 4.9), true, "phase: age 4.9s 은신")
    t.eq(ep:isPhased(10 + 5.0), false, "phase: age 5.0s 재출현")
    t.eq(ep:isPhased(10 + 8.0), true, "phase: 두 번째 주기(age8.0=3.0+5)도 은신")

    local eNoPhase = Enemy(d.enemies["bug"], 1, 1)
    eNoPhase.spawnedAt = 0
    t.eq(eNoPhase:isPhased(100), false, "phase 능력 없는 적은 항상 isPhased false")

    local bph = Battle(d, 1, {})
    t.ok(bph:buildTower("printer", 3, 10, "pp2"), "phase 테스트용 프린터 건설")
    local twPh = bph.towersByName["pp2"]
    local ephA = Enemy(phaseDef, twPh.r, twPh.c)
    ephA.id = 501
    ephA.spawnedAt = -10   -- clock=4에서 age=14 → 은신 중(14%5=4>=3)
    ephA.x, ephA.y = twPh.x, twPh.y
    local ephB = Enemy(d.enemies["bug"], twPh.r, twPh.c)
    ephB.id = 502
    ephB.spawnedAt = 0     -- clock=4에서 age=4 → phase 능력 없으니 항상 가시
    ephB.x, ephB.y = twPh.x, twPh.y

    bph.enemies = { ephA }
    local envPh, setTowerPh = api.buildEnv(bph)
    setTowerPh(twPh)

    bph.clock = 1.0   -- 가시 구간
    local _, worldVis = api.refresh(envPh, twPh, bph.enemies, bph.clock)
    t.eq(#worldVis.enemies(), 1, "phase: 가시 구간엔 world.enemies()에 포함")

    bph.clock = 4.0   -- 은신 구간
    local _, worldHidden = api.refresh(envPh, twPh, bph.enemies, bph.clock)
    t.eq(#worldHidden.enemies(), 0, "phase: 은신 구간엔 world.enemies()에서 제외")
    t.eq(worldHidden.nearest(), nil, "phase: 은신 중 world.nearest() nil")
    t.eq(worldHidden.oldest(), nil, "phase: 은신 중 world.oldest() nil")

    bph.clock = 5.0   -- 재출현
    local _, worldBack = api.refresh(envPh, twPh, bph.enemies, bph.clock)
    t.eq(#worldBack.enemies(), 1, "phase: 재출현(age5.0) 시 다시 world.enemies()에 포함")

    -- 혼합: 은신 중인 쪽이 나이가 더 많아도 oldest 후보에서 제외되고 가시 적이 선택됨
    bph.enemies = { ephA, ephB }
    bph.clock = 4.0
    local _, worldMix = api.refresh(envPh, twPh, bph.enemies, bph.clock)
    t.eq(#worldMix.enemies(), 1, "phase: 은신 중인 적은 혼합 목록에서도 제외")
    local oldestMix = worldMix.oldest()
    t.eq(oldestMix.id, ephB.id,
        "phase: 은신 중(나이 더 많음)인 적은 oldest 후보에서 제외, 가시 적이 선택됨")

    -- 투사체 명중 무효: 명중 순간 대상이 은신 중이면 데미지 무효(통과·소멸), 가시면 정상 명중
    local ephHit = Enemy(phaseDef, 1, 1)
    ephHit.id = 601
    ephHit.spawnedAt = 0
    ephHit.hp = 100
    ephHit.x, ephHit.y = 100, 0
    local projHidden = Projectile(0, 0, ephHit, 20, 1000, 4)
    projHidden:update(1, 4.0)   -- clock=4.0(은신 중), 사거리 안(거리100<=step1000)
    t.eq(projHidden.done, true, "투사체: 명중 시점 자체는 발생(소멸)")
    t.eq(ephHit.hp, 100, "투사체: 은신 중 명중은 데미지 무효")

    local ephHit2 = Enemy(phaseDef, 1, 1)
    ephHit2.id = 602
    ephHit2.spawnedAt = 0
    ephHit2.hp = 100
    ephHit2.x, ephHit2.y = 100, 0
    local projVisible = Projectile(0, 0, ephHit2, 20, 1000, 4)
    projVisible:update(1, 1.0)   -- clock=1.0(가시 구간)
    t.eq(projVisible.done, true, "투사체: 가시 상태 명중도 소멸")
    t.eq(ephHit2.hp, 80, "투사체: 가시 상태에서는 정상 데미지 적용")

    -- 서버라인 도달 판정은 은신과 무관하게 유지(Enemy:update는 phase를 참조하지 않는다)
    local ephReach = Enemy(phaseDef, 16, 2)   -- (16,2): 001.txt 서버라인(dist=0) 칸
    ephReach.spawnedAt = 0
    local hiddenClock = 4.0
    t.eq(ephReach:isPhased(hiddenClock), true, "reach 테스트: 이 시각엔 은신 중")
    ephReach:update(0.001, bph.grid, hiddenClock)
    t.eq(ephReach.reached, true, "phase: 은신 중이어도 서버라인 도달 판정은 그대로 발생")

    ------------------------------------------------------------------
    -- ⑧ split2: 사망 시 hp 절반 2기(깊이1), 깊이1 사망 시 또 2기(깊이2), 깊이2는 분열 없음.
    --    reachedByType 등 집계는 부모 def 기준. 기존 split(concat-nil, 깊이1)은 불변.
    ------------------------------------------------------------------
    local bs = Battle(d, 1, {})
    bs:start()
    local forkDefRef = d.enemies["fork-bomb"]  -- abilities="split2"
    local origin = Enemy(forkDefRef, 2, 2)
    origin.id = bs.nextEnemyId
    bs.nextEnemyId = bs.nextEnemyId + 1
    origin.spawnedAt = bs.clock
    origin.max_hp = forkDefRef.hp
    origin.hp = 0   -- 사망 예정
    bs.enemies = { origin }
    bs:update(1 / 60)
    t.eq(#bs.enemies, 2, "split2: 깊이0 사망 → 깊이1 자식 2기")
    local c1, c2 = bs.enemies[1], bs.enemies[2]
    t.eq(c1.splitDepth, 1, "split2: 자식1 splitDepth=1")
    t.eq(c2.splitDepth, 1, "split2: 자식2 splitDepth=1")
    t.eq(c1.hp, math.floor(forkDefRef.hp / 2), "split2: 자식 hp=부모 max_hp 절반(floor)")
    t.eq(c1.def.id, forkDefRef.id, "split2: 자식 def는 부모 def(적 구성 집계 부모 기준)")

    -- 깊이1 둘 다 사망 → 깊이2 자식 각 2기(총 4기), 더 분열 없음
    c1.hp, c2.hp = 0, 0
    bs:update(1 / 60)
    t.eq(#bs.enemies, 4, "split2: 깊이1 둘 다 사망 → 깊이2 자식 총 4기")
    for _, kid in ipairs(bs.enemies) do
        t.eq(kid.splitDepth, 2, "split2: 손자 세대 splitDepth=2")
    end

    -- 깊이2 사망 → 더 이상 분열 없음(전멸)
    for _, kid in ipairs(bs.enemies) do kid.hp = 0 end
    bs:update(1 / 60)
    t.eq(#bs.enemies, 0, "split2: 깊이2는 분열하지 않음(전멸)")

    -- 기존 split(concat-nil, 깊이1) 회귀: 자식은 딱 1세대만 생기고 더는 분열 안 함(바이트 동일)
    local bs2 = Battle(d, 1, {})
    bs2:start()
    local concatDefRef = d.enemies["concat-nil"]
    local originC = Enemy(concatDefRef, 2, 2)
    originC.id = bs2.nextEnemyId
    bs2.nextEnemyId = bs2.nextEnemyId + 1
    originC.spawnedAt = bs2.clock
    originC.max_hp = concatDefRef.hp
    originC.hp = 0
    bs2.enemies = { originC }
    bs2:update(1 / 60)
    t.eq(#bs2.enemies, 2, "split(concat-nil): 사망 시 자식 2기(깊이1)")
    local sc1, sc2 = bs2.enemies[1], bs2.enemies[2]
    t.eq(sc1.splitDepth, 1, "split: 자식 splitDepth=1")
    t.eq(sc1.hp, math.floor(concatDefRef.hp / 2), "split(concat-nil): 자식 hp 절반(floor, 기존과 동일)")
    sc1.hp, sc2.hp = 0, 0
    bs2:update(1 / 60)
    t.eq(#bs2.enemies, 0, "split(concat-nil): 자식 사망 시 더 분열 없음(기존 동작 불변)")

    ------------------------------------------------------------------
    -- ⑨ 결정론 재현: 같은 스테이지·같은 스크립트로 Battle 전체를 2회 실행
    --    → status·serverHP(+잔존 적 수·money) 완전 일치. pair/phase/split이 섞인 커스텀
    --    타임라인으로 새 능력 경로의 결정론까지 함께 증명한다.
    ------------------------------------------------------------------
    local DET_SCRIPT = [[
build("printer", 3, 10, "a")
build("printer", 11, 3, "b")
function on_tick(self, world)
  self:attack(world.nearest())
end
]]
    local function buildDeterminismBattle()
        local b = Battle(d, 1, {})
        b.timeline = {
            { at = 0, spawn = "deadlock", count = 5, interval = 0.5, col = 4 },
            { at = 6, spawn = "heisenbug", count = 3, interval = 0.7, col = 9 },
            { at = 12, spawn = "fork-bomb", count = 2, interval = 1.0, col = 4 },
            { at = 18, spawn = "concat-nil", count = 2, interval = 1.0, col = 9 },
        }
        t.ok(b:setScript(DET_SCRIPT), "결정론 테스트: 스크립트 컴파일")
        b:start()
        return b
    end
    local function runFull(b, seconds)
        local dt = 1 / 30
        for _ = 1, math.floor(seconds / dt) do
            if b.status ~= "running" then break end
            b:update(dt)
        end
        return b
    end

    local bd1 = runFull(buildDeterminismBattle(), 310)
    local bd2 = runFull(buildDeterminismBattle(), 310)

    t.ok(bd1.status == "clear" or bd1.status == "defeat", "결정론: 실행1이 종료 상태(clear/defeat)에 도달")
    t.eq(bd1.status, bd2.status, "결정론: 2회 실행 status 완전 일치")
    t.eq(bd1.serverHP, bd2.serverHP, "결정론: 2회 실행 serverHP 완전 일치")
    t.eq(#bd1.enemies, #bd2.enemies, "결정론: 2회 실행 잔존 적 수 동일")
    t.eq(bd1.money, bd2.money, "결정론: 2회 실행 money 동일")
    local rt1, rt2 = bd1.reachedByType or {}, bd2.reachedByType or {}
    local rtKeys = {}
    for k in pairs(rt1) do rtKeys[k] = true end
    for k in pairs(rt2) do rtKeys[k] = true end
    for k in pairs(rtKeys) do
        t.eq(rt1[k], rt2[k], ("결정론: reachedByType[%s] 값 일치"):format(tostring(k)))
    end

    ------------------------------------------------------------------
    -- ⑩ splash(gc-collector): 명중점 기준 반경 60px 선형 낙폭(중심100%→가장자리50%,
    --    floor·min1), 61px 밖 0, 은신 피해자 면제, 주 타겟 자신은 이중 타격 없음.
    --    ability="splash" 분기로 실제 tower.buildTower→resolveAttack 경로에서 생성됨을
    --    확인(합성 데이터가 아니라 실제 발동 경로).
    ------------------------------------------------------------------
    local bsp = Battle(d, 6, {})
    bsp:start()
    t.ok(bsp:buildTower("compiler", 2, 2, "c"), "splash: 컴파일러 건설(gc-collector 선행 조건)")
    t.ok(bsp:buildTower("gc-collector", 4, 2, "gc"), "splash: GC 수집기 건설")
    local twGC = bsp.towersByName["gc"]
    bsp.clock = 4.0   -- heisenbug(spawnedAt=0) age4.0 → 은신 구간(§⑦과 동일한 산술)

    local mainT = Enemy(d.enemies["bug"], twGC.r, twGC.c)
    mainT.id, mainT.hp, mainT.spawnedAt = 8001, 100, bsp.clock
    mainT.x, mainT.y = twGC.x, twGC.y                      -- 명중점(거리0, 사거리 안 · 주 타겟)
    local near = Enemy(d.enemies["bug"], twGC.r, twGC.c)
    near.id, near.hp, near.spawnedAt = 8002, 100, bsp.clock
    near.x, near.y = twGC.x + 30, twGC.y                   -- 명중점에서 30px
    local far = Enemy(d.enemies["bug"], twGC.r, twGC.c)
    far.id, far.hp, far.spawnedAt = 8003, 100, bsp.clock
    far.x, far.y = twGC.x + 61, twGC.y                     -- 명중점에서 61px(반경 밖)
    local hiddenV = Enemy(d.enemies["heisenbug"], twGC.r, twGC.c)  -- phase 능력
    hiddenV.id, hiddenV.hp, hiddenV.spawnedAt = 8004, 100, 0        -- age4.0 → 은신 중
    hiddenV.x, hiddenV.y = twGC.x + 20, twGC.y             -- 사거리 안이지만 은신(면제 대상)
    t.ok(hiddenV:isPhased(bsp.clock), "splash 게이트 자가검증: hiddenV가 이 시각 실제로 은신 중")

    bsp.enemies = { mainT, near, far, hiddenV }
    twGC.pendingTarget = mainT.id
    bsp:resolveAttack(twGC)
    local proj = bsp.projectiles[#bsp.projectiles]
    t.eq(proj.splash, true, "splash: gc-collector 투사체는 splash=true(ability 분기로 실제 세팅됨)")
    t.eq(proj.damage, d.towers["gc-collector"].damage,
        "splash 게이트 자가검증: 주 타겟 데미지=기준값(charge0·dan없음 → mult1)")

    t.ok(bsp:buildTower("printer", 7, 2, "pchk"), "splash 대조군: 프린터 건설")
    local twP2 = bsp.towersByName["pchk"]
    local decoy = Enemy(d.enemies["bug"], twP2.r, twP2.c)
    decoy.id, decoy.hp, decoy.spawnedAt = 8005, 100, bsp.clock
    decoy.x, decoy.y = twP2.x, twP2.y
    bsp.enemies[#bsp.enemies + 1] = decoy
    twP2.pendingTarget = decoy.id
    bsp:resolveAttack(twP2)
    t.eq(bsp.projectiles[#bsp.projectiles].splash, false,
        "splash 대조군: printer(ability 무관) 투사체는 splash=false")

    proj:update(1000, bsp.clock, bsp.enemies)   -- 큰 dt로 명중 처리(거리0 → 어차피 이번 프레임 명중)
    t.eq(proj.done, true, "splash: 명중 처리 완료")
    t.eq(proj.splashHit, true, "splash: 폭발 발생 플래그(뷰 관측용) true")
    t.eq(mainT.hp, 100 - d.towers["gc-collector"].damage,
        "splash: 주 타겟은 정상 데미지만 받음(스플래시로 이중 타격 없음)")
    local expectedNear = math.max(1, math.floor(d.towers["gc-collector"].damage * (1 - 0.5 * 30 / 60)))
    t.eq(expectedNear, 4, "splash 산술 자가검증: 6×0.75=4.5 → floor=4(비정수 결과로 floor 구별 확인)")
    t.eq(near.hp, 100 - expectedNear, "splash: 명중점 30px 옆 적은 ×0.75 floor 데미지")
    t.eq(far.hp, 100, "splash: 61px 밖은 데미지 0(반경 제외)")
    t.eq(hiddenV.hp, 100, "splash: 은신 중인 피해자는 면제(0)")
    t.eq(decoy.hp, 100, "splash: printer 대조군 명중과 무관 — decoy는 gc 폭발 범위 밖(별개 타워)")

    ------------------------------------------------------------------
    -- ⑩-2 splash 피해자별 경감(최종 리뷰 반영): 광역 피해도 피해자 기준으로 resist·pair를
    --    직격과 동일 순서(resist→pair, 각각 floor·min1)로 적용한다 — 우회를 허용하면
    --    GC 수집기+컴파일러(230)가 스테이지14 예산(250) 안에 들어와 "표적 분산" 학습
    --    포인트가 무력화된다. 두 케이스 모두 전제 조건(게이트)이 실제로 참인지부터 값으로
    --    확인한다(이 웨이브에서 헛단언이 3회 적발된 전례가 있어 값 추적이 필수).
    ------------------------------------------------------------------
    local bfin = Battle(d, 6, {})
    bfin:start()
    t.ok(bfin:buildTower("compiler", 2, 2, "c2"), "splash 경감: 컴파일러 건설")
    t.ok(bfin:buildTower("gc-collector", 4, 2, "gc2"), "splash 경감: GC 수집기 건설")
    local twGC2 = bfin.towersByName["gc2"]

    -- (a) pair: 스플래시 피해자가 pair 생존 쌍이면 낙폭에도 ×0.4가 적용돼야 한다. 직격
    --     대상은 pair와 무관한 bug로 두어 splash 경로만 순수하게 관측한다.
    local pairMain = Enemy(d.enemies["bug"], twGC2.r, twGC2.c)
    pairMain.id, pairMain.hp, pairMain.spawnedAt = 8101, 100, bfin.clock
    pairMain.x, pairMain.y = twGC2.x, twGC2.y

    local deadlockDef = d.enemies["deadlock"]  -- abilities="pair"
    local pairV1 = Enemy(deadlockDef, twGC2.r, twGC2.c)
    pairV1.id, pairV1.hp, pairV1.spawnedAt = 8102, 100, bfin.clock
    pairV1.x, pairV1.y = twGC2.x + 30, twGC2.y     -- 명중점에서 30px(splash 반경 안)
    local pairV2 = Enemy(deadlockDef, twGC2.r, twGC2.c)
    pairV2.id, pairV2.hp, pairV2.spawnedAt = 8103, 100, bfin.clock
    pairV2.x, pairV2.y = twGC2.x + 5000, twGC2.y   -- 반경 훨씬 밖(짝만 생존, 직접 피격 안 함)
    pairV1.pairId, pairV1.pairAlive = pairV2.id, true
    pairV2.pairId, pairV2.pairAlive = pairV1.id, true
    t.ok(pairV1.abilities.pair, "splash pair 경감 게이트: pairV1은 실제 pair 능력 보유")
    t.eq(pairV1.pairAlive, true, "splash pair 경감 게이트: pairV1의 짝(pairV2)이 실제로 생존 중")

    bfin.enemies = { pairMain, pairV1, pairV2 }
    twGC2.pendingTarget = pairMain.id
    bfin:resolveAttack(twGC2)
    local projPair = bfin.projectiles[#bfin.projectiles]
    projPair:update(1000, bfin.clock, bfin.enemies)

    local rawFalloff = projPair.damage * (1 - 0.5 * 30 / 60)          -- 6×0.75=4.5(주 타겟 damage 기준)
    local unmitigated = math.max(1, math.floor(rawFalloff))          -- floor(4.5)=4
    local expectedPairDmg = math.max(1, math.floor(rawFalloff * 0.4))  -- floor(4.5×0.4)=floor(1.8)=1
    t.ok(expectedPairDmg < unmitigated,
        "splash pair 경감 게이트: 미적용 값과 실제 달라야 진짜 게이트(헛단언 방지)")
    t.eq(pairV1.hp, 100 - expectedPairDmg,
        "splash: 피해자가 pair 생존 쌍이면 낙폭에도 ×0.4(floor·min1) 적용")

    -- (b) resist: 이 splash를 쏜 타워가 gc-collector이므로 legacy(resist:printer)의 저항은
    --     매치하지 않아야 한다(게이트 불일치 — printer가 아닌 타워의 splash는 저항 무의미).
    twGC2.cd, twGC2.charge = 0, 0
    local resistMain = Enemy(d.enemies["bug"], twGC2.r, twGC2.c)
    resistMain.id, resistMain.hp, resistMain.spawnedAt = 8111, 100, bfin.clock
    resistMain.x, resistMain.y = twGC2.x, twGC2.y
    local legacyV = Enemy(d.enemies["legacy"], twGC2.r, twGC2.c)  -- abilities="resist:printer"
    legacyV.id, legacyV.hp, legacyV.spawnedAt = 8112, 300, bfin.clock
    legacyV.x, legacyV.y = twGC2.x + 30, twGC2.y
    t.eq(legacyV.abilities.resist, "printer",
        "splash resist 게이트: legacy의 resist 대상은 printer(gc-collector와 실제로 불일치)")

    bfin.enemies = { resistMain, legacyV }
    twGC2.pendingTarget = resistMain.id
    bfin:resolveAttack(twGC2)
    local projResist = bfin.projectiles[#bfin.projectiles]
    projResist:update(1000, bfin.clock, bfin.enemies)
    t.eq(legacyV.hp, 300 - unmitigated,
        "splash: resist 대상이 printer가 아닌 gc-collector면 저항 미적용(낙폭 그대로)")

    ------------------------------------------------------------------
    -- ⑩-3 splash 60px 경계: falloff = 1 - 0.5×(60/60) = 0.5. ed<=60이 포함 판정이므로
    --    정확히 60px 지점도 낙폭 피해를 받는다(charge로 주 타겟 데미지를 비정수로 만들어
    --    floor가 실제로 개입했는지 구별한다).
    ------------------------------------------------------------------
    local bbound = Battle(d, 6, {})
    bbound:start()
    t.ok(bbound:buildTower("compiler", 2, 2, "cb"), "splash 경계: 컴파일러 건설")
    t.ok(bbound:buildTower("gc-collector", 4, 2, "gcb"), "splash 경계: GC 수집기 건설")
    local twGCb = bbound.towersByName["gcb"]
    twGCb.charge = 0.1   -- mult = 1 + 0.1×0.5 = 1.05 → 주 타겟 데미지가 비정수가 된다

    local boundMain = Enemy(d.enemies["bug"], twGCb.r, twGCb.c)
    boundMain.id, boundMain.hp, boundMain.spawnedAt = 8121, 100, bbound.clock
    boundMain.x, boundMain.y = twGCb.x, twGCb.y
    local boundEdge = Enemy(d.enemies["bug"], twGCb.r, twGCb.c)
    boundEdge.id, boundEdge.hp, boundEdge.spawnedAt = 8122, 100, bbound.clock
    boundEdge.x, boundEdge.y = twGCb.x + 60, twGCb.y   -- 명중점에서 정확히 60px(경계, 포함)

    bbound.enemies = { boundMain, boundEdge }
    twGCb.pendingTarget = boundMain.id
    bbound:resolveAttack(twGCb)
    local projBound = bbound.projectiles[#bbound.projectiles]
    local mainDmg = projBound.damage
    t.ok(mainDmg ~= math.floor(mainDmg),
        "splash 경계 게이트: 주 타겟 데미지가 비정수(charge 배율 반영, 6×1.05=6.3)")
    projBound:update(1000, bbound.clock, bbound.enemies)

    local expectedEdge = math.max(1, math.floor(mainDmg * 0.5))
    t.eq(expectedEdge, 3, "splash 경계 산술 자가검증: floor(6.3×0.5)=floor(3.15)=3(비정수 결과로 floor 구별)")
    t.eq(boundEdge.hp, 100 - expectedEdge,
        "splash: 정확히 60px 경계도 포함(ed<=60)되어 낙폭 피해 적용")

    ------------------------------------------------------------------
    -- ⑪ slowfield(디버거): 사거리 내 실효 speed ×0.6, 2기 겹쳐도 ×0.6 한 번만,
    --    사거리 밖 즉시 원복, dash와 겹치면 ×3×0.6 복합. 디버거는 무발사(투사체 0,
    --    ability 분기 확인 — cd/overclock도 갱신 안 됨). limit 2 초과는 기존 경로로 실패.
    ------------------------------------------------------------------
    -- (a) 훅 단위: e.slowed 플래그만으로 effectiveSpeed 배율 확인(dash 훅과 동일 지점 재사용)
    local esOff = Enemy(d.enemies["bug"], 1, 1)
    esOff.spawnedAt = 0
    esOff:updateStats(0)
    t.eq(esOff.speed, esOff.def.speed, "slowfield 훅: slowed=false(기본)면 실효 speed 그대로")

    local esOn = Enemy(d.enemies["bug"], 1, 1)
    esOn.spawnedAt = 0
    esOn.slowed = true
    esOn:updateStats(0)
    t.eq(esOn.speed, esOn.def.speed * 0.6, "slowfield 훅: slowed=true면 실효 speed ×0.6")

    local esDash = Enemy(d.enemies["race-cond"], 1, 1)   -- dash 능력
    esDash.spawnedAt = 0
    esDash.slowed = true
    esDash:updateStats(0.1)   -- 대시 창 안(0.1s < DASH_LEN 0.3s) — 게이트 자가검증
    t.ok((esDash.age % 1.5) < 0.3, "slowfield 복합 게이트 자가검증: 이 age는 실제 대시 창 안")
    t.eq(esDash.speed, esDash.def.speed * 3 * 0.6, "slowfield 훅: dash 중 겹치면 ×3×0.6 복합")

    -- (b) Battle 레벨 자동 판정: 디버거 사거리 안/밖 실측, 2기 중첩 시에도 ×0.6 한 번만
    local bsf = Battle(d, 6, {})
    bsf:start()
    bsf.clock = 0
    bsf.timeline, bsf.spawned = {}, {}   -- 실제 스테이지6 스폰 유입을 차단해 순수 관측 유지
    t.ok(bsf:buildTower("debugger", 2, 2, "d1"), "slowfield: 디버거1 건설")
    t.ok(bsf:buildTower("debugger", 4, 2, "d2"), "slowfield: 디버거2 건설(사거리 겹치는 위치)")
    local twD1, twD2 = bsf.towersByName["d1"], bsf.towersByName["d2"]

    local eSF = Enemy(d.enemies["bug"], twD1.r, twD1.c)
    eSF.id, eSF.spawnedAt = 9201, 0
    eSF.x, eSF.y = twD1.x, twD1.y + 32   -- d1 사거리 32 안, d2와도 32 거리(둘 다 range132 안)
    bsf.enemies = { eSF }
    local dToD1 = math.sqrt((eSF.x - twD1.x) ^ 2 + (eSF.y - twD1.y) ^ 2)
    local dToD2 = math.sqrt((eSF.x - twD2.x) ^ 2 + (eSF.y - twD2.y) ^ 2)
    t.ok(dToD1 <= twD1.def.range and dToD2 <= twD2.def.range,
        "slowfield 게이트 자가검증: eSF는 실제로 디버거 두 대 사거리 안(중첩 상황)")
    bsf:update(1 / 60)
    t.eq(eSF.slowed, true, "slowfield: 사거리 안 → slowed=true")
    t.eq(eSF.speed, eSF.def.speed * 0.6, "slowfield: 디버거 2기 겹쳐도 ×0.6 한 번만(중첩 아님)")

    eSF.x, eSF.y = twD1.x + 100000, twD1.y   -- 사거리 훨씬 밖으로 이동
    bsf:update(1 / 60)
    t.eq(eSF.slowed, false, "slowfield: 사거리 밖으로 나가면 slowed=false")
    t.eq(eSF.speed, eSF.def.speed, "slowfield: 사거리 밖 → 실효 speed 즉시 원복")

    -- (c) 디버거 무발사: 공통 on_tick이 있어도 ability 분기로 on_tick 자체가 스킵됨을 확인
    --     (damage=0 우연이 아니라는 근거로 cd·overclock도 전혀 갱신되지 않는지까지 확인)
    local bd = Battle(d, 6, {})
    bd:start()
    bd.timeline, bd.spawned = {}, {}
    t.ok(bd:buildTower("debugger", 2, 2, "dbg"), "무발사 테스트: 디버거 건설")
    local twDbg = bd.towersByName["dbg"]
    local target = Enemy(d.enemies["bug"], twDbg.r, twDbg.c)
    target.id, target.hp, target.spawnedAt = 9301, 100, 0
    target.x, target.y = twDbg.x, twDbg.y   -- 사거리 안(거리0) — 항상 타겟 존재
    bd.enemies = { target }
    local ATTACK_SCRIPT = [[
function on_tick(self, world)
  if world.nearest() then self:attack(world.nearest()) end
end
]]
    t.ok(bd:setScript(ATTACK_SCRIPT), "무발사 테스트: 공용 on_tick 스크립트 컴파일")
    -- Battle:update 전체(이동·정리)가 아니라 runTick()만 여러 번 직접 호출한다 — 그래야
    -- "우연히 데미지가 0이라 해가 없다"가 아니라 "on_tick 호출·투사체 생성 자체가 없다"를
    -- 정확히 관찰할 수 있다(update()를 쓰면 debugger의 bullet_speed=0·거리0 조합 때문에
    -- 설령 예외적으로 투사체가 생겨도 그 프레임 안에서 즉시 명중·정리되어 이 부분이 헛단언이
    -- 되는 함정이 있었다 — RED 확인 과정에서 실제로 겪은 문제라 runTick 직접 호출로 바꿨다).
    for _ = 1, 5 do bd:runTick() end
    t.eq(#bd.projectiles, 0, "디버거: 발사 없음(투사체 0) — ability 분기가 실제로 on_tick을 건너뜀")
    t.eq(twDbg.cd, 0, "디버거: cd 갱신 없음(resolveAttack 자체가 호출된 적 없다는 근거)")
    t.eq(twDbg.overclock, 0, "디버거: overclock 갱신 없음(on_tick 성공 경로를 탄 적이 없다는 근거)")

    -- (d) limit 2 초과 build 실패(기존 limit 경로 — 한글 실패 로그 확인, 코어 변경 없음)
    local bl = Battle(d, 6, {})
    bl:start()
    t.ok(bl:buildTower("debugger", 2, 2, "l1"), "limit: 디버거 1번째(한도 내)")
    t.ok(bl:buildTower("debugger", 4, 2, "l2"), "limit: 디버거 2번째(한도 내)")
    local ok3, err3 = bl:buildTower("debugger", 7, 2, "l3")
    t.eq(ok3, false, "limit: 디버거 3번째는 실패(false)")
    t.eq(err3, ("%s는 스테이지당 %d개뿐입니다"):format(d.towers.debugger.name, d.towers.debugger.limit),
        "limit: 실패 메시지가 기존 한글 limit 경로 그대로")
end
