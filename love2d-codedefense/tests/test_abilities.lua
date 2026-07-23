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
end
