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
end
