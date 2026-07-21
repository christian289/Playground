local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local grid = require("src.grid")

local GRID_X, GRID_Y = 20, 60
local view = {}

function view:enter(_, battle, ctx)
    self.b, self.ctx = battle, ctx
    self.speed = 1
end

function view:update(dt)
    self.b:update(dt * self.speed)
    if self.b.status == "prep" then
        Gamestate.switch(require("states.prep"), self.ctx.d, self.ctx.stageId, self.ctx.p,
            { battle = self.b, money = 0, placements = self.ctx.placements })
    elseif self.b.status == "clear" or self.b.status == "defeat" then
        Gamestate.switch(require("states.result"), self.b.status, self.ctx)
    end
end

function view:draw()
    local b = self.b
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.9, 0.92, 0.95)
    love.graphics.print(("%.0f초 / 300초   서버 HP %d   배속 x%d (1/2/4)"):format(b.clock, b.serverHP, self.speed), 20, 16)

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
    -- 서버라인
    love.graphics.setColor(0.3, 0.7, 1, 0.6)
    love.graphics.rectangle("fill", GRID_X, GRID_Y + grid.ROWS * grid.CELL, grid.COLS * grid.CELL, 4)

    for _, tw in ipairs(b.towers) do
        local rgb = {}
        for v in tw.def.color:gmatch("[^;]+") do rgb[#rgb + 1] = tonumber(v) end
        if tw.crashed > 0 then love.graphics.setColor(0.4, 0.4, 0.4)
        else love.graphics.setColor(rgb[1], rgb[2], rgb[3]) end
        love.graphics.rectangle("fill", GRID_X + tw.x - 12, GRID_Y + tw.y - 12, 24, 24)
        if tw.crashed > 0 then
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 0.4, 0.3)
            love.graphics.print("크래시", GRID_X + tw.x - 14, GRID_Y + tw.y - 28)
        end
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

    -- 전투 로그
    love.graphics.setFont(fonts.small)
    for i, msg in ipairs(b.log) do
        love.graphics.setColor(0.8, 0.82, 0.86, 1 - (#b.log - i) * 0.1)
        love.graphics.print(msg, 480, 60 + (i - 1) * 20)
    end
end

function view:keypressed(key)
    if key == "1" then self.speed = 1
    elseif key == "2" then self.speed = 2
    elseif key == "4" then self.speed = 4
    elseif key == "escape" then
        Gamestate.switch(require("states.stageselect"), self.ctx.d, self.ctx.p)
    end
end

return view
