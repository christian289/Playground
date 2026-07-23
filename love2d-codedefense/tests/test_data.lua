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
    -- origin 단언 보강: null-ptr(콤마 포함 따옴표 CSV 값)·concat-nil도 비어있지 않고
    -- enemies.csv 원문의 기대 문구를 포함하는지 확인한다.
    t.ok(type(d.enemies["null-ptr"].origin) == "string" and d.enemies["null-ptr"].origin ~= "",
        "null-ptr origin 비어있지 않은 문자열")
    t.ok(d.enemies["null-ptr"].origin:find("토니 호어", 1, true) ~= nil,
        "null-ptr origin에 기대 문구(토니 호어) 포함")
    t.ok(type(d.enemies["concat-nil"].origin) == "string" and d.enemies["concat-nil"].origin ~= "",
        "concat-nil origin 비어있지 않은 문자열")
    t.ok(d.enemies["concat-nil"].origin:find("Lua 런타임 오류 메시지", 1, true) ~= nil,
        "concat-nil origin에 기대 문구(Lua 런타임 오류 메시지) 포함")

    -- lore 콘텐츠 회귀: d.validate()는 lore_file "존재"만 검증하므로, 파일 안 문법 오류나
    -- briefing/postmortem 누락은 잡아내지 못한다. db.lua/states 쪽과 동일한 io.open+loadstring
    -- 패턴으로 각 스테이지의 lore 파일을 실제로 로드·실행해 스키마를 검증한다.
    local loreCount = 0
    for id, stage in pairs(d.stages) do
        if stage.lore_file and stage.lore_file ~= "" then
            loreCount = loreCount + 1
            local f = io.open(d.root .. "/data/" .. stage.lore_file, "rb")
            t.ok(f ~= nil, ("스테이지 %s lore 파일 열기(%s)"):format(id, stage.lore_file))
            if f then
                local src = f:read("*a")
                f:close()
                local chunk, cerr = loadstring(src, stage.lore_file)
                t.ok(chunk ~= nil,
                    ("스테이지 %s lore 파일 컴파일(%s): %s"):format(id, stage.lore_file, tostring(cerr)))
                if chunk then
                    local ok, lore = pcall(chunk)
                    t.ok(ok and type(lore) == "table",
                        ("스테이지 %s lore 파일 실행 → 테이블 반환(%s)"):format(id, stage.lore_file))
                    if ok and type(lore) == "table" then
                        t.ok(type(lore.briefing) == "string" and lore.briefing ~= "",
                            ("스테이지 %s lore.briefing 비어있지 않은 문자열"):format(id))
                        t.ok(type(lore.postmortem) == "string" and lore.postmortem ~= "",
                            ("스테이지 %s lore.postmortem 비어있지 않은 문자열"):format(id))
                    end
                end
            end
        end
    end
    t.ok(loreCount >= 12, ("lore_file이 채워진 스테이지 수 확인: %d개 검사"):format(loreCount))

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
