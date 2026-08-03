local grid = {}
grid.COLS, grid.ROWS, grid.CELL = 12, 16, 32

local DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

-- 미로 파일: ROWS줄 × COLS문자. '#'=벽, '.'=통로, 'B'=건설칸(벽 취급)
function grid.load(path)
    local f = assert(io.open(path, "rb"), "미로 파일 없음: " .. path)
    local g = { walls = {}, build = {} }
    local r = 0
    for line in f:lines() do
        line = line:gsub("[\r%s]+$", "")
        if line ~= "" then
            r = r + 1
            assert(#line == grid.COLS,
                ("%s %d행 길이 %d ~= %d"):format(path, r, #line, grid.COLS))
            g.walls[r], g.build[r] = {}, {}
            for c = 1, grid.COLS do
                local ch = line:sub(c, c)
                g.walls[r][c] = (ch == "#" or ch == "B")
                g.build[r][c] = (ch == "B")
            end
        end
    end
    f:close()
    assert(r == grid.ROWS, ("%s: 행 수 %d ~= %d"):format(path, r, grid.ROWS))
    grid.computeFlow(g)
    return g
end

-- BFS: 맨 아랫줄 통로들로부터의 거리 → 각 통로 칸의 다음 이동 방향
function grid.computeFlow(g)
    local dist, queue, head = {}, {}, 1
    for r = 1, grid.ROWS do dist[r] = {} end
    for c = 1, grid.COLS do
        if not g.walls[grid.ROWS][c] then
            dist[grid.ROWS][c] = 0
            queue[#queue + 1] = { grid.ROWS, c }
        end
    end
    while head <= #queue do
        local r, c = queue[head][1], queue[head][2]
        head = head + 1
        for _, d in ipairs(DIRS) do
            local nr, nc = r + d[1], c + d[2]
            if nr >= 1 and nr <= grid.ROWS and nc >= 1 and nc <= grid.COLS
                and not g.walls[nr][nc] and dist[nr][nc] == nil then
                dist[nr][nc] = dist[r][c] + 1
                queue[#queue + 1] = { nr, nc }
            end
        end
    end
    local flow = {}
    for r = 1, grid.ROWS do
        flow[r] = {}
        for c = 1, grid.COLS do
            local d0 = dist[r][c]
            if d0 and d0 > 0 then
                for _, d in ipairs(DIRS) do
                    local nr, nc = r + d[1], c + d[2]
                    if nr >= 1 and nr <= grid.ROWS and nc >= 1 and nc <= grid.COLS
                        and dist[nr][nc] and dist[nr][nc] < d0 then
                        flow[r][c] = d
                        break
                    end
                end
            end
        end
    end
    g.dist, g.flow = dist, flow
end

function grid.toXY(r, c)
    return (c - 1) * grid.CELL, (r - 1) * grid.CELL
end

return grid
