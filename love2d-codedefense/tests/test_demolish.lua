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

    -- ⑥ 멀티타워 mid-tick demolish: 같은 틱에 타워 A의 on_tick이 (배치 순서상 앞선) 타워 B를
    -- demolish하면, runTick이 self.towers를 ipairs로 직접 순회할 경우 table.remove로 인해
    -- 배열이 앞으로 당겨져 그 뒤(B보다도 뒤, A 다음 차례)의 타워 C의 on_tick이 그 틱에서
    -- 통째로 스킵되는 버그가 있었다. B → A → C 순서로 건설(towers 배열 순서 그대로)해 재현한다.
    -- (스테이지 6: 예산 360으로 3타워 300을 감당, 건설칸은 mazes/006.txt 기준)
    local b6 = Battle(d, 6, {})
    b6:start()
    t.ok(b6:buildTower("printer", 2, 2, "B"), "B 빌드 성공")
    t.ok(b6:buildTower("printer", 2, 10, "A"), "A 빌드 성공")
    t.ok(b6:buildTower("printer", 4, 2, "C"), "C 빌드 성공")
    local SKIP_SCRIPT = [[
function on_tick(self, world)
  if self.name == "A" then demolish("B") end
end
]]
    t.ok(b6:setScript(SKIP_SCRIPT), "스킵 재현 스크립트 컴파일")
    local twC = b6.towersByName["C"]
    local chargeBefore = twC.charge
    b6:runTick()
    t.eq(#b6.towers, 2, "A가 B를 철거해 타워 수 2(A, C)")
    t.ok(twC.charge > chargeBefore,
        "A가 B를 철거한 그 틱에도 C의 on_tick이 스킵되지 않고 실행됨(charge 누적으로 확인)")

    -- ⑦ 이미 철거된 타워의 on_tick은 실행되지 않아야 한다: P(먼저 건설)의 on_tick이 Q(나중
    -- 건설, 같은 틱에 아직 실행 전)를 demolish하면 Q는 이번 틱에 아예 실행되지 않아야 한다.
    local b7 = Battle(d, 6, {})
    b7:start()
    t.ok(b7:buildTower("printer", 2, 2, "P"), "P 빌드 성공")
    t.ok(b7:buildTower("printer", 2, 10, "Q"), "Q 빌드 성공")
    local DEMOLISHED_NO_RUN_SCRIPT = [[
function on_tick(self, world)
  if self.name == "P" then demolish("Q") end
end
]]
    t.ok(b7:setScript(DEMOLISHED_NO_RUN_SCRIPT), "철거 대상 선실행 스크립트 컴파일")
    local twP, twQ = b7.towersByName["P"], b7.towersByName["Q"]
    local pChargeBefore, qChargeBefore = twP.charge, twQ.charge
    b7:runTick()
    t.eq(#b7.towers, 1, "Q 철거로 타워 수 1(P만 남음)")
    t.ok(twP.charge > pChargeBefore, "P의 on_tick은 정상 실행됨(charge 누적)")
    t.eq(twQ.charge, qChargeBefore, "이미 철거된 Q의 on_tick은 실행되지 않음(charge 불변)")
end
