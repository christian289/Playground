local Gamestate = require("lib.hump.gamestate")
local Editor = require("src.editor")
local fonts = require("src.fonts")
local art = require("src.art")

local editorpractice = {}
local Session = {}
Session.__index = Session

local DEFAULT_DOCUMENTS = {
    {
        name = "README.md",
        text = "# 서버실 편집기\n\n이 작업공간은 Nano를 내장하지 않고, Nano의 단순한 편집 경험을 따라 구현했습니다.\n\nF1~F3으로 문서를 열고, Ctrl+S로 현재 문서를 저장하세요.\n",
    },
    {
        name = "deploy.lua",
        text = "-- 새벽 배포 점검\nlocal target = world.nearest()\nself:attack(target)\n",
    },
    {
        name = "notes.txt",
        text = "점검 메모\n- Ctrl+O: 다음 문서 열기\n- Ctrl+S: 현재 문서 저장\n- Ctrl+Z / Ctrl+Y: 되돌리기 / 다시 실행\n",
    },
}

function editorpractice.ensureDocuments(data)
    if type(data.documents) ~= "table" or #data.documents == 0 then
        data.documents = DEFAULT_DOCUMENTS
    end
    return data
end

local function loadLua(path)
    local file = assert(io.open(path, "rb"), "워밍업 데이터를 열 수 없습니다: " .. path)
    local source = file:read("*a")
    file:close()
    return assert(loadstring(source), "워밍업 데이터 형식이 올바르지 않습니다: " .. path)()
end

function editorpractice.load(root)
    local data = editorpractice.ensureDocuments(loadLua(root .. "/data/editor_practice.lua"))
    local lore = loadLua(root .. "/data/" .. data.lore_file)
    data.narrative = lore.narrative
    return data
end

function editorpractice.new(documents)
    return setmetatable({ documents = documents, index = 1 }, Session)
end

function Session:current()
    return self.documents[self.index]
end

function Session:advance()
    if not self:done() then self.index = self.index + 1 end
end

function Session:done()
    return self.index > #self.documents
end

local function copyDocuments(documents)
    local copy = {}
    for i, document in ipairs(documents) do
        copy[i] = { name = document.name, text = document.text, saved = document.text }
    end
    return copy
end

function editorpractice:enter(_, d, p)
    self.d, self.p = d, p
    self.data = editorpractice.load(d.root)
    self.documents = copyDocuments(self.data.documents)
    self.session = editorpractice.new(self.documents)
    self.editor = Editor(260, 180, 860, 350)
    self.status = nil
    self:openDocument(1)
end

function editorpractice:openDocument(index)
    local document = self.documents[index]
    if not document then return false end
    if self.editor and self.session.index ~= index then self:saveCurrent(false) end
    self.session.index = index
    self.editor:setText(document.text)
    self.status = document.name .. " 열기"
    return true
end

function editorpractice:saveCurrent(showStatus)
    local document = self.session and self.session:current()
    if not document or not self.editor then return false end
    document.text = self.editor:getText()
    document.saved = document.text
    if showStatus then self.status = document.name .. " 저장됨 (가상 작업공간)" end
    return true
end

function editorpractice:nextDocument()
    local index = self.session.index % #self.documents + 1
    return self:openDocument(index)
end

function editorpractice:update()
end

function editorpractice:draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local current = self.session:current()
    love.graphics.clear(0.045, 0.055, 0.08)
    love.graphics.setFont(fonts.big)
    love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
    love.graphics.printf("에디터 워밍업", 0, 34, W, "center")
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.75, 0.8, 0.88)
    love.graphics.printf(self.data.narrative, 0, 76, W, "center")

    love.graphics.setColor(0.08, 0.11, 0.16)
    love.graphics.rectangle("fill", 120, 132, 120, 398, 5)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.95, 0.82, 0.38)
    love.graphics.print("문서", 140, 150)
    for i, document in ipairs(self.documents) do
        local y = 184 + (i - 1) * 42
        if i == self.session.index then
            love.graphics.setColor(art.pal.green[1], art.pal.green[2], art.pal.green[3])
            love.graphics.print("> " .. document.name, 140, y)
        else
            love.graphics.setColor(0.72, 0.76, 0.84)
            love.graphics.print("  " .. document.name, 140, y)
        end
    end

    love.graphics.setColor(0.15, 0.18, 0.24)
    love.graphics.rectangle("fill", 260, 132, 860, 34, 5)
    love.graphics.setColor(0.95, 0.82, 0.38)
    love.graphics.printf(current.name, 278, 141, 824, "left")
    self.editor:draw(fonts, true)

    love.graphics.setColor(0.55, 0.64, 0.72)
    love.graphics.printf("Nano에서 영감을 받은 게임 내 편집기 · 실제 파일에는 쓰지 않습니다.", 0, H - 72, W, "center")
    love.graphics.setColor(0.78, 0.84, 0.92)
    love.graphics.printf(self.status or "F1~F3 문서 열기 · Ctrl+O 다음 문서 · Ctrl+S 저장 · ESC 돌아가기", 0, H - 46, W, "center")
    love.graphics.setColor(1, 1, 1)
end

function editorpractice:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if key == "escape" then
        self:saveCurrent(false)
        Gamestate.switch(require("states.title"), self.d, self.p)
        return
    end
    if key == "f1" then self:openDocument(1); return end
    if key == "f2" then self:openDocument(2); return end
    if key == "f3" then self:openDocument(3); return end
    if ctrl and key == "o" then self:nextDocument(); return end
    if ctrl and key == "s" then self:saveCurrent(true); return end
    self.editor:keypressed(key, ctrl)
end

function editorpractice:textinput(ch)
    self.editor:textinput(ch)
end

function editorpractice:mousepressed(x, y, button)
    if button ~= 1 then return end
    if x >= 120 and x < 240 and y >= 170 and y < 170 + #self.documents * 42 then
        self:openDocument(math.floor((y - 170) / 42) + 1)
        return
    end
    local editor = self.editor
    if x < editor.x or x >= editor.x + editor.w or y < editor.y or y >= editor.y + editor.h then return end
    local lineH = fonts.mono:getHeight() + 4
    local line, column = editor:charAt(x - editor.x, y - editor.y, lineH, function(s) return fonts.mono:getWidth(s) end)
    if line then editor.cr, editor.cc = line, column end
end

return editorpractice
