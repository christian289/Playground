local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")
local Editor = require("src.editor")
local Battle = require("src.battle")
local progress = require("src.progress")

local GRID_X, GRID_Y = 8, 48
local play = {}

local function loadText(root, rel)
    local f = io.open(root .. "/data/" .. rel, "rb")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

function play:enter(_, d, stageId, p)
    self.d, self.stageId, self.p = d, stageId, p
    self.stage = d.stages[stageId]
    self.battle = Battle(d, stageId, { items = p.items })
    self.speed = 1
    self.tut = nil                      -- Task 5에서 튜토리얼 주입
    self.autotype = nil                 -- {target=문자열, pos=글자수, timer}
    self.buttons = {}
    if self.stage.buttons_file ~= "" then
        local chunk = loadstring(loadText(d.root, self.stage.buttons_file) or "")
        if chunk then self.buttons = chunk() or {} end
    end
    self.editor = Editor(400, 48, 552, 470)
    self.editor:setQuickbar({
        { key = "f1", label = "build", text = 'build("printer", ${1}, , "")' },
        { key = "f2", label = "on_tick", text = "function on_tick(self, world)\n  ${1}\nend" },
        { key = "f3", label = "공격", text = "self:attack(world.nearest())" },
        { key = "f4", label = "if", text = "if ${1} then\nend" },
    })
    local saved = p.codes[stageId]
    if saved then self.editor:setText(saved)
    elseif self.stage.hints_file ~= "" then
        self.editor:setText(loadText(d.root, self.stage.hints_file) or "")
    end
    self.battle:start()                 -- 카운트다운부터 실시간 진행
end

function play:isButtonStage() return self.stage.ui == "button" end

function play:save()
    local before = #self.battle.towers
    local code = self.editor:getText()
    local ok = self.battle:setScript(code)
    if ok then
        self.p.codes[self.stageId] = code
        progress.save(self.p)
        if #self.battle.towers > before and self.tut then self.tut:notify("built") end
        if self.tut then self.tut:notify("saved") end
    end
    return ok
end

function play:pressButton(i)
    local b = self.buttons[i]
    if not b then return end
    self.autotype = { target = b.script, timer = 0, pos = 0 }
    self.editor:setText("")
end

