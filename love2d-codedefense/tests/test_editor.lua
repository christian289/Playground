return function(t)
    local Editor = require("src.editor")
    local ed = Editor(0, 0, 400, 300)

    ed:setText("abc")
    t.eq(ed:getText(), "abc", "setText/getText")
    t.eq(ed.cr, 1, "커서 행 초기화")

    ed:keypressed("end"); ed:textinput("d")
    t.eq(ed:getText(), "abcd", "textinput 삽입")

    ed:keypressed("return"); ed:textinput("x")
    t.eq(ed:getText(), "abcd\nx", "엔터 줄바꿈")
    t.eq(ed.cr, 2, "엔터 후 커서 행")

    ed:keypressed("backspace")
    t.eq(ed:getText(), "abcd\n", "백스페이스")
    ed:keypressed("backspace")
    t.eq(ed:getText(), "abcd", "줄 병합 백스페이스")

    ed:setText("한글 주석")
    ed:keypressed("end"); ed:textinput("!")
    t.eq(ed:getText(), "한글 주석!", "UTF-8 한글 뒤 삽입")
    ed:keypressed("backspace"); ed:keypressed("backspace")
    t.eq(ed:getText(), "한글 주", "UTF-8 한글 백스페이스(글자 단위)")

    ed:setText(""); ed:insert("function on_tick(self, world)\n  ${1}\nend")
    t.eq(ed:getText(), "function on_tick(self, world)\n  \nend", "insert가 ${1} 제거")
    t.eq(ed.cr, 2, "insert 후 커서가 ${1} 위치")

    ed:setQuickbar({ { key = "f1", label = "공격", text = "self:attack(world.nearest())" } })
    ed:setText("")
    t.ok(ed:quickbarPressed("f1"), "퀵바 f1 처리")
    t.eq(ed:getText(), "self:attack(world.nearest())", "퀵바 삽입")
    t.ok(not ed:quickbarPressed("f9"), "빈 슬롯은 false")

    local mono = function(s) local n = 0; for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end return n * 10 end
    local ed2 = Editor(0, 0, 400, 300)
    ed2:setText("build(1)\nlocal x = helper(w)")
    local ln, ci = ed2:charAt(40 + 25, 5, 18, mono)   -- 40px 여백 + 2.5글자 → 3번째 글자
    t.eq(ln, 1, "charAt 줄"); t.eq(ci, 3, "charAt 글자")
    t.eq(Editor.tokenAt("build(1)", 3), "build", "tokenAt 식별자")
    t.eq(Editor.tokenAt("local x = helper(w)", 12), "helper", "tokenAt 중간 위치")
    t.eq(Editor.tokenAt("build(1)", 6), nil, "괄호 위치는 nil")
end
