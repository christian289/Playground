-- 레벨 문자열 → Tiled Lua 맵(assets/maps/level1.lua) + 타일셋 PNG(assets/images/tileset.png) 생성기.
-- 실행: love tools/genmap  (프로젝트 루트 기준. 콘솔 출력 확인은 lovec)
-- 레벨을 고치려면 아래 MAP을 수정하고 다시 실행한다.

-- 기호: # 지면, B 벽돌, = 발판, o 코인, E 적, P 플레이어 스폰, F 깃발
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

local COLS, ROWS, TILE = 120, 18, 32

-- 타일 gid: 1 잔디 지면, 2 흙, 3 벽돌, 4 발판
local SOLID = { ["#"] = true, ["B"] = true, ["="] = true }

local function cellAt(row, col)
    if row < 1 or row > #MAP then return " " end
    local line = MAP[row]
    if col > #line then return " " end
    return line:sub(col, col)
end

local function gidAt(row, col)
    local ch = cellAt(row, col)
    if ch == "#" then
        return SOLID[cellAt(row - 1, col)] and 2 or 1
    elseif ch == "B" then
        return 3
    elseif ch == "=" then
        return 4
    end
    return 0
end

-- 이 파일 위치에서 프로젝트 루트 절대경로 계산 (love tools/genmap 실행 기준)
local function projectRoot()
    local src = love.filesystem.getSource() -- .../love2d-mario/tools/genmap
    return src:gsub("[/\\]tools[/\\]genmap$", "")
end

local function writeFile(path, content, mode)
    local f = assert(io.open(path, mode or "w"))
    f:write(content)
    f:close()
    print("WROTE " .. path)
end

local function makeTilesetPng()
    local canvas = love.graphics.newCanvas(4 * TILE, TILE)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local function dirtBase(x)
        love.graphics.setColor(0.55, 0.36, 0.20)
        love.graphics.rectangle("fill", x, 0, TILE, TILE)
        love.graphics.setColor(0.45, 0.28, 0.14)
        for i = 0, 5 do
            local dx = (i * 13 + x * 7) % 26 + 3
            local dy = (i * 11 + x * 3) % 24 + 4
            love.graphics.rectangle("fill", x + dx, dy, 3, 3)
        end
    end

    dirtBase(0)                                   -- 1: 잔디 지면
    love.graphics.setColor(0.30, 0.72, 0.30)
    love.graphics.rectangle("fill", 0, 0, TILE, 8)
    love.graphics.setColor(0.22, 0.55, 0.22)
    love.graphics.rectangle("fill", 0, 8, TILE, 2)

    dirtBase(TILE)                                -- 2: 흙

    love.graphics.setColor(0.80, 0.45, 0.20)      -- 3: 벽돌
    love.graphics.rectangle("fill", 2 * TILE, 0, TILE, TILE)
    love.graphics.setColor(0.55, 0.28, 0.10)
    love.graphics.setLineWidth(2)
    local bx = 2 * TILE
    love.graphics.line(bx, 16, bx + TILE, 16)
    love.graphics.line(bx + 16, 0, bx + 16, 16)
    love.graphics.line(bx + 8, 16, bx + 8, 32)
    love.graphics.line(bx + 24, 16, bx + 24, 32)
    love.graphics.rectangle("line", bx + 1, 1, TILE - 2, TILE - 2)

    love.graphics.setColor(0.60, 0.60, 0.68)      -- 4: 발판
    love.graphics.rectangle("fill", 3 * TILE, 4, TILE, TILE - 8, 4, 4)
    love.graphics.setColor(0.40, 0.40, 0.48)
    love.graphics.rectangle("fill", 3 * TILE + 4, 8, 4, 4)
    love.graphics.rectangle("fill", 3 * TILE + 24, 8, 4, 4)
    love.graphics.rectangle("fill", 3 * TILE + 4, 20, 4, 4)
    love.graphics.rectangle("fill", 3 * TILE + 24, 20, 4, 4)

    love.graphics.setCanvas()
    love.graphics.pop()
    return canvas:newImageData():encode("png"):getString()
end

local function makeObjects()
    local objs, id = {}, 1
    local typeOf = { o = "coin", E = "enemy", P = "spawn", F = "flag" }
    for row = 1, #MAP do
        for col = 1, #MAP[row] do
            local t = typeOf[cellAt(row, col)]
            if t then
                table.insert(objs, string.format(
                    '      { id = %d, name = "", type = %q, shape = "rectangle", x = %d, y = %d, ' ..
                    'width = %d, height = %d, rotation = 0, visible = true, properties = {} },',
                    id, t, (col - 1) * TILE, (row - 1) * TILE, TILE, TILE))
                id = id + 1
            end
        end
    end
    return table.concat(objs, "\n"), id
end

local function makeMapLua()
    local data = {}
    for row = 1, ROWS do
        local line = {}
        for col = 1, COLS do
            line[col] = gidAt(row, col)
        end
        table.insert(data, "      " .. table.concat(line, ", ") .. ",")
    end
    local objects, nextId = makeObjects()

    return ([[
-- tools/genmap 이 생성한 Tiled Lua 형식 맵. 직접 수정하지 말고 생성기를 다시 실행할 것.
return {
  version = "1.10",
  luaversion = "5.1",
  tiledversion = "1.10.2",
  orientation = "orthogonal",
  renderorder = "right-down",
  width = ]] .. COLS .. [[,
  height = ]] .. ROWS .. [[,
  tilewidth = ]] .. TILE .. [[,
  tileheight = ]] .. TILE .. [[,
  nextlayerid = 3,
  nextobjectid = ]] .. nextId .. [[,
  properties = {},
  tilesets = {
    {
      name = "tiles",
      firstgid = 1,
      tilewidth = ]] .. TILE .. [[,
      tileheight = ]] .. TILE .. [[,
      spacing = 0,
      margin = 0,
      columns = 4,
      image = "../images/tileset.png",
      imagewidth = ]] .. (4 * TILE) .. [[,
      imageheight = ]] .. TILE .. [[,
      objectalignment = "unspecified",
      tileoffset = { x = 0, y = 0 },
      grid = { orientation = "orthogonal", width = ]] .. TILE .. [[, height = ]] .. TILE .. [[ },
      properties = {},
      wangsets = {},
      tilecount = 4,
      tiles = {},
    },
  },
  layers = {
    {
      type = "tilelayer",
      id = 1,
      name = "terrain",
      x = 0,
      y = 0,
      width = ]] .. COLS .. [[,
      height = ]] .. ROWS .. [[,
      visible = true,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      properties = { collidable = true },
      encoding = "lua",
      data = {
]] .. table.concat(data, "\n") .. [[

      },
    },
    {
      type = "objectgroup",
      id = 2,
      name = "entities",
      visible = false,
      opacity = 1,
      offsetx = 0,
      offsety = 0,
      parallaxx = 1,
      parallaxy = 1,
      draworder = "topdown",
      properties = {},
      objects = {
]] .. objects .. [[

      },
    },
  },
}
]])
end

function love.load()
    local root = projectRoot()
    writeFile(root .. "/assets/images/tileset.png", makeTilesetPng(), "wb")
    writeFile(root .. "/assets/maps/level1.lua", makeMapLua())
    print("GENMAP DONE")
    love.event.quit(0)
end
