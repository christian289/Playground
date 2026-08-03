-- Wave D Task 3: src/factions.lua 순수 로직(진영 필터 + 언락) 헤드리스 테스트.
-- states/stageselect.lua가 그대로 위임하는 모듈이라, 여기서 검증하면 뷰(love 필요)를 띄우지
-- 않고도 "진영 내 목록 이전 항목 클리어" 언락 규칙과 전역 id-1 참조 버그의 부재를 증명할 수 있다.
return function(t)
    local factions = require("src.factions")

    ------------------------------------------------------------------
    -- ① languageOf: 빈 값/nil → "lua", 그 외는 그대로
    ------------------------------------------------------------------
    t.eq(factions.languageOf({ languages = "" }), "lua", "①: languages 빈 문자열 → lua")
    t.eq(factions.languageOf({ languages = nil }), "lua", "①: languages 필드 자체가 없어도(구 CSV 호환) → lua")
    t.eq(factions.languageOf({ languages = "lua" }), "lua", "①: languages=lua 그대로")
    t.eq(factions.languageOf({ languages = "shell" }), "shell", "①: languages=shell 그대로")

    ------------------------------------------------------------------
    -- ② idsFor: 실제 stages.csv와 동일한 모양(불연속 id를 섞은 합성 데이터)으로 진영별 분리 확인
    --    — Lua 1~20(languages="lua") + 셸 101~103(languages="shell") 혼재, mode!="normal"은 제외.
    ------------------------------------------------------------------
    local stages = {}
    for id = 1, 20 do stages[id] = { id = id, mode = "normal", languages = "lua" } end
    for id = 101, 103 do stages[id] = { id = id, mode = "normal", languages = "shell" } end
    stages[999] = { id = 999, mode = "bonus", languages = "shell" } -- mode!=normal은 어느 진영에도 안 잡힘

    local luaIds = factions.idsFor(stages, "lua")
    local shellIds = factions.idsFor(stages, "shell")
    t.eq(#luaIds, 20, "②: lua 진영 20개")
    t.eq(luaIds[1], 1, "②: lua 진영 첫 id=1")
    t.eq(luaIds[20], 20, "②: lua 진영 마지막 id=20(오름차순 정렬 확인)")
    t.eq(#shellIds, 3, "②: shell 진영 3개(999 mode=bonus 제외)")
    t.eq(shellIds[1], 101, "②: shell 진영 첫 id=101")
    t.eq(shellIds[3], 103, "②: shell 진영 마지막 id=103")

    ------------------------------------------------------------------
    -- ③ unlocked: 진영 내 목록 이전 항목 클리어 기준 — 핵심은 "셸 101이 Lua 20 클리어와
    --    무관하게 언락되는가"(전역 id-1 참조였다면 100(없음)이 이전 항목이 되어 영구 잠기거나,
    --    실제 리스트 전역 정렬이었다면 101의 "리스트상 이전"이 Lua 20이 되어 버렸을 상황).
    ------------------------------------------------------------------
    local clearedNone = {}
    t.ok(factions.unlocked(shellIds, clearedNone, 101), "③: shell 진영 첫 항목(101)은 아무것도 안 깨도 언락")
    t.ok(not factions.unlocked(shellIds, clearedNone, 102), "③: 102는 101 클리어 전엔 잠김")

    local clearedLuaOnly = { [20] = true } -- Lua 전체 클리어, 셸은 아무것도 안 함
    t.ok(not factions.unlocked(shellIds, clearedLuaOnly, 102),
        "③: Lua 20 전부 클리어해도 셸 102는 안 풀림(진영이 섞이지 않음 — 버그 재발 방지 핵심 단언)")

    local clearedShell101 = { [101] = true }
    t.ok(factions.unlocked(shellIds, clearedShell101, 102), "③: 셸 101 클리어 → 셸 102 언락")
    t.ok(not factions.unlocked(shellIds, clearedShell101, 103), "③: 101만 클리어로는 103은 아직 잠김(102 미클리어)")

    -- Lua 진영 자체의 실효 동작 불변: 기존과 동일하게 "바로 이전 id 클리어"만 보면 됨(연속 id라
    -- 리스트 인접 참조와 id-1 참조가 결과적으로 일치 — 리팩터 전후 동일 동작임을 여기서 증명).
    t.ok(factions.unlocked(luaIds, {}, 1), "③: Lua 1은 항상 언락")
    t.ok(not factions.unlocked(luaIds, {}, 2), "③: Lua 2는 1 클리어 전엔 잠김")
    t.ok(factions.unlocked(luaIds, { [1] = true }, 2), "③: Lua 1 클리어 → 2 언락")
    t.ok(not factions.unlocked(luaIds, { [1] = true }, 3), "③: 1만 클리어로는 3은 잠김(2 미클리어)")
    t.ok(not factions.unlocked(luaIds, { [1] = true, [2] = true, [3] = true }, 5),
        "③: 4를 건너뛰고 5까지 못 감(연쇄가 끊기면 그 뒤는 계속 잠김)")

    -- 목록에 없는 id(다른 진영/비정상 값)는 항상 잠김
    t.ok(not factions.unlocked(luaIds, { [200] = true }, 999), "③: 목록 밖 id는 항상 잠김")
end
