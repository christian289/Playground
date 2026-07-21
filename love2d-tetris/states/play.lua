local Gamestate = require("lib.hump.gamestate")
local Board = require("src.board")
local Tetromino = require("src.tetromino")
local fonts = require("src.fonts")

local play = {}

local CELL = 28
local BOARD_X, BOARD_Y = 30, 40
local PANEL_X = BOARD_X + Board.WIDTH * CELL + 20

local LOCK_DELAY = 0.5
local MAX_LOCK_RESETS = 15
local DAS_DELAY, DAS_REPEAT = 0.17, 0.05
local SOFT_DROP_INTERVAL = 0.04

local function fallInterval(level)
    return math.max(0.05, 0.8 * (0.85 ^ (level - 1)))
end

local function cellsOf(piece)
    local out = {}
    for _, c in ipairs(Tetromino.data[piece.type].rotations[piece.rot + 1]) do
        table.insert(out, { piece.x + c[1], piece.y + c[2] })
    end
    return out
end

local function drawCell(col, row, color, alpha)
    if row < 1 then return end
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    love.graphics.rectangle("fill",
        BOARD_X + (col - 1) * CELL + 1, BOARD_Y + (row - 1) * CELL + 1,
        CELL - 2, CELL - 2, 3, 3)
end

local function drawMini(type, px, py, cell)
    local data = Tetromino.data[type]
    local off = (4 - data.size) * cell / 2
    love.graphics.setColor(data.color)
    for _, c in ipairs(data.rotations[1]) do
        love.graphics.rectangle("fill", px + off + c[1] * cell, py + c[2] * cell, cell - 1, cell - 1, 2, 2)
    end
end

function play:enter()
    self.board = Board()
    self.bag = {}
    self.queue = {}
    self.hold = nil
    self.holdUsed = false
    self.score = 0
    self.lines = 0
    self.level = 1
    self.fallTimer = 0
    self.lockTimer = 0
    self.lockResets = 0
    self.softTimer = 0
    self.das = { dir = 0, timer = 0, repeating = false }
    self.paused = false
    self:refillQueue()
    self:spawnPiece()
end

function play:refillQueue()
    while #self.queue < 5 do
        if #self.bag == 0 then
            for _, t in ipairs(Tetromino.types) do
                table.insert(self.bag, t)
            end
            for i = #self.bag, 2, -1 do
                local j = love.math.random(i)
                self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
            end
        end
        table.insert(self.queue, table.remove(self.bag))
    end
end

local function newPiece(type)
    local size = Tetromino.data[type].size
    local x = size == 2 and 5 or 4
    return { type = type, rot = 0, x = x, y = 0 }
end

function play:gameOver()
    Gamestate.switch(require("states.gameover"), self.score, self.lines, self.level)
end

function play:spawnPiece(type)
    local t = type
    if not t then
        t = table.remove(self.queue, 1)
        self:refillQueue()
    end
    self.piece = newPiece(t)
    self.holdUsed = false
    self.fallTimer = 0
    self.lockTimer = 0
    self.lockResets = 0
    if not self.board:fits(cellsOf(self.piece)) then
        self:gameOver()
    end
end

function play:grounded()
    local p = self.piece
    return not self.board:fits(cellsOf({ type = p.type, rot = p.rot, x = p.x, y = p.y + 1 }))
end

function play:tryMove(dx, dy)
    local p = self.piece
    local moved = { type = p.type, rot = p.rot, x = p.x + dx, y = p.y + dy }
    if self.board:fits(cellsOf(moved)) then
        self.piece = moved
        return true
    end
    return false
end

-- 접지 상태에서 이동/회전에 성공하면 잠금 지연을 리셋 (횟수 제한)
function play:onSuccessfulShift()
    if self:grounded() and self.lockResets < MAX_LOCK_RESETS then
        self.lockTimer = 0
        self.lockResets = self.lockResets + 1
    end
end

function play:tryRotate(dir)
    local p = self.piece
    if p.type == "O" then return false end
    local from, to = p.rot, (p.rot + dir) % 4
    local kickTable = p.type == "I" and Tetromino.kicks.I or Tetromino.kicks.JLSTZ
    for _, k in ipairs(kickTable[from .. ">" .. to]) do
        local cand = { type = p.type, rot = to, x = p.x + k[1], y = p.y + k[2] }
        if self.board:fits(cellsOf(cand)) then
            self.piece = cand
            self:onSuccessfulShift()
            return true
        end
    end
    return false
end

function play:lockPiece()
    local cells = cellsOf(self.piece)
    local allAbove = true
    for _, c in ipairs(cells) do
        if c[2] >= 1 then allAbove = false end
    end
    self.board:place(cells, self.piece.type)
    if allAbove then
        self:gameOver()
        return
    end
    local cleared = self.board:clearLines()
    if cleared > 0 then
        local base = { 100, 300, 500, 800 }
        self.score = self.score + base[cleared] * self.level
        self.lines = self.lines + cleared
        self.level = math.floor(self.lines / 10) + 1
    end
    self:spawnPiece()
end

function play:hardDrop()
    local dist = 0
    while self:tryMove(0, 1) do
        dist = dist + 1
    end
    self.score = self.score + dist * 2
    self:lockPiece()
end

function play:holdPiece()
    if self.holdUsed then return end
    local cur = self.piece.type
    if self.hold then
        local swapped = self.hold
        self.hold = cur
        self.piece = newPiece(swapped)
        self.fallTimer, self.lockTimer, self.lockResets = 0, 0, 0
        if not self.board:fits(cellsOf(self.piece)) then
            self:gameOver()
            return
        end
    else
        self.hold = cur
        self:spawnPiece()
    end
    self.holdUsed = true
