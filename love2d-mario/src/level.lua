-- 문자열 기반 레벨 정의와 bump 월드 구축, 타일 렌더링
-- 기호: # 지면, B 벽돌, = 발판, o 코인, E 적, P 플레이어 스폰, F 깃발
-- (다음 단계: Tiled로 맵을 만들어 STI로 교체)
local M = {}

M.TILE = 32
M.ROWS = 18
M.COLS = 120

local sp = function(n) return string.rep(" ", n) end
local gr = function(n) return string.rep("#", n) end

local MAP = {
    "", "", "", "", "", "", "", "", "",
    sp(51) .. "oooo",
    sp(51) .. "====",
    sp(22) .. "ooo" .. sp(7) .. "BBBB" .. sp(25) .. "BBBB",
    sp(21) .. "=====" .. sp(76) .. "#",
    sp(45) .. "====" .. sp(52) .. "##",
    sp(14) .. "oooo" .. sp(53) .. "ooo" .. sp(9) .. "ooo" .. sp(14) .. "###",
    sp(2) .. "P" .. sp(26) .. "E" .. sp(27) .. "E" .. sp(6) .. "E" .. sp(22) .. "E" .. sp(11) .. "####" .. sp(8) .. "F",
    gr(40) .. sp(3) .. gr(28) .. sp(3) .. gr(21) .. sp(3) .. gr(22),
    gr(40) .. sp(3) .. gr(28) .. sp(3) .. gr(21) .. sp(3) .. gr(22),
}

local SOLID = { ["#"] = "ground", ["B"] = "brick", ["="] = "platform" }

function M.build(world)
    local out = {
        tiles = {}, coins = {}, enemySpawns = {},
        spawn = { x = 64, y = 400 }, flag = nil,
        widthPx = M.COLS * M.TILE, heightPx = M.ROWS * M.TILE,
    }
    for row = 1, #MAP do
        local line = MAP[row]
        for col = 1, #line do
            local ch = line:sub(col, col)
            local px, py = (col - 1) * M.TILE, (row - 1) * M.TILE
            if SOLID[ch] then
                local above = row > 1 and MAP[row - 1]:sub(col, col) or " "
                local tile = { kind = SOLID[ch], x = px, y = py, top = not SOLID[above] }
                world:add(tile, px, py, M.TILE, M.TILE)
                table.insert(out.tiles, tile)
            elseif ch == "o" then
                local coin = { kind = "coin", x = px + 8, y = py + 8, w = 16, h = 16 }
                world:add(coin, coin.x, coin.y, coin.w, coin.h)
                table.insert(out.coins, coin)
            elseif ch == "E" then
                table.insert(out.enemySpawns, { x = px + 3, y = py + 6 })
            elseif ch == "P" then
                out.spawn = { x = px + 4, y = py + 2 }
            elseif ch == "F" then
                local flag = { kind = "flag", x = px + 12, y = py - 5 * M.TILE, w = 8, h = 6 * M.TILE, baseY = py }
                world:add(flag, flag.x, flag.y, flag.w, flag.h)
                out.flag = flag
            end
        end
    end
    -- 레벨 양끝 보이지 않는 벽
    local wallL = { kind = "wall" }
    local wallR = { kind = "wall" }
    world:add(wallL, -M.TILE, -400, M.TILE, out.heightPx + 800)
    world:add(wallR, out.widthPx, -400, M.TILE, out.heightPx + 800)
    return out
end

function M.draw(level)
    local T = M.TILE
    for _, t in ipairs(level.tiles) do
        if t.kind == "ground" then
            love.graphics.setColor(0.55, 0.36, 0.20)
            love.graphics.rectangle("fill", t.x, t.y, T, T)
            if t.top then
                love.graphics.setColor(0.30, 0.72, 0.30)
                love.graphics.rectangle("fill", t.x, t.y, T, 8)
            end
        elseif t.kind == "brick" then
            love.graphics.setColor(0.80, 0.45, 0.20)
            love.graphics.rectangle("fill", t.x, t.y, T, T)
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.line(t.x, t.y + T / 2, t.x + T, t.y + T / 2)
            love.graphics.line(t.x + T / 2, t.y, t.x + T / 2, t.y + T / 2)
            love.graphics.line(t.x + T / 4, t.y + T / 2, t.x + T / 4, t.y + T)
            love.graphics.line(t.x + T * 3 / 4, t.y + T / 2, t.x + T * 3 / 4, t.y + T)
        else -- platform
            love.graphics.setColor(0.60, 0.60, 0.68)
            love.graphics.rectangle("fill", t.x, t.y + 4, T, T - 8, 4, 4)
        end
    end

    for _, c in ipairs(level.coins) do
        if not c.collected then
            love.graphics.setColor(0.95, 0.82, 0.15)
            love.graphics.circle("fill", c.x + c.w / 2, c.y + c.h / 2, 8)
            love.graphics.setColor(0.75, 0.60, 0.05)
            love.graphics.circle("line", c.x + c.w / 2, c.y + c.h / 2, 8)
        end
    end

    local f = level.flag
    if f then
        love.graphics.setColor(0.75, 0.75, 0.80)
        love.graphics.rectangle("fill", f.x + 2, f.y, 4, f.h)
        love.graphics.setColor(0.20, 0.75, 0.30)
        love.graphics.polygon("fill", f.x + 6, f.y, f.x + 6 + 26, f.y + 11, f.x + 6, f.y + 22)
        love.graphics.setColor(0.45, 0.45, 0.50)
        love.graphics.rectangle("fill", f.x - 10, f.baseY + M.TILE - 12, 28, 12)
    end
end

return M
