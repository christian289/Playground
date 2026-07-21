return function(t)
    local db = require("src.db")
    local d = db.load(PROJECT_ROOT)

    t.ok(d.towers.printer, "towers.csv 로드")
    t.eq(d.towers.printer.cost, 100, "타워 cost 숫자 변환")
    t.eq(d.towers.sniper.requires, "compiler", "테크 의존성 파싱")
    t.ok(d.enemies["null-ptr"], "enemies.csv 로드")
    t.eq(d.enemies["null-ptr"].hp, 20, "적 hp 숫자 변환")
    t.eq(d.stages[1].budget, 200, "stages.csv budget 숫자 변환")
    t.eq(d.stages[1].countdown, 20, "countdown 숫자 변환")
    t.eq(d.stages[1].tutorial_file, "", "tutorial_file 빈 값")
    t.eq(d.stages[1].buttons_file, "", "buttons_file 빈 값")
    t.eq(d.stages[1].wave_clock, nil, "빈 셀은 nil로 변환")

    local tl = d.timeline(1)
    t.ok(#tl >= 4, "타임라인 이벤트 존재")
    t.eq(tl[1].spawn, "bug", "타임라인 첫 이벤트")
    t.ok(tl[1].at <= tl[#tl].at, "타임라인 시각 정렬")

    local errs = d.validate()
    t.eq(#errs, 0, "참조 무결성 (오류 0건): " .. table.concat(errs, " / "))

    local bad = db.load(PROJECT_ROOT .. "/tests/fixtures/baddata")
    local baderrs = bad.validate()
    t.ok(#baderrs >= 3, "깨진 데이터에서 오류 감지 (spawn/미로/requires): " .. #baderrs .. "건")
    t.ok(table.concat(baderrs, " / "):find("스폰 열"), "벽에 스폰하는 타임라인 열 감지")
    t.ok(table.concat(baderrs, "/"):find("튜토리얼"), "없는 tutorial_file 감지")
end
