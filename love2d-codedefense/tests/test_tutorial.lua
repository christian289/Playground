return function(t)
    local Tutorial = require("src.tutorial")

    local steps = {
        { text = "안내1", advance = { on = "enter" } },
        { text = "버튼", allow = { "1" }, advance = { on = "event", event = "built" } },
        { text = "저장", allow = { "f5", "textinput" }, advance = { on = "key", key = "f5" } },
    }
    local tut = Tutorial(steps)

    t.ok(tut:allows("enter"), "Enter 항상 통과")
    t.ok(tut:allows("escape"), "ESC 항상 통과")
    t.ok(tut:allows("anything"), "allow 없는 스텝은 전부 허용")
    tut:keypressed("return")
    t.ok(tut:allows("1") and not tut:allows("f5"), "allow 게이팅")
    t.ok(not tut:allowsText(), "textinput 토큰 없으면 문자 차단")
    tut:notify("built")
    t.ok(tut:allowsText(), "textinput 토큰 허용")
    tut:keypressed("f5")
    t.ok(tut:done(), "전 스텝 소진")

    local tut2 = Tutorial(steps)
    tut2:keypressed("x")
    t.ok(tut2:done() and tut2.skipped, "X 스킵")

    t.ok(Tutorial.load(PROJECT_ROOT .. "/data/curriculum/tutorial_1.lua") ~= nil, "스텝 파일 로드")
    t.ok(Tutorial.load(PROJECT_ROOT .. "/없는파일.lua") == nil, "없는 파일 nil")
end
