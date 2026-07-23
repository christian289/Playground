-- 적 능력 grow·dash·resist + 스냅샷 age/speed + world.oldest() (Wave B Task 2)
return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local Enemy = require("src.enemy")
    local api = require("src.api")
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
end
