local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")
local Editor = require("src.editor")
local Battle = require("src.battle")

local GRID_X, GRID_Y = 20, 60
local STRATEGIES = {
    { label = "가까운 적", code = "function on_tick(self, world)\n  self:attack(world.nearest())\nend" },
    { label = "약한 적", code = "function on_tick(self, world)\n  self:attack(world.weakest())\nend" },
    { label = "빠른 적", code = "function on_tick(self, world)\n  self:attack(world.fastest())\nend" },
}

local prep = {}

function prep:enter(prev, d, stageId, p, resume)
    self.d, self.stageId, self.p = d, stageId, p
    self.stage = d.stages[stageId]
    if resume then
        -- 전투 중 pause_at으로 돌아온 경우: battle 유지
        self.battle = resume.battle
        self.money = resume.money
    else
        self.battle = nil
        self.money = self.stage.budget
        self.placements = {}
    end
    self.g = grid.load(d.root .. "/data/" .. self.stage.maze_file)
    self.cursorR, self.cursorC = 3, 3
    self.selTower = "printer"
    self.stratIdx = 1
    self.focus = "grid"          -- "grid" | "editor"
    self.editor = Editor(480, 60, 460, 420)
    self.editor:setQuickbar({
        { key = "f1", label = "on_tick", text = "function on_tick(self, world)\n  ${1}\nend" },
        { key = "f2", label = "공격", text = "self:attack(world.nearest())" },
        { key = "f3", label = "if", text = "if ${1} then\nend" },
        { key = "f4", label = "for", text = "for i, e in ipairs(world.enemies()) do\n  ${1}\nend" },
    })
    -- 코드 초기값: 저장된 코드 > 힌트 템플릿 > 빈 화면
    if self.stage.ui ~= "button" then
        local saved = p.codes[stageId]
        if saved then self.editor:setText(saved)
        elseif self.stage.hints_file ~= "" then
            local f = io.open(d.root .. "/data/" .. self.stage.hints_file, "rb")
            if f then self.editor:setText(f:read("*a")); f:close() end
        end
    end
end

function prep:currentCode()
    if self.stage.ui == "button" then
        return STRATEGIES[self.stratIdx].code
    end
    return self.editor:getText()
end

function prep:draw()
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.print(("스테이지 %d — %s   예산 %d"):format(self.stageId, self.stage.concept, self.money), 20, 16)

    -- 그리드
    for r = 1, grid.ROWS do
        for c = 1, grid.COLS do
            local x, y = grid.toXY(r, c)
            x, y = x + GRID_X, y + GRID_Y
            if self.g.build[r][c] then love.graphics.setColor(0.2, 0.3, 0.2)
            elseif self.g.walls[r][c] then love.graphics.setColor(0.22, 0.24, 0.3)
            else love.graphics.setColor(0.12, 0.13, 0.17) end
            love.graphics.rectangle("fill", x, y, grid.CELL - 1, grid.CELL - 1)
        end
    end
    -- 배치된 타워
    for _, pl in ipairs(self.placements or {}) do
        local x, y = grid.toXY(pl.r, pl.c)
        local col = self.d.towers[pl.tower].color
        local rgb = {}
        for v in col:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        love.graphics.setColor(rgb[1], rgb[2], rgb[3])
        love.graphics.rectangle("fill", x + GRID_X + 4, y + GRID_Y + 4, grid.CELL - 9, grid.CELL - 9)
    end
    -- 커서
    if self.focus == "grid" then
        local x, y = grid.toXY(self.cursorR, self.cursorC)
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.rectangle("line", x + GRID_X, y + GRID_Y, grid.CELL - 1, grid.CELL - 1)
    end

    -- 우측 패널
    if self.stage.ui == "button" then
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.9, 0.92, 0.95)
        love.graphics.print("타겟 전략 (Space로 변경):", 480, 60)
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.print("< " .. STRATEGIES[self.stratIdx].label .. " >", 480, 90)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.6, 0.65, 0.7)
        love.graphics.print("이 버튼은 사실 이 코드입니다:", 480, 140)
        love.graphics.setColor(0.5, 0.8, 0.6)
        love.graphics.print(STRATEGIES[self.stratIdx].code, 480, 165)
    else
        self.editor:draw(fonts, self.focus == "editor")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.printf("화살표 배치커서 · B 건설(" .. self.selTower .. ") · T 타워종류 · Tab 에디터/그리드 · F5 전투 시작 · ESC 나가기",
        20, 600, 920, "left")
end

function prep:keypressed(key)
    if key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.d, self.p)
        return
    end
    if key == "f5" then self:startBattle() return end
    if key == "tab" and self.stage.ui ~= "button" then
        self.focus = (self.focus == "grid") and "editor" or "grid"
        return
    end
    if self.focus == "editor" then
        if not self.editor:quickbarPressed(key) then self.editor:keypressed(key) end
        return
    end
    -- 그리드 조작
    if key == "up" then self.cursorR = math.max(1, self.cursorR - 1)
    elseif key == "down" then self.cursorR = math.min(grid.ROWS, self.cursorR + 1)
    elseif key == "left" then self.cursorC = math.max(1, self.cursorC - 1)
    elseif key == "right" then self.cursorC = math.min(grid.COLS, self.cursorC + 1)
    elseif key == "space" and self.stage.ui == "button" then
        self.stratIdx = self.stratIdx % #STRATEGIES + 1
    elseif key == "t" then
        local order = { "printer", "compiler", "sniper" }
        for i, id in ipairs(order) do
            if id == self.selTower then self.selTower = order[i % #order + 1] break end
        end
    elseif key == "b" then
        self:tryBuild()
    end
end

function prep:tryBuild()
    local def = self.d.towers[self.selTower]
    if not self.g.build[self.cursorR][self.cursorC] then return end
    for _, pl in ipairs(self.placements) do
        if pl.r == self.cursorR and pl.c == self.cursorC then return end
    end
    if self.money < def.cost then return end
    if def.requires ~= "" then
        local has = false
        for _, pl in ipairs(self.placements) do
            if pl.tower == def.requires then has = true end
        end
        if not has then return end
    end
    self.money = self.money - def.cost
    self.placements[#self.placements + 1] =
        { r = self.cursorR, c = self.cursorC, tower = self.selTower, items = {} }
end

function prep:textinput(ch)
    if self.focus == "editor" then self.editor:textinput(ch) end
end

function prep:startBattle()
    local code = self:currentCode()
    if self.stage.ui ~= "button" then
        self.p.codes[self.stageId] = code
        require("src.progress").save(self.p)
    end
    for _, pl in ipairs(self.placements) do pl.code = code end
    if not self.battle then
        local ok, battleOrErr = pcall(Battle, self.d, self.stageId, self.placements)
        if not ok then return end
        self.battle = battleOrErr
    end
    -- 문법 오류가 있는 타워가 있으면 시작 막기 (교육: 시작 전 진단)
    for _, tw in ipairs(self.battle.towers) do
        if tw.lastError and tw.env == nil then return end
    end
    self.battle:start()
    Gamestate.switch(require("states.battle"), self.battle,
        { d = self.d, stageId = self.stageId, p = self.p, prepState = self })
end

return prep
