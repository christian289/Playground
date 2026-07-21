-- STI(Tiled Lua 맵) 로드 + bump 월드 구축 + 엔티티(코인/깃발) 렌더링.
-- 지형 타일은 STI가 그리고 충돌은 bump 플러그인(map:bump_init)이 등록한다.
-- 레벨 수정: tools/genmap/main.lua 의 MAP을 고치고 `love tools/genmap` 재실행
-- (또는 Tiled 에디터로 만든 맵을 Lua로 export해서 assets/maps/에 배치).
local sti = require("lib.sti")

local M = {}

M.TILE = 32

function M.build(world)
    local map = sti("assets/maps/level1.lua", { "bump" })
    map:bump_init(world)

    local out = {
        map = map, coins = {}, enemySpawns = {},
        spawn = { x = 64, y = 400 }, flag = nil,
        widthPx = map.width * map.tilewidth,
        heightPx = map.height * map.tileheight,
    }

    for _, obj in ipairs(map.layers["entities"].objects) do
        if obj.type == "coin" then
            local coin = { kind = "coin", x = obj.x + 8, y = obj.y + 8, w = 16, h = 16 }
            world:add(coin, coin.x, coin.y, coin.w, coin.h)
            table.insert(out.coins, coin)
        elseif obj.type == "enemy" then
            table.insert(out.enemySpawns, { x = obj.x + 3, y = obj.y + 6 })
        elseif obj.type == "spawn" then
            out.spawn = { x = obj.x + 4, y = obj.y + 2 }
        elseif obj.type == "flag" then
            out.flag = { kind = "flag", x = obj.x + 12, y = obj.y - 5 * M.TILE, w = 8, h = 6 * M.TILE, baseY = obj.y }
            world:add(out.flag, out.flag.x, out.flag.y, out.flag.w, out.flag.h)
        end
    end

    -- 레벨 양끝 보이지 않는 벽
    local wallL = { kind = "wall" }
    local wallR = { kind = "wall" }
    world:add(wallL, -M.TILE, -400, M.TILE, out.heightPx + 800)
    world:add(wallR, out.widthPx, -400, M.TILE, out.heightPx + 800)
    return out
end

-- 코인과 깃발은 STI 밖에서 직접 그린다 (카메라 attach 안에서 호출할 것)
function M.drawEntities(level, sprites, coinAnim)
    for _, c in ipairs(level.coins) do
        if not c.collected then
            coinAnim:draw(sprites.coinImg, c.x + c.w / 2, c.y + c.h / 2, 0, 1, 1, 16, 16)
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
        love.graphics.setColor(1, 1, 1)
    end
end

return M