function play:update(dt)
    -- 버튼 오토타이핑 (초당 40자, 끝나면 자동 저장)
    if self.autotype then
        local at = self.autotype
        at.timer = at.timer + dt
        local want = math.min(math.floor(at.timer * 40), #at.target)
        if want > at.pos then
            self.editor:setText(at.target:sub(1, want))
            self.editor.cr = #self.editor.lines
            self.editor.cc = 1
            at.pos = want
        end
        if at.pos >= #at.target then
            self.autotype = nil
            self.editor:setText(at.target)
            self.editor.cr = #self.editor.lines
            self.editor.cc = 1
            self:save()
        end
    end

    self.battle:update(dt * self.speed)
    -- 웨이브 틈 감지: 화면에 적이 없고 전투 중이면 gap 알림 (튜토리얼용, 1회성은 tutorial이 관리)
    if self.tut and self.battle.clock > 0 and #self.battle.enemies == 0 then
        self.tut:notify("gap")
    end

    if self.battle.status == "clear" or self.battle.status == "defeat" then
        Gamestate.switch(require("states.result"), self.battle.status,
            { d = self.d, stageId = self.stageId, p = self.p })
    end
end

function play:draw()
    local b = self.battle
    -- 상단 바
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    local clockText = b.clock < 0
        and ("전투 시작까지 %d초 — 코드를 준비하세요!"):format(math.ceil(-b.clock))
        or ("%.0f / 300초"):format(b.clock)
    love.graphics.print(("%s   서버 HP %d   잔액 %d   배속 x%d"):format(clockText, b.serverHP, b.money, self.speed), 8, 12)

    -- 전장
    for r = 1, grid.ROWS do
        for c = 1, grid.COLS do
            local x, y = grid.toXY(r, c)
            x, y = x + GRID_X, y + GRID_Y
            if b.grid.build[r][c] then love.graphics.setColor(0.2, 0.3, 0.2)
            elseif b.grid.walls[r][c] then love.graphics.setColor(0.22, 0.24, 0.3)
            else love.graphics.setColor(0.12, 0.13, 0.17) end
            love.graphics.rectangle("fill", x, y, grid.CELL - 1, grid.CELL - 1)
        end
    end
    -- 행·열 좌표 라벨 (코드로 좌표를 지정하므로 상시 표기)
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.5, 0.55, 0.6)
    for c = 1, grid.COLS do love.graphics.print(tostring(c), GRID_X + (c - 1) * grid.CELL + 10, GRID_Y - 16) end
    for r = 1, grid.ROWS do love.graphics.print(tostring(r), GRID_X - 6 - fonts.small:getWidth(tostring(r)) + 4, GRID_Y + (r - 1) * grid.CELL + 8) end
    -- 서버라인
    love.graphics.setColor(0.3, 0.7, 1, 0.6)
    love.graphics.rectangle("fill", GRID_X, GRID_Y + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, 4)
    -- 타워/적/총알 (기존 states/battle.lua 렌더 블록 재사용: 색상 파싱, 크래시 라벨, HP바)
    for _, tw in ipairs(b.towers) do
        local rgb = {}
        for v in tw.def.color:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        if tw.crashed > 0 or tw.disabled then love.graphics.setColor(0.4, 0.4, 0.4)
        else love.graphics.setColor(rgb[1], rgb[2], rgb[3]) end
        love.graphics.rectangle("fill", GRID_X + tw.x - 12, GRID_Y + tw.y - 12, 24, 24)
        love.graphics.setColor(0.8, 0.85, 0.9)
        love.graphics.print(tw.name or "", GRID_X + tw.x - 10, GRID_Y + tw.y - 26)
    end
    for _, e in ipairs(b.enemies) do
        local rgb = {}
        for v in e.def.color:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        love.graphics.setColor(rgb[1], rgb[2], rgb[3])
        love.graphics.circle("fill", GRID_X + e.x, GRID_Y + e.y, 9)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", GRID_X + e.x - 10, GRID_Y + e.y - 16, 20, 3)
        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.rectangle("fill", GRID_X + e.x - 10, GRID_Y + e.y - 16, 20 * e.hp / e.max_hp, 3)
    end
    love.graphics.setColor(1, 0.95, 0.6)
    for _, pr in ipairs(b.projectiles) do
        love.graphics.circle("fill", GRID_X + pr.x, GRID_Y + pr.y, pr.size)
    end

    -- 에디터 또는 버튼 패널
    if self:isButtonStage() then
        self.editor:draw(fonts, false)
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.95, 0.85, 0.4)
        love.graphics.print("버튼을 누르면 코드가 자동으로 입력·실행됩니다:", 400, 530)
        love.graphics.setFont(fonts.small)
        for i, btn in ipairs(self.buttons) do
            love.graphics.setColor(0.85, 0.88, 0.92)
            love.graphics.print(("[%d] %s"):format(i, btn.label), 400, 550 + (i - 1) * 20)
        end
    else
        self.editor:draw(fonts, true)
    end

    -- 전투 로그 (전장 아래)
    love.graphics.setFont(fonts.small)
    for i, msg in ipairs(b.log) do
        love.graphics.setColor(0.8, 0.82, 0.86, 1 - (#b.log - i) * 0.1)
        love.graphics.print(msg, 8, GRID_Y + grid.ROWS * grid.CELL + 12 + (i - 1) * 18)
    end
    -- 저장 오류
    if b.scriptError then
        love.graphics.setColor(1, 0.45, 0.4)
        love.graphics.printf("저장 실패 — " .. b.scriptError, 400, 545, 552, "left")
    end
    -- 힌트바
    love.graphics.setColor(0.6, 0.65, 0.7)
    local hint = self:isButtonStage()
        and "숫자키 버튼 실행 · Ctrl+1/2/4 배속 · ESC 나가기"
        or "F5 저장·반영 · F1~F4 스니펫 · Ctrl+1/2/4 배속 · ESC 나가기"
    love.graphics.printf(hint, 0, 620, 960, "center")

    if self.tut then self.tut:draw(fonts, GRID_X, GRID_Y) end
end

function play:keypressed(key)
    -- Task 5 훅: 튜토리얼이 활성 상태면 허용된 키만 통과시킨다.
    if self.tut and not self.tut:done() then
        if not self.tut:allows(key) then return end
        self.tut:keypressed(key)
    end
    if key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
        return
    end
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl and (key == "1" or key == "2" or key == "4") then
        self.speed = tonumber(key)
        if self.tut then self.tut:notify("speed_changed") end
        return
    end
    if self:isButtonStage() then
        local i = tonumber(key)
        if i and self.buttons[i] and not self.autotype then self:pressButton(i) end
        return
    end
    if key == "f5" then self:save() return end
    if not self.editor:quickbarPressed(key) then self.editor:keypressed(key) end
end

function play:textinput(ch)
    -- Task 5 훅: 튜토리얼이 텍스트 입력을 막는 구간에서는 무시한다.
    if self.tut and not self.tut:done() and not self.tut:allowsText() then return end
    if self:isButtonStage() or self.autotype then return end
    self.editor:textinput(ch)
end

return play
