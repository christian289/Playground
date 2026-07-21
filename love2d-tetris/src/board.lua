local Object = require("lib.classic")

local Board = Object:extend()

Board.WIDTH = 10
Board.HEIGHT = 20

function Board:new()
    self.grid = {}
    for y = 1, Board.HEIGHT do
        self.grid[y] = {}
    end
end

-- cells: {{col, row}, ...} — row < 1(필드 위 숨김 영역)은 비어있는 것으로 취급
function Board:fits(cells)
    for _, c in ipairs(cells) do
        local x, y = c[1], c[2]
        if x < 1 or x > Board.WIDTH or y > Board.HEIGHT then
            return false
        end
        if y >= 1 and self.grid[y][x] then
            return false
        end
    end
    return true
end

function Board:place(cells, type)
    for _, c in ipairs(cells) do
        if c[2] >= 1 then
            self.grid[c[2]][c[1]] = type
        end
    end
end

function Board:clearLines()
    local cleared = 0
    local y = Board.HEIGHT
    while y >= 1 do
        local full = true
        for x = 1, Board.WIDTH do
            if not self.grid[y][x] then
                full = false
                break
            end
        end
        if full then
            table.remove(self.grid, y)
            table.insert(self.grid, 1, {})
            cleared = cleared + 1
        else
            y = y - 1
        end
    end
    return cleared
end

return Board