end

function play:ghostPiece()
    local p = self.piece
    local g = { type = p.type, rot = p.rot, x = p.x, y = p.y }
    while true do
        local down = { type = g.type, rot = g.rot, x = g.x, y = g.y + 1 }
        if self.board:fits(cellsOf(down)) then
            g = down
        else
            break
        end
    end
    return g
end

function play:update(dt)
    if self.paused then return end

    -- 좌우 자동 반복 이동 (DAS)
    local dir = 0
    if love.keyboard.isDown("left") and not love.keyboard.isDown("right") then
        dir = -1
    elseif love.keyboard.isDown("right") and not love.keyboard.isDown("left") then
        dir = 1
    end
    if dir ~= self.das.dir then
        self.das.dir = dir
        self.das.timer = 0
        self.das.repeating = false
    elseif dir ~= 0 then
        self.das.timer = self.das.timer + dt
        local threshold = self.das.repeating and DAS_REPEAT or DAS_DELAY
        while self.das.timer >= threshold do
            self.das.timer = self.das.timer - threshold
            self.das.repeating = true
            threshold = DAS_REPEAT
            if self:tryMove(dir, 0) then
                self:onSuccessfulShift()
            end
        end
    end

    -- 소프트 드롭
    if love.keyboard.isDown("down") then
        self.softTimer = self.softTimer + dt
        while self.softTimer >= SOFT_DROP_INTERVAL do
            self.softTimer = self.softTimer - SOFT_DROP_INTERVAL
            if self:tryMove(0, 1) then
                self.score = self.score + 1
                self.fallTimer = 0
            end
        end
    else
        self.softTimer = 0
    end

    -- 중력 낙하와 잠금 지연
    if self:grounded() then
        self.lockTimer = self.lockTimer + dt
        if self.lockTimer >= LOCK_DELAY then
            self:lockPiece()
        end
    else
        self.lockTimer = 0
        self.fallTimer = self.fallTimer + dt
        local interval = fallInterval(self.level)
        while self.fallTimer >= interval and not self:grounded() do
            self.fallTimer = self.fallTimer - interval
            self:tryMove(0, 1)
        end
    end
end

function play:keypressed(key)
    if key == "escape" then
        Gamestate.switch(require("states.title"))
        return
    end
    if key == "p" then
        self.paused = not self.paused
        return
    end
    if self.paused then return end

    if key == "left" then
        if self:tryMove(-1, 0) then self:onSuccessfulShift() end
    elseif key == "right" then
        if self:tryMove(1, 0) then self:onSuccessfulShift() end
    elseif key == "up" or key == "x" then
        self:tryRotate(1)
    elseif key == "z" then
        self:tryRotate(-1)
    elseif key == "space" then
        self:hardDrop()
    elseif key == "c" or key == "lshift" then
        self:holdPiece()
    end
end

function play:draw()
    -- 보드 배경과 그리드
    love.graphics.setColor(0.10, 0.10, 0.16)
    love.graphics.rectangle("fill", BOARD_X, BOARD_Y, Board.WIDTH * CELL, Board.HEIGHT * CELL)
    love.graphics.setColor(1, 1, 1, 0.05)
    for x = 1, Board.WIDTH - 1 do
        love.graphics.line(BOARD_X + x * CELL, BOARD_Y, BOARD_X + x * CELL, BOARD_Y + Board.HEIGHT * CELL)
    end
    for y = 1, Board.HEIGHT - 1 do
        love.graphics.line(BOARD_X, BOARD_Y + y * CELL, BOARD_X + Board.WIDTH * CELL, BOARD_Y + y * CELL)
    end

    -- 쌓인 블록
    for y = 1, Board.HEIGHT do
        for x = 1, Board.WIDTH do
            local t = self.board.grid[y][x]
            if t then
                drawCell(x, y, Tetromino.data[t].color)
            end
        end
    end

    -- 고스트 피스
    local ghost = self:ghostPiece()
    for _, c in ipairs(cellsOf(ghost)) do
        drawCell(c[1], c[2], Tetromino.data[ghost.type].color, 0.22)
    end

    -- 현재 피스
    for _, c in ipairs(cellsOf(self.piece)) do
        drawCell(c[1], c[2], Tetromino.data[self.piece.type].color)
    end

    -- 보드 테두리
    love.graphics.setColor(0.45, 0.45, 0.55)
    love.graphics.rectangle("line", BOARD_X - 1, BOARD_Y - 1, Board.WIDTH * CELL + 2, Board.HEIGHT * CELL + 2)

    -- 사이드 패널
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.print("HOLD", PANEL_X, 40)
    love.graphics.rectangle("line", PANEL_X, 58, 88, 56)
    if self.hold then
        drawMini(self.hold, PANEL_X + 8, 70, 18)
    end

    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.print("NEXT", PANEL_X, 136)
    for i = 1, 4 do
        if self.queue[i] then
            drawMini(self.queue[i], PANEL_X + 8, 158 + (i - 1) * 56, 16)
        end
    end

    love.graphics.setFont(fonts.normal)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("SCORE", PANEL_X, 410)
    love.graphics.print(tostring(self.score), PANEL_X, 434)
    love.graphics.print("LEVEL " .. self.level, PANEL_X, 486)
    love.graphics.print("LINES " .. self.lines, PANEL_X, 514)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.55, 0.55, 0.65)
    love.graphics.print("P PAUSE\nESC TITLE", PANEL_X, 580)

    if self.paused then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setFont(fonts.big)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PAUSED", 0, 280, love.graphics.getWidth(), "center")
    end
end

return play
