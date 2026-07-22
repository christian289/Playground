return function(t)
    local db = require("src.db")
    local stageinfo = require("src.stageinfo")
    local Battle = require("src.battle")
    local d = db.load(PROJECT_ROOT)

    local info = stageinfo.totals(d.timeline(1))
    t.ok(info.total > 0, "전체 적 수 > 0")
    t.ok(info.byType.bug and info.byType.bug > 0, "종류별 집계")
    t.ok(info.lastEnd >= 240, "마지막 스폰 종료 ≥ 240 (validate와 일치)")
    local sum = 0
    for _, n in pairs(info.byType) do sum = sum + n end
    t.eq(sum, info.total, "종류 합 = 전체")

    -- killedCounts: 카운트다운 중(스폰 전)에는 전부 미처리(0)
    local b0 = Battle(d, 1, {})
    b0:start()
    local killed0 = stageinfo.killedCounts(info, b0)
    t.eq(killed0.bug or 0, 0, "카운트다운 중 처리 수 0")

    -- 전투를 실제로 진행시켜 처리 수가 늘어나는지 확인
    local ATK = [[
build("printer", 3, 10, "a")
build("printer", 11, 3, "b")
function on_tick(self, world)
  self:attack(world.nearest())
end
]]
    local b1 = Battle(d, 1, {})
    t.ok(b1:setScript(ATK), "정답 스크립트 컴파일")
    b1:start()
    local dt = 1 / 30
    for _ = 1, math.floor(120 / dt) do
        if b1.status ~= "running" then break end
        b1:update(dt)
    end
    local killed1 = stageinfo.killedCounts(info, b1)
    t.ok((killed1.bug or 0) > 0, "전투 진행 후 처리 수 증가")
    t.ok((killed1.bug or 0) <= info.byType.bug, "처리 수는 종류별 전체를 넘지 않음")
end
