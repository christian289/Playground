local Object = require("lib.classic")
local utf8 = require("utf8")

local Editor = Object:extend()

function Editor:new(x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
    self.lines = { "" }
    self.cr, self.cc = 1, 1     -- cc는 바이트 오프셋이 아니라 "글자" 인덱스
    self.scroll = 0
    self.quickbar = {}
    self.lineClipboard = nil
    self.history, self.historyIndex = {}, 0
    self:_record()
end

-- 글자 배열 유틸 (UTF-8 안전)
local function chars(s)
    local out = {}
    for _, cp in utf8.codes(s) do out[#out + 1] = utf8.char(cp) end
    return out
end
local function joinRange(cs, a, b)
    return table.concat(cs, "", a, b)
end

-- 원본 줄은 보존한 채, 표시 폭을 넘지 않는 UTF-8 안전한 조각으로 나눈다.
function Editor.wrapLine(line, maxWidth, measure)
    local wrapped, current = {}, ""
    for _, ch in ipairs(chars(line)) do
        if current ~= "" and measure(current .. ch) > maxWidth then
            wrapped[#wrapped + 1] = current
            current = ch
        else
            current = current .. ch
        end
    end
    wrapped[#wrapped + 1] = current
    return wrapped
end

function Editor:displayLines(maxWidth, measure)
    local displayed = {}
    for source, line in ipairs(self.lines) do
        local start = 1
        for _, text in ipairs(Editor.wrapLine(line, maxWidth, measure)) do
            displayed[#displayed + 1] = { source = source, start = start, text = text }
            start = start + #chars(text)
        end
    end
    return displayed
end

function Editor:setText(s)
    self.lines = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do self.lines[#self.lines + 1] = line end
    if #self.lines == 0 then self.lines = { "" } end
    self.cr, self.cc = 1, 1
    self.history, self.historyIndex = {}, 0
    self:_record()
end

function Editor:getText()
    return table.concat(self.lines, "\n")
end

function Editor:_snapshot()
    return { text = self:getText(), cr = self.cr, cc = self.cc }
end

function Editor:_record()
    local current = self:_snapshot()
    local previous = self.history[self.historyIndex]
    if previous and previous.text == current.text and previous.cr == current.cr and previous.cc == current.cc then return end
    for i = #self.history, self.historyIndex + 1, -1 do self.history[i] = nil end
    self.historyIndex = self.historyIndex + 1
    self.history[self.historyIndex] = current
end

function Editor:_restore(snapshot)
    self.lines = {}
    for line in (snapshot.text .. "\n"):gmatch("(.-)\n") do self.lines[#self.lines + 1] = line end
    self.cr, self.cc = snapshot.cr, snapshot.cc
end

function Editor:undo()
    if self.historyIndex <= 1 then return false end
    self.historyIndex = self.historyIndex - 1
    self:_restore(self.history[self.historyIndex])
    return true
end

function Editor:redo()
    if self.historyIndex >= #self.history then return false end
    self.historyIndex = self.historyIndex + 1
    self:_restore(self.history[self.historyIndex])
    return true
end

function Editor:reload(path, readFile)
    local text = readFile(path)
    if type(text) ~= "string" then return false end
    self:setText(text)
    return true
end

function Editor:textinput(ch)
    local cs = chars(self.lines[self.cr])
    table.insert(cs, self.cc, ch)
    self.lines[self.cr] = table.concat(cs)
    self.cc = self.cc + 1
    self:_record()
end

function Editor:insert(s)
    -- 여러 줄 삽입 + ${1} 커서 마커
    local markR, markC
    local first = true
    for line in (s .. "\n"):gmatch("(.-)\n") do
        local m = line:find("%${1}", 1, false)
        if m then
            local before = line:sub(1, m - 1)
            markC = #chars(before) + 1
            line = line:gsub("%${1}", "", 1)
        end
        if first then
            local cs = chars(self.lines[self.cr])
            local left = joinRange(cs, 1, self.cc - 1)
            local right = joinRange(cs, self.cc, #cs)
            self.lines[self.cr] = left .. line
            self._tail = right
            if markC then markR, markC = self.cr, #chars(left) + markC end
            first = false
        else
            self.cr = self.cr + 1
            table.insert(self.lines, self.cr, line)
            if markC and not markR then markR = self.cr end
        end
    end
    self.lines[self.cr] = self.lines[self.cr] .. (self._tail or "")
    self._tail = nil
    if markR then self.cr, self.cc = markR, markC
    else self.cc = #chars(self.lines[self.cr]) + 1 end
    self:_record()
end

local function isWordChar(ch)
    return ch:match("[%w_]") ~= nil or (not ch:match("%s") and not ch:match("[%p]"))
end

function Editor:deleteWordBackward()
    local cs = chars(self.lines[self.cr])
    local stop = self.cc - 1
    while stop > 0 and cs[stop]:match("%s") do stop = stop - 1 end
    while stop > 0 and isWordChar(cs[stop]) do stop = stop - 1 end
    if stop == self.cc - 1 then return false end
    for _ = stop + 1, self.cc - 1 do table.remove(cs, stop + 1) end
    self.lines[self.cr], self.cc = table.concat(cs), stop + 1
    self:_record()
    return true
end

function Editor:deleteWordForward()
    local cs = chars(self.lines[self.cr])
    local stop = self.cc
    while stop <= #cs and cs[stop]:match("%s") do stop = stop + 1 end
    while stop <= #cs and isWordChar(cs[stop]) do stop = stop + 1 end
    if stop == self.cc then return false end
    for _ = self.cc, stop - 1 do table.remove(cs, self.cc) end
    self.lines[self.cr] = table.concat(cs)
    self:_record()
    return true
end

function Editor:cutLine()
    self.lineClipboard = self.lines[self.cr]
    table.remove(self.lines, self.cr)
    if #self.lines == 0 then self.lines[1] = ""; self.cr = 1
    elseif self.cr > #self.lines then self.cr = #self.lines end
    self.cc = 1
    self:_record()
    return true
end

function Editor:pasteLine()
    if self.lineClipboard == nil then return false end
    table.insert(self.lines, self.cr + 1, self.lineClipboard)
    self.cr, self.cc = self.cr + 1, 1
    self:_record()
    return true
end

function Editor:keypressed(key, ctrl)
    if ctrl then
        if key == "z" then return self:undo()
        elseif key == "y" then return self:redo()
        elseif key == "backspace" then return self:deleteWordBackward()
        elseif key == "delete" then return self:deleteWordForward()
        elseif key == "k" then return self:cutLine()
        elseif key == "u" then return self:pasteLine()
        end
        return false
    end

    local cs = chars(self.lines[self.cr])
    local changed = false
    if key == "left" then
        if self.cc > 1 then self.cc = self.cc - 1
        elseif self.cr > 1 then self.cr = self.cr - 1; self.cc = #chars(self.lines[self.cr]) + 1 end
    elseif key == "right" then
        if self.cc <= #cs then self.cc = self.cc + 1
        elseif self.cr < #self.lines then self.cr = self.cr + 1; self.cc = 1 end
    elseif key == "up" and self.cr > 1 then
        self.cr = self.cr - 1
        self.cc = math.min(self.cc, #chars(self.lines[self.cr]) + 1)
    elseif key == "down" and self.cr < #self.lines then
        self.cr = self.cr + 1
        self.cc = math.min(self.cc, #chars(self.lines[self.cr]) + 1)
    elseif key == "home" then self.cc = 1
    elseif key == "end" then self.cc = #cs + 1
    elseif key == "return" then
        local left = joinRange(cs, 1, self.cc - 1)
        local right = joinRange(cs, self.cc, #cs)
        self.lines[self.cr] = left
        table.insert(self.lines, self.cr + 1, right)
        self.cr, self.cc, changed = self.cr + 1, 1, true
    elseif key == "tab" then
        table.insert(cs, self.cc, " "); table.insert(cs, self.cc + 1, " ")
        self.lines[self.cr], self.cc, changed = table.concat(cs), self.cc + 2, true
    elseif key == "backspace" then
        if self.cc > 1 then
            table.remove(cs, self.cc - 1)
            self.lines[self.cr] = table.concat(cs)
            self.cc, changed = self.cc - 1, true
        elseif self.cr > 1 then
            local prev = chars(self.lines[self.cr - 1])
            local newCc = #prev + 1
            self.lines[self.cr - 1] = self.lines[self.cr - 1] .. self.lines[self.cr]
            table.remove(self.lines, self.cr)
            self.cr, self.cc, changed = self.cr - 1, newCc, true
        end
    elseif key == "delete" then
        if self.cc <= #cs then
            table.remove(cs, self.cc)
            self.lines[self.cr], changed = table.concat(cs), true
        elseif self.cr < #self.lines then
            self.lines[self.cr] = self.lines[self.cr] .. self.lines[self.cr + 1]
            table.remove(self.lines, self.cr + 1)
            changed = true
        end
    end
    if changed then self:_record() end
    return changed
end

-- 에디터 내부 좌표(px, py는 에디터 원점 기준)를 (줄, 글자 인덱스)로 변환한다.
-- lineH는 draw()가 쓰는 lineHeight를 그대로 주입받고, measure(str)는 픽셀 폭을 반환하는 함수다.
-- 줄 번호 여백(40px) 안쪽을 클릭하거나 존재하지 않는 줄이면 nil.
function Editor:charAt(px, py, lineH, measure)
    local displayed = self:displayLines(self.w - 46, measure)
    local row = displayed[math.floor(py / lineH) + 1 + self.scroll]
    if not row then return nil end
    local x = px - 40
    if x < 0 then return nil end
    local cs = chars(row.text)
    local acc = 0
    for i = 1, #cs do
        local w = measure(cs[i])
        if x < acc + w then return row.source, row.start + i - 1 end
        acc = acc + w
    end
    return row.source, row.start + #cs
end

function Editor:moveCursorAt(px, py, lineH, measure)
    local line, column = self:charAt(px, py, lineH, measure)
    if not line then return false end
    self.cr, self.cc = line, column
    return true
end

-- lineText에서 charIdx(1-based) 위치를 포함하는 식별자 토큰([%a_][%w_]*)을 반환한다.
-- charIdx와 반환한 범위는 모두 UTF-8 글자 인덱스이며, byteStart는 앞 문맥을 읽을 때만 쓴다.
function Editor.tokenAt(lineText, charIdx)
    if not charIdx then return nil end
    for byteStart, tok, byteEnd in lineText:gmatch("()([%a_][%w_]*)()") do
        local charStart = #chars(lineText:sub(1, byteStart - 1)) + 1
        local charEnd = charStart + #chars(tok)
        if charIdx >= charStart and charIdx < charEnd then
            return tok, charStart, charEnd, byteStart
        end
    end
    return nil
end

-- 현재 줄에서 커서 이전 텍스트(UTF-8 안전)를 반환한다 — 뷰가 커서의 픽셀 x 위치를 폭 측정으로
-- 계산할 때 재사용한다(예: states/play.lua의 셸 터미널 입력 줄 커서 렌더).
function Editor:textBeforeCursor()
    local cs = chars(self.lines[self.cr])
    return joinRange(cs, 1, self.cc - 1)
end

function Editor:setQuickbar(slots) self.quickbar = slots end

function Editor:quickbarPressed(key)
    for _, slot in ipairs(self.quickbar) do
        if slot.key == key then self:insert(slot.text) return true end
    end
    return false
end

local KEYWORDS = { ["function"] = true, ["end"] = true, ["if"] = true, ["then"] = true,
    ["else"] = true, ["elseif"] = true, ["for"] = true, ["while"] = true, ["do"] = true,
    ["local"] = true, ["return"] = true, ["and"] = true, ["or"] = true, ["not"] = true,
    ["true"] = true, ["false"] = true, ["nil"] = true, ["break"] = true, ["repeat"] = true, ["until"] = true }
local API_ROOTS = { build = true, demolish = true, self = true, world = true, cache = true, on_spawn = true }
local API_METHODS = {
    ["self:attack"] = true, ["world.enemies"] = true, ["world.nearest"] = true,
    ["world.weakest"] = true, ["world.fastest"] = true, ["world.oldest"] = true,
    ["cache.get"] = true, ["cache.set"] = true,
}
local TOKEN_COLORS = {
    plain = { 0.85, 0.88, 0.92 }, comment = { 0.42, 0.62, 0.48 }, string = { 0.85, 0.7, 0.42 },
    number = { 0.68, 0.76, 0.98 }, keyword = { 0.9, 0.55, 0.4 }, declaration = { 0.46, 0.86, 0.95 },
    call = { 0.75, 0.7, 0.98 }, basicApi = { 0.35, 0.95, 0.77 }, property = { 0.7, 0.8, 0.86 },
    placeholder = { 1, 0.94, 0.5 },
}

function Editor.lexLine(line)
    local tokens, i, previous, lastName, separator = {}, 1, nil, nil, nil
    local function add(kind, text)
        local token = { kind = kind, text = text }
        tokens[#tokens + 1] = token
        return token
    end
    while i <= #line do
        local rest = line:sub(i)
        if rest:sub(1, 2) == "--" then
            add("comment", rest)
            break
        elseif rest:sub(1, 6) == "______" then
            add("placeholder", "______")
            i = i + 6
        else
            local quote = rest:sub(1, 1)
            if quote == '"' or quote == "'" then
                local j = i + 1
                while j <= #line do
                    local ch = line:sub(j, j)
                    if ch == "\\" then j = j + 2
                    elseif ch == quote then j = j + 1; break
                    else j = j + 1 end
                end
                add("string", line:sub(i, j - 1))
                i = j
            else
                local number = rest:match("^(%d+%.?%d*)")
                local word = rest:match("^([%a_][%w_]*)")
                if number then
                    add("number", number)
                    i = i + #number
                    separator = nil
                elseif word then
                    local qualified = separator and lastName and lastName .. separator.text .. word
                    local kind
                    if KEYWORDS[word] then kind = "keyword"
                    elseif previous and previous.kind == "keyword" and previous.text == "function" then kind = "declaration"
                    elseif API_ROOTS[word] or (qualified and API_METHODS[qualified]) then kind = "basicApi"
                    elseif separator and (separator.text == "." or separator.text == ":") then kind = "property"
                    elseif line:sub(i + #word):match("^%s*%(") then kind = "call"
                    else kind = "plain" end
                    local token = add(kind, word)
                    previous, lastName, separator = token, word, nil
                    i = i + #word
                else
                    local nextPos = utf8.offset(line, 2, i) or (#line + 1)
                    local text = line:sub(i, nextPos - 1)
                    local token = add("plain", text)
                    if text == "." or text == ":" then separator = token else separator = nil end
                    if not text:match("%s") then previous = token end
                    i = nextPos
                end
            end
        end
    end
    return tokens
end

function Editor:draw(fonts, focused)
    local lh = fonts.mono:getHeight() + 4
    local visible = math.floor(self.h / lh)
    local displayed = self:displayLines(self.w - 46, function(s) return fonts.mono:getWidth(s) end)
    local cursorDisplay
    for i, row in ipairs(displayed) do
        local length = #chars(row.text)
        if row.source == self.cr and self.cc >= row.start and self.cc <= row.start + length then
            cursorDisplay = i
            break
        end
    end
    if cursorDisplay and cursorDisplay - 1 < self.scroll then self.scroll = cursorDisplay - 1 end
    if cursorDisplay and cursorDisplay > self.scroll + visible then self.scroll = cursorDisplay - visible end

    love.graphics.setColor(0.08, 0.09, 0.12)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setFont(fonts.mono)
    love.graphics.setScissor(self.x, self.y, self.w, self.h)
    for i = 1, visible do
        local row = displayed[i + self.scroll]
        if not row then break end
        local ly = self.y + (i - 1) * lh + 2
        love.graphics.setColor(0.4, 0.45, 0.5)
        love.graphics.print(("%3d"):format(row.source), self.x + 4, ly)
        local lx = self.x + 40
        for _, token in ipairs(Editor.lexLine(row.text)) do
            local width = fonts.mono:getWidth(token.text)
            if token.kind == "placeholder" then
                love.graphics.setColor(0.45, 0.34, 0.08)
                love.graphics.rectangle("fill", lx - 2, ly - 1, width + 4, lh - 2, 2)
                love.graphics.setColor(1, 0.82, 0.18)
                love.graphics.rectangle("line", lx - 2, ly - 1, width + 4, lh - 2, 2)
            end
            local color = TOKEN_COLORS[token.kind] or TOKEN_COLORS.plain
            love.graphics.setColor(color[1], color[2], color[3])
            love.graphics.print(token.text, lx, ly)
            lx = lx + width
        end
        if focused and i + self.scroll == cursorDisplay and (love.timer.getTime() * 2) % 2 < 1 then
            local prefix = joinRange(chars(row.text), 1, self.cc - row.start)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", self.x + 40 + fonts.mono:getWidth(prefix), ly, 2, lh - 4)
        end
    end
    love.graphics.setScissor()

    -- 퀵바
    local qy = self.y + self.h + 6
    for i, slot in ipairs(self.quickbar) do
        local qx = self.x + (i - 1) * 92
        love.graphics.setColor(0.16, 0.18, 0.24)
        love.graphics.rectangle("fill", qx, qy, 86, 26, 4)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.95, 0.8, 0.4)
        love.graphics.print(slot.key:upper(), qx + 5, qy + 5)
        love.graphics.setColor(0.85, 0.88, 0.92)
        love.graphics.print(slot.label, qx + 30, qy + 5)
    end
end

return Editor
