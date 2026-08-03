return function(t)
    local Cutscene = require("src.cutscene")
    local cs = Cutscene({ { text = "가나다라" }, { text = "마바" } })

    t.eq(cs:sceneIndex(), 1, "장면 1 시작")
    t.eq(cs:visibleText(), "", "타이핑 전 빈 텍스트")
    cs:update(2 / 30)
    t.eq(cs:visibleText(), "가나", "초당 30자 타이프라이터")
    cs:press()
    t.eq(cs:visibleText(), "가나다라", "타이핑 중 press = 전체 표시")
    cs:press()
    t.eq(cs:sceneIndex(), 2, "완료 후 press = 다음 장면")
    t.ok(not cs:done(), "아직 안 끝남")
    cs:press()  -- 장면2 전체 표시
    cs:press()  -- 장면2 넘김
    t.ok(cs:done(), "마지막 장면 넘기면 done")

    local cs2 = Cutscene({ { text = "가" }, { text = "나" } })
    cs2:skip()
    t.ok(cs2:done(), "skip 즉시 done")
end
