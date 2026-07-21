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
    t.ok(tut:allows("x") == false, "제한 스텝에서 plain x는 allow 목록에 없으면 차단")
    t.ok(tut:allows("x", true), "Ctrl+X는 항상 통과")
    t.ok(tut:allows("return"), "제한 스텝에서도 Enter는 항상 통과")
    t.ok(tut:allows("escape"), "제한 스텝에서도 ESC는 항상 통과")
    t.ok(not tut:allows("f5"), "제한 스텝에서 allow 목록 밖 키는 여전히 차단")
    t.ok(not tut:allowsText(), "textinput 토큰 없으면 문자 차단")
    tut:notify("built")
    t.ok(tut:allowsText(), "textinput 토큰 허용")
    tut:keypressed("f5")
    t.ok(tut:done(), "전 스텝 소진")

    -- 일반 "x" 키는 더 이상 스킵이 아니다 — 첫 스텝은 allow 없음(전부 허용)이므로
    -- allows는 통과하지만 keypressed는 skipped를 세우지 않는다.
    local tutX = Tutorial(steps)
    tutX:keypressed("x")
    t.ok(not tutX.skipped and not tutX:done(), "plain x는 스킵하지 않음")

    local tut2 = Tutorial(steps)
    tut2:keypressed("x", true)
    t.ok(tut2:done() and tut2.skipped, "Ctrl+X 스킵")

    -- allow = {} 는 always-pass(Enter/ESC/Ctrl+X)를 제외한 전부를 차단한다.
    local lockedSteps = {
        { text = "잠금", allow = {}, advance = { on = "enter" } },
    }
    local tut3 = Tutorial(lockedSteps)
    t.ok(not tut3:allows("a"), "allow={} 는 일반 문자 차단")
    t.ok(not tut3:allowsText(), "allow={} 는 textinput 차단")
    t.ok(tut3:allows("return"), "allow={} 에서도 Enter는 통과")
    t.ok(tut3:allows("escape"), "allow={} 에서도 ESC는 통과")
    t.ok(tut3:allows("x", true), "allow={} 에서도 Ctrl+X는 통과")

    t.ok(Tutorial.load(PROJECT_ROOT .. "/data/curriculum/tutorial_1.lua") ~= nil, "스텝 파일 로드")
    t.ok(Tutorial.load(PROJECT_ROOT .. "/없는파일.lua") == nil, "없는 파일 nil")
end
