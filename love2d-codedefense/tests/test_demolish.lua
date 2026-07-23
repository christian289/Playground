return function(t)
    local db = require("src.db")
    local Battle = require("src.battle")
    local d = db.load(PROJECT_ROOT)

    local function run(b, seconds)
        local dt = 1 / 30
        for _ = 1, math.floor(seconds / dt) do
            if b.status ~= "running" then break end
            b:update(dt)
        end
        return b
    end

    -- ① build 후 demolish: towers 수 0, 환불(floor(cost*0.5)) 반영, 점유 해제되어 재건설 성공
    local b1 = Battle(d, 1, {})
    b1:start()
    local moneyBefore = b1.money
    t.ok(b1:buildTower("printer", 3, 10, "a"), "빌드 성공")
    local moneyAfterBuild = b1.money
    t.eq(moneyAfterBuild, moneyBefore - 100, "빌드비 100 차감")
    t.ok(b1:demolishTower("a"), "철거 성공")
    t.eq(#b1.towers, 0, "철거 후 타워 수 0")
    t.eq(b1.money, moneyAfterBuild + 50, "환불 = floor(cost*0.5) = 50 가산")
    t.ok(table.concat(b1.log, "/"):find('%[철거%] 프린터 → "a" · %+50 환불'), "철거 로그 형식")
    t.ok(b1:buildTower("printer", 3, 10, "b"), "점유 해제되어 같은 칸에 다른 이름 재건설 성공")

    -- ② 미존재 이름 demolish: false 반환 + "철거 실패" 로그
    local b2 = Battle(d, 1, {})
    b2:start()
    local ok2 = b2:demolishTower("없음")
    t.eq(ok2, false, "미존재 타워 철거는 false")
    t.ok(table.concat(b2.log, "/"):find("철거 실패"), "철거 실패 로그 포함")
    t.eq(b2.log[#b2.log], '[오류] 철거 실패 — "없음" 타워가 없습니다', "철거 실패 로그 형식 정확")

    -- ③ setScript의 on_tick 안에서 demolish 호출: 다음 틱에 반영되고 크래시 없음
    local DEMO_SCRIPT = [[
build("printer", 3, 10, "a")
function on_tick(self, world)
  demolish("a")
end
]]
    local b3 = Battle(d, 1, {})
    t.ok(b3:setScript(DEMO_SCRIPT), "demolish 스크립트 컴파일")
    t.eq(#b3.towers, 1, "스크립트 저장 직후에는 아직 타워 존재")
    local tw3 = b3.towers[1]
    b3:start()
    run(b3, 0.3)
    t.eq(#b3.towers, 0, "on_tick의 demolish 호출로 다음 틱에 제거")
    t.eq(tw3.crashed, 0, "demolish 호출 자체는 크래시를 유발하지 않음")

    -- ④ demolish 후 같은 이름으로 build: 멱등 캐시가 막지 않고 재생성됨
    local b4 = Battle(d, 1, {})
    b4:start()
    t.ok(b4:buildTower("printer", 3, 10, "a"), "1차 빌드 성공")
    t.ok(b4:demolishTower("a"), "철거 성공")
    t.ok(b4:buildTower("printer", 3, 10, "a"), "철거 후 같은 이름으로 재건설 성공(멱등 캐시가 막지 않음)")
    t.eq(#b4.towers, 1, "재건설 후 타워 수 1")

    -- ⑤ 적이 서버라인에 도달하면 battle.reachedByType[적id] 증가(관측 전용 집계)
    local b5 = Battle(d, 1, {})
    b5:start()
    run(b5, 60)
    t.ok(b5.reachedByType["bug"] ~= nil and b5.reachedByType["bug"] >= 1, "도달 시 reachedByType 집계 증가")
end
