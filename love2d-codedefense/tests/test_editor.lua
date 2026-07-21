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
end
