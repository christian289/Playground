return function(t)
    local Practice = require("states.editorpractice")
    local data = Practice.load(PROJECT_ROOT)
    t.eq(data.narrative, "새벽 교대 전 서버실에서 에디터를 점검한다.", "워밍업 서사 로드")
    t.eq(#data.documents, 3, "가상 연습 문서 세 개")
    t.eq(data.documents[1].name, "README.md", "첫 문서는 README")
    t.ok(data.documents[2].text:find("self:attack", 1, true) ~= nil, "Lua 연습 문서에 API 예시")
    local legacy = Practice.ensureDocuments({ steps = {} })
    t.eq(legacy.documents[1].name, "README.md", "구 배포 데이터도 기본 작업공간 문서로 복구")

    local session = Practice.new(data.documents)
    t.eq(session:current().name, "README.md", "첫 연습 문서")
    session:advance()
    t.eq(session:current().name, "deploy.lua", "다음 문서로 이동")
    for _ = 2, #data.documents do session:advance() end
    t.ok(session:done(), "마지막 연습 문서 뒤 종료")

    local live = setmetatable({}, { __index = Practice })
    Practice.enter(live, nil, { root = PROJECT_ROOT }, {})
    t.ok(live.battle == nil and live.timer == nil and live.enemies == nil, "워밍업은 전투 타이머·적 없이 시작")
    t.eq(live.editor:getText(), data.documents[1].text, "첫 문서를 편집기에 연다")

    local fonts = require("src.fonts")
    local fakeFont = { getHeight = function() return 10 end }
    fonts.title, fonts.subtitle, fonts.ui = fakeFont, fakeFont, fakeFont
    local title = require("states.title")
    t.eq(title.nextStartState({ editor_practice_done = false }), "states.faction", "게임 시작은 항상 진영 흐름")
    t.eq(title.nextStartState({ editor_practice_done = true }), "states.faction", "진행도와 무관하게 기존 진영 흐름")

    local oldIsDown = love.keyboard.isDown
    love.keyboard.isDown = function() return false end
    Practice.keypressed(live, "f2")
    t.eq(live.session:current().name, "deploy.lua", "F2로 Lua 연습 문서 열기")
    Practice.textinput(live, " ")
    Practice.saveCurrent(live, true)
    t.eq(live.documents[2].saved, live.editor:getText(), "저장은 가상 작업공간에만 반영")
    love.keyboard.isDown = oldIsDown
end
