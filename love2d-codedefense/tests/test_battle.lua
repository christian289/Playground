return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local d = db.load(PROJECT_ROOT)

    local ATK = [[
build("printer", 3, 10, "a")
build("printer", 11, 3, "b")
function on_tick(self, world)
  self:attack(world.nearest())
end
]]

    local function run(b, seconds)
        local dt = 1 / 30
        for _ = 1, math.floor(seconds / dt) do
            if b.status ~= "running" then break end
            b:update(dt)
        end
        return b
    end

    -- 스크립트 없이 방치 → 패배
    local b0 = Battle(d, 1, {})
    b0:start()
    run(b0, 400)
    t.eq(b0.status, "defeat", "무방비 시 패배")

    -- 카운트다운: clock<0 동안 스폰 없음
    local bc = Battle(d, 1, {})
    bc:start()
    t.ok(bc.clock < 0, "카운트다운 동안 clock 음수")
    run(bc, d.stages[1].countdown - 2)
    t.eq(#bc.enemies, 0, "카운트다운 동안 스폰 없음")

    -- 정답 스크립트 → 클리어 (스테이지 1)
    local b1 = Battle(d, 1, {})
    t.ok(b1:setScript(ATK), "setScript 성공")
    b1:start()
    run(b1, 400)
    t.eq(b1.status, "clear", "스테이지1 스크립트 클리어")

    -- build 멱등: 같은 스크립트 재저장해도 타워 수/돈 불변
    local b2 = Battle(d, 1, {})
    b2:setScript(ATK)
    local n, m = #b2.towers, b2.money
    t.ok(b2:setScript(ATK), "재저장 성공")
    t.eq(#b2.towers, n, "멱등: 타워 수 불변")
    t.eq(b2.money, m, "멱등: 돈 불변")

    -- 예산 부족: 3번째 설치 실패, 로그에 예산
    local b3 = Battle(d, 1, {})
    b3:setScript(ATK .. '\nbuild("printer", 7, 3, "c")')
    t.eq(#b3.towers, 2, "예산 부족 설치 실패")
    t.ok(table.concat(b3.log, "/"):find("예산"), "예산 부족 로그")

    -- 킬 보상: 클리어한 b1의 돈이 (시작예산-설치비)보다 큼
    t.ok(b1.money > d.stages[1].budget - 200, "처치 보상 누적")

    -- 문법 오류 저장 → 기존 코드 유지
    local b4 = Battle(d, 1, {})
    b4:setScript(ATK)
    local ok4, err4 = b4:setScript("function on_tick( broken")
    t.ok(not ok4 and err4 ~= nil, "문법 오류 저장 거부")
    t.ok(b4.env ~= nil and b4.env.on_tick ~= nil, "기존 on_tick 유지")

    -- 테크 의존성: compiler 없이 sniper → 실패 로그, compiler 후 성공
    local b5 = Battle(d, 1, {})
    b5:setScript('build("sniper", 3, 10, "s")')
    t.eq(#b5.towers, 0, "테크 미충족 설치 실패")
    b5:setScript('build("compiler", 3, 10, "c")\nbuild("sniper", 11, 3, "s")')
    t.eq(#b5.towers, 2, "컴파일러 후 스나이퍼 설치")

    -- 샌드박스: env에 원시 Tower 객체가 노출되지 않는다 (env._tower 회귀 금지)
    local bSbx = Battle(d, 1, {})
    bSbx:setScript(ATK)
    t.eq(bSbx.env._tower, nil, "원시 타워 미노출")

    -- 샌드박스: env._tower가 없으므로 이를 통한 tower.def 변조 시도는 인덱싱 오류로 그 타워만 크래시
    local SANDBOX_ESCAPE = [[
build("printer", 3, 10, "a")
function on_tick(self, world)
  _tower.def.damage = 9999
end
]]
    local bEsc = Battle(d, 1, {})
    bEsc:setScript(SANDBOX_ESCAPE)
    bEsc:start()
    run(bEsc, 2)
    t.ok(bEsc.towers[1].crashed > 0, "_tower 접근 시도는 nil 인덱싱으로 크래시")
    t.eq(d.towers.printer.damage, 10, "printer 공유 정의(damage) 불변")

    -- 장애 격리: 이름 분기 오류는 그 타워만 크래시
    local b6 = Battle(d, 1, {})
    b6:setScript(ATK .. [[

function on_tick(self, world)
  if self.name == "a" then local x = nil; return x.y end
  self:attack(world.nearest())
end
]])
    b6:start()
    run(b6, 2)
    local a6 = nil
    for _, tw in ipairs(b6.towers) do if tw.name == "a" then a6 = tw end end
    t.ok(a6.crashed > 0 or a6.disabled, "a 타워만 크래시")

    -- 아이템 게이팅: cache는 opts.items에 있을 때만
    local CACHE = 'build("printer", 3, 10, "a")\nfunction on_tick(self, world)\n  cache.set("n", (cache.get("n") or 0) + 1)\nend'
    local b7 = Battle(d, 1, { items = { "cache" } })
    t.ok(b7:setScript(CACHE), "cache 장착 시 컴파일")
    b7:start()
    run(b7, 1)
    local a7 = b7.towers[1]
    t.eq(a7.crashed, 0, "cache 사용 정상")
    local b8 = Battle(d, 1, {})
    b8:setScript(CACHE)
    b8:start()
    run(b8, 1)
    t.ok(b8.towers[1].crashed > 0, "cache 미보유 시 크래시")

    -- on_spawn: fn(enemy) 계약, cache에 기록
    local HOOK = [[
build("printer", 3, 10, "a")
on_spawn(function(e)
  cache.set("last", e.type)
end)
function on_tick(self, world) self:attack(world.nearest()) end
]]
    local b9 = Battle(d, 1, { items = { "cache", "webhook" } })
    t.ok(b9:setScript(HOOK), "webhook 스크립트 컴파일")
    b9:start()
    run(b9, d.stages[1].countdown + 10)
    t.eq(b9.env.cache.get("last"), "bug", "on_spawn이 적 스냅샷 수신")

    -- 전 스테이지 회귀 (데이터 주도): CSV의 모든 스테이지를 순회하며
    -- solution_file은 클리어, naive_file이 있으면 그 순진 배치는 반드시 패배임을 증명한다.
    local function readCode(rel)
        local f = assert(io.open(PROJECT_ROOT .. "/data/" .. rel, "rb"))
        local code = f:read("*a"); f:close()
        return code
    end
    local stageIds = {}
    for id in pairs(d.stages) do stageIds[#stageIds + 1] = id end
    table.sort(stageIds)
    local owned = {}
    for _, stageId in ipairs(stageIds) do
        local stage = d.stages[stageId]
        local b = Battle(d, stageId, { items = owned })
        t.ok(b:setScript(readCode(stage.solution_file)), ("스테이지 %d 정답 컴파일"):format(stageId))
        b:start()
        run(b, 420)
        t.eq(b.status, "clear", ("스테이지 %d 정답 클리어"):format(stageId))
        if stage.naive_file and stage.naive_file ~= "" then
            local bn = Battle(d, stageId, { items = owned })
            t.ok(bn:setScript(readCode(stage.naive_file)), ("스테이지 %d 순진 배치 컴파일"):format(stageId))
            bn:start()
            run(bn, 420)
            t.eq(bn.status, "defeat", ("스테이지 %d 순진 배치는 패배(퍼즐 강제)"):format(stageId))
        end
        local reward = stage.reward_item
        if reward ~= "" then owned[#owned + 1] = reward end
    end

    -- 버튼 스테이지 2: buttons_2의 마지막 버튼 스크립트(전략: 약한 적 우선)로 클리어
    do
        local f = assert(io.open(PROJECT_ROOT .. "/data/curriculum/buttons_2.lua", "rb"))
        local src = f:read("*a"); f:close()
        local chunk = assert(loadstring(src))
        local buttons = chunk()
        local script = buttons[#buttons].script
        local bb = Battle(d, 2, {})
        t.ok(bb:setScript(script), "buttons_2 마지막 버튼 스크립트 컴파일")
        bb:start()
        run(bb, 420)
        t.eq(bb.status, "clear", "buttons_2 마지막 버튼 스크립트로 스테이지2 클리어")
    end

    -- 구구 클래스: 별칭·limit·단 성장·배율
    local GUGU = 'build("구구클래스", 3, 10, "g")\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend'
    local bg = Battle(d, 1, {})
    t.ok(bg:setScript(GUGU), "한글 별칭 컴파일")
    t.eq(bg.towers[1].def.id, "gugu-class", "별칭이 gugu-class로 해석")
    t.eq(bg.towers[1].dan, 2, "2단 시작")
    bg:setScript(GUGU .. '\nbuild("gugu-class", 11, 3, "g2")')
    t.eq(#bg.towers, 1, "스테이지당 1개 제한")
    t.ok(table.concat(bg.log, "/"):find("1개뿐"), "limit 한글 오류 로그")

    -- 단 성장: 발사 여부와 무관하게 전투 시간(clock>=0) 기준 30초마다 진행
    bg:start()
    local dt = 1 / 30
    local totalSteps = math.floor((d.stages[1].countdown + 31) / dt)
    for _ = 1, totalSteps do bg:update(dt) end
    t.eq(bg.towers[1].dan, 3, "30초 후 3단")
    t.ok(table.concat(bg.log, "/"):find("3단 돌입"), "단 상승 로그")
    t.eq(Battle.TOTAL, 300, "TOTAL 상수 노출")

    -- 배율 검증: (11,3)은 초반 웨이브(col=4)가 지나가는 실제 정답 좌표(001_solution.lua의 "b")와
    -- 같아 이른 시각에 사격이 이뤄진다. 카운트다운 중 charge가 최대치(3)로 포화되므로
    -- 첫 발은 damage(6) * dan(2) * (1 + 3*0.5) = 30 으로 결정론적이다.
    local GUGU2 = 'build("구구클래스", 11, 3, "g")\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend'
    local bg2 = Battle(d, 1, {})
    bg2:setScript(GUGU2)
    bg2:start()
    local firstProjDamage = nil
    for _ = 1, math.floor(60 / dt) do
        bg2:update(dt)
        if not firstProjDamage and #bg2.projectiles > 0 then
            firstProjDamage = bg2.projectiles[1].damage
        end
        if firstProjDamage then break end
    end
    t.ok(firstProjDamage ~= nil, "구구 클래스 첫 발사")
    t.eq(firstProjDamage, 30, "발사 데미지 = damage(6) * dan(2) * 차지배율(2.5)")

    -- userFuncs: setScript 성공 후 새로 정의된 함수 이름을 정렬 수집, 실패 시 기존 유지
    local FN = 'build("printer", 3, 10, "a")\nfunction helper(w) return w.nearest() end\nfunction on_tick(self, world)\n  self:attack(helper(world))\nend'
    local bf = Battle(d, 1, {})
    t.ok(bf:setScript(FN), "userFuncs 스크립트 컴파일")
    t.eq(#bf.userFuncs, 2, "새 함수 2개 수집")
    t.eq(bf.userFuncs[1], "helper", "정렬 첫 항목")
    t.eq(bf.userFuncs[2], "on_tick", "정렬 둘째 항목")
    bf:setScript("function on_tick( broken")
    t.eq(#bf.userFuncs, 2, "실패 저장 시 기존 목록 유지")
end
