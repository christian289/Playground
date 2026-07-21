local Object = require("lib.classic")
local utf8 = require("utf8")

local Editor = Object:extend()

function Editor:new(x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
    self.lines = { "" }
    self.cr, self.cc = 1, 1     -- cc는 바이트 오프셋이 아니라 "글자" 인덱스
    self.scroll = 0
    self.quickbar = {}
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

function Editor:setText(s)
    self.lines = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do self.lines[#self.lines + 1] = line end
    if #self.lines == 0 then self.lines = { "" } end
    self.cr, self.cc = 1, 1
end

function Editor:getText()
    return table.concat(self.lines, "\n")
end

function Editor:textinput(ch)
    local cs = chars(self.lines[self.cr])
    table.insert(cs, self.cc, ch)
    self.lines[self.cr] = table.concat(cs)
    self.cc = self.cc + 1
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
end

function Editor:keypressed(key)
    local cs = chars(self.lines[self.cr])
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
        self.cr, self.cc = self.cr + 1, 1
    elseif key == "tab" then
        self:textinput(" "); self:textinput(" ")
    elseif key == "backspace" then
        if self.cc > 1 then
            table.remove(cs, self.cc - 1)
            self.lines[self.cr] = table.concat(cs)
            self.cc = self.cc - 1
        elseif self.cr > 1 then
            local prev = chars(self.lines[self.cr - 1])
            local newCc = #prev + 1
            self.lines[self.cr - 1] = self.lines[self.cr - 1] .. self.lines[self.cr]
            table.remove(self.lines, self.cr)
            self.cr, self.cc = self.cr - 1, newCc
        end
    elseif key == "delete" then
        if self.cc <= #cs then
            table.remove(cs, self.cc)
            self.lines[self.cr] = table.concat(cs)
        elseif self.cr < #self.lines then
            self.lines[self.cr] = self.lines[self.cr] .. self.lines[self.cr + 1]
            table.remove(self.lines, self.cr + 1)
        end
    end
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
    ["local"] = true, ["return"] = true, ["and"] = true, ["or"] = true, ["not"] = true }

function Editor:draw(fonts, focused)
    local lh = fonts.mono:getHeight() + 4
    local visible = math.floor(self.h / lh)
    if self.cr - 1 < self.scroll then self.scroll = self.cr - 1 end
    if self.cr > self.scroll + visible then self.scroll = self.cr - visible end

    love.graphics.setColor(0.08, 0.09, 0.12)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setFont(fonts.mono)
    love.graphics.setScissor(self.x, self.y, self.w, self.h)
    for i = 1, visible do
        local li = i + self.scroll
        local line = self.lines[li]
        if not line then break end
        local ly = self.y + (i - 1) * lh + 2
        love.graphics.setColor(0.4, 0.45, 0.5)
        love.graphics.print(("%3d"):format(li), self.x + 4, ly)
        -- 단순 하이라이트: 키워드만 색 구분
        local lx = self.x + 40
        for token, sep in line:gmatch("([^%s]*)(%s*)") do
            if token ~= "" then
                if KEYWORDS[token] then love.graphics.setColor(0.9, 0.55, 0.4)
                else love.graphics.setColor(0.85, 0.88, 0.92) end
                love.graphics.print(token, lx, ly)
                lx = lx + fonts.mono:getWidth(token)
            end
            lx = lx + fonts.mono:getWidth(sep)
        end
        -- 커서
        if focused and li == self.cr and (love.timer.getTime() * 2) % 2 < 1 then
            local cs = chars(line)
            local cx = self.x + 40 + fonts.mono:getWidth(joinRange(cs, 1, self.cc - 1))
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", cx, ly, 2, lh - 4)
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
