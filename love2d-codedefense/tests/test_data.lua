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
    t.eq(d.stages[1].tutorial_file, "curriculum/tutorial_1.lua", "tutorial_file 값 로드")
    t.eq(d.stages[5].tutorial_file, "", "tutorial_file 빈 값(튜토리얼 없는 스테이지)")
    t.eq(d.stages[1].buttons_file, "curriculum/buttons_1.lua", "buttons_file 값 로드")
    t.eq(d.stages[3].buttons_file, "", "buttons_file 빈 값(버튼 없는 스테이지)")
    t.eq(d.stages[1].wave_clock, nil, "빈 셀은 nil로 변환")
    t.eq(d.towers["gugu-class"].limit, 1, "gugu-class limit 숫자 변환")
    t.eq(d.towers.printer.limit, nil, "빈 limit은 nil")
    t.eq(d.stages[1].lore_file, "lore/001.lua", "stages.csv lore_file 값 로드")
    t.eq(d.stages[12].lore_file, "lore/012.lua", "stages.csv 마지막 스테이지 lore_file")
    t.eq(d.enemies.bug.origin,
        "1947년 그레이스 호퍼의 팀이 Mark II 릴레이에서 진짜 나방을 꺼내 로그에 붙였다 — \"버그가 실제로 발견된 최초의 사례\"",
        "enemies.csv origin 로드")

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
    t.ok(table.concat(baderrs, " / "):find("240초"), "마지막 스폰 종료 240초 미만 감지")
    t.ok(table.concat(baderrs, " / "):find("공백"), "스폰 공백 40초 초과 감지")
    t.ok(table.concat(baderrs, " / "):find("로어 파일 없음"), "없는 lore_file 감지")
    local loreErrCount = 0
    for _, e in ipairs(baderrs) do
        if e:find("로어 파일 없음") then loreErrCount = loreErrCount + 1 end
    end
    t.eq(loreErrCount, 1, "lore_file 빈 칼럼(스테이지 2·3)은 통과, 값 있는 스테이지 1만 오류")
end
