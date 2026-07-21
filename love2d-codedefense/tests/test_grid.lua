return function(t)
    local grid = require("src.grid")
    local g = grid.load(PROJECT_ROOT .. "/data/mazes/001.txt")

    t.eq(grid.COLS, 12, "그리드 열 수")
    t.eq(grid.ROWS, 16, "그리드 행 수")
    t.ok(g.walls[1][1], "1행1열은 벽(#)")
    t.ok(not g.walls[2][2], "2행2열은 통로")
    t.ok(g.build[3][3], "3행3열은 건설칸(B)")
    t.ok(g.walls[3][3], "건설칸은 적이 못 지나감")

    -- 플로우필드: 위쪽 통로에서 아래로 향하는 경로가 존재
    t.ok(g.flow[2][2] ~= nil, "통로 칸에 플로우 존재")
    t.ok(g.dist[2][2] > 0, "위쪽 통로의 거리 > 0")
    t.eq(g.dist[16][1], 0, "맨 아랫줄 통로 거리 0")

    -- 플로우를 따라가면 반드시 아랫줄에 도달 (막힌 미로 감지)
    local r, c, steps = 2, 2, 0
    while g.dist[r][c] ~= 0 and steps < 500 do
        local d = g.flow[r][c]
        r, c, steps = r + d[1], c + d[2], steps + 1
    end
    t.eq(g.dist[r][c], 0, "플로우 추적이 서버라인 도달")

    local x, y = grid.toXY(1, 1)
    t.eq(x, 0, "toXY x"); t.eq(y, 0, "toXY y")
end
