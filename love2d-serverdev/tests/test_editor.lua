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
    local wrapped = Editor.wrapLine("주석이 아주 길어서 화면 폭을 넘습니다", 60, function(s) return #s * 10 end)
    t.eq(table.concat(wrapped), "주석이 아주 길어서 화면 폭을 넘습니다", "자동 줄바꿈은 원본 텍스트를 보존")
    t.ok(#wrapped > 1, "긴 줄은 여러 표시 줄로 나뉨")

    local mono = function(s) local n = 0; for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end return n * 10 end
    local ed2 = Editor(0, 0, 400, 300)
    ed2:setText("build(1)\nlocal x = helper(w)")
    local ln, ci = ed2:charAt(40 + 25, 5, 18, mono)   -- 40px 여백 + 2.5글자 → 3번째 글자
    t.eq(ln, 1, "charAt 줄"); t.eq(ci, 3, "charAt 글자")
    t.eq(Editor.tokenAt("build(1)", 3), "build", "tokenAt 식별자")
    t.eq(Editor.tokenAt("local x = helper(w)", 12), "helper", "tokenAt 중간 위치")
    t.eq(Editor.tokenAt("build(1)", 6), nil, "괄호 위치는 nil")

    local lnE, ciE = ed2:charAt(40 + 300, 5, 18, mono)
    t.eq(lnE, 1, "줄끝 초과 클릭 줄")
    t.eq(ciE, 9, "줄끝 초과는 마지막+1")   -- "build(1)" = 8글자 → 9
    ed2:setText("가나다")
    t.ok(ed2:moveCursorAt(40 + 15, 5, 18, mono), "UTF-8 클릭 커서 이동 처리")
    t.eq(ed2.cc, 2, "UTF-8 클릭은 둘째 글자 앞으로")
    local ed3 = Editor(0, 0, 400, 300)
    ed3:setText("한글 alpha beta")
    ed3:keypressed("end")
    ed3:keypressed("backspace", true)
    t.eq(ed3:getText(), "한글 alpha ", "Ctrl+Backspace 단어 삭제")
    ed3:keypressed("z", true)
    t.eq(ed3:getText(), "한글 alpha beta", "Ctrl+Z undo")
    ed3:keypressed("y", true)
    t.eq(ed3:getText(), "한글 alpha ", "Ctrl+Y redo")
    ed3:setText("alpha beta")
    ed3:keypressed("delete", true)
    t.eq(ed3:getText(), " beta", "Ctrl+Delete 다음 단어 삭제")

    ed3:setText("첫 줄\n둘째 줄")
    ed3.cr, ed3.cc = 2, 3
    ed3:keypressed("k", true)
    t.eq(ed3:getText(), "첫 줄", "Ctrl+K 현재 줄 잘라내기")
    ed3:keypressed("u", true)
    t.eq(ed3:getText(), "첫 줄\n둘째 줄", "Ctrl+U 잘라낸 줄 붙여넣기")

    local kinds = {}
    for _, token in ipairs(Editor.lexLine('function deploy() local target = world.nearest(); helper(); local missing = ______ -- 메모')) do
        kinds[token.kind] = (kinds[token.kind] or 0) + 1
    end
    t.ok(kinds.keyword and kinds.declaration and kinds.call and kinds.basicApi and kinds.comment and kinds.placeholder,
        "Lua 토큰과 placeholder 분류")
    local stringKinds = {}
    for _, token in ipairs(Editor.lexLine('local n = 42; local label = "문자열"; self.range = n')) do
        stringKinds[token.kind] = true
    end
    t.ok(stringKinds.number and stringKinds.string and stringKinds.property, "숫자·문자열·속성 분류")

    local reloaded = ed3:reload("연습 힌트", function(path)
        t.eq(path, "연습 힌트", "외부 힌트 다시 불러오기 경로")
        return "build(______)"
    end)
    t.ok(reloaded, "외부 힌트 다시 불러오기 성공")
    local play = require("states.play")
    local reloadedPath, reloadedText
    local reloader = {
        reload = function(_, path, readFile)
            reloadedPath, reloadedText = path, readFile(path)
            return type(reloadedText) == "string"
        end,
    }
    local state = { stage = { hints_file = "curriculum/005_hints.lua" }, d = { root = PROJECT_ROOT }, editor = reloader }
    t.ok(play.reloadHint(state), "Ctrl+Shift+R 힌트 파일 다시 불러오기")
    t.eq(reloadedPath, "curriculum/005_hints.lua", "게임 상태가 힌트 경로 전달")
    t.ok(#reloadedText > 0, "게임 상태가 외부 힌트 내용을 전달")
    t.eq(ed3:getText(), "build(______)", "외부 힌트 내용 적용")
    local Tutorial = require("src.tutorial")
    local fonts = require("src.fonts")
    local function loadTutorial(name)
        return assert(loadfile(PROJECT_ROOT .. "/data/curriculum/" .. name))()
    end
    local oldIsDown = love.keyboard.isDown
    local ctrl, shift = true, false
    love.keyboard.isDown = function(key)
        return (ctrl and (key == "lctrl" or key == "rctrl")) or
            (shift and (key == "lshift" or key == "rshift"))
    end
    local function editingState(steps)
        local tutorial = Tutorial(steps)
        tutorial.idx = #steps
        local input = Editor(100, 100, 400, 300)
        input:setText("첫 줄\n둘째 줄")
        input.cr, input.cc = 2, 3
        return setmetatable({
            stage = { ui = "code" },
            tut = tutorial,
            editor = input,
            battle = { userFuncs = {} },
            showBrief = false,
            save = function(self) self.saved = (self.saved or 0) + 1 end,
            reloadHint = function(self) self.reloaded = (self.reloaded or 0) + 1 end,
        }, { __index = play })
    end
    for _, tutorialName in ipairs({ "tutorial_3.lua", "tutorial_4.lua" }) do
        local steps = loadTutorial(tutorialName)
        local saved = editingState(steps)
        play.keypressed(saved, "s")
        t.eq(saved.saved, 1, tutorialName .. " 편집 단계 Ctrl+S가 저장까지 도달")

        local cut = editingState(steps)
        play.keypressed(cut, "k")
        t.eq(cut.editor:getText(), "첫 줄", tutorialName .. " 편집 단계 Ctrl+K가 에디터까지 도달")
        play.keypressed(cut, "u")
        t.eq(cut.editor:getText(), "첫 줄\n둘째 줄", tutorialName .. " 편집 단계 Ctrl+U가 에디터까지 도달")

        local undo = editingState(steps)
        undo.editor:setText("alpha")
        undo.editor:keypressed("end")
        undo.editor:textinput("!")
        play.keypressed(undo, "z")
        t.eq(undo.editor:getText(), "alpha", tutorialName .. " 편집 단계 Ctrl+Z가 에디터까지 도달")
        play.keypressed(undo, "y")
        t.eq(undo.editor:getText(), "alpha!", tutorialName .. " 편집 단계 Ctrl+Y가 에디터까지 도달")

        local words = editingState(steps)
        words.editor:setText("alpha beta")
        words.editor:keypressed("end")
        play.keypressed(words, "backspace")
        t.eq(words.editor:getText(), "alpha ", tutorialName .. " 편집 단계 Ctrl+Backspace가 에디터까지 도달")
        words.editor:setText("alpha beta")
        play.keypressed(words, "delete")
        t.eq(words.editor:getText(), " beta", tutorialName .. " 편집 단계 Ctrl+Delete가 에디터까지 도달")

        local reload = editingState(steps)
        shift = true
        play.keypressed(reload, "r")
        shift = false
        t.eq(reload.reloaded, 1, tutorialName .. " 편집 단계 Ctrl+Shift+R가 힌트를 다시 불러온다")
    end
    local locked = editingState(loadTutorial("tutorial_3.lua"))
    locked.tut.idx = 1
    play.keypressed(locked, "k")
    t.eq(locked.editor:getText(), "첫 줄\n둘째 줄", "설명 단계는 Ctrl+K를 계속 차단한다")
    t.eq(locked.tutShake, 0.3, "설명 단계의 차단 피드백을 유지한다")

    local previousMono = fonts.mono
    fonts.mono = {
        getHeight = function() return 10 end,
        getWidth = function(_, s)
            local count = 0
            for _ in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do count = count + 1 end
            return count * 10
        end,
    }
    local clickState = setmetatable({
        stage = { ui = "code" },
        editor = Editor(100, 100, 400, 300),
        battle = { userFuncs = {} },
        showBrief = false,
    }, { __index = play })
    clickState.editor:setText('local s = "한글"; build(1)')
    local pacing = setmetatable({
        p = { play_speed = 1 },
        battle = { finishEarly = function(self) self.finished = true; return true end },
        showBrief = false,
    }, { __index = play })
    ctrl = true
    play.keypressed(pacing, "4")
    t.eq(pacing.p.play_speed, 4, "배속 변경은 다음 스테이지에도 저장")
    play.keypressed(pacing, "return")
    t.ok(pacing.battle.finished, "Ctrl+Enter는 가능한 조기 종료를 요청")
    play.mousepressed(clickState, 100 + 40 + 18 * 10 + 5, 105, 1)
    t.eq(clickState.dictOpen, "build", "한글 앞 텍스트 뒤 Ctrl+클릭이 build 토큰을 연다")
    ctrl = false
    fonts.mono = previousMono
    love.keyboard.isDown = oldIsDown
end
