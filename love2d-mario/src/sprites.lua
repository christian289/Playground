-- 런타임에 캔버스로 픽셀아트 스프라이트시트를 생성하고 anim8 그리드/애니메이션을 제공.
-- 실제 PNG 에셋이 준비되면 love.graphics.newImage로 교체하면 된다 (anim8 사용부는 그대로).
local anim8 = require("lib.anim8")

local sprites = {}

-- 16x16 픽셀아트를 2배 확대해 32x32 프레임으로 그린다
local PX = 2

local COL = {
    red    = { 0.85, 0.16, 0.16 },
    darkred = { 0.62, 0.10, 0.10 },
    skin   = { 0.98, 0.80, 0.60 },
    blue   = { 0.22, 0.30, 0.75 },
    brown  = { 0.42, 0.26, 0.12 },
    dark   = { 0.10, 0.08, 0.08 },
    white  = { 1, 1, 1 },
    ebrown = { 0.55, 0.33, 0.16 },
    edark  = { 0.35, 0.20, 0.10 },
    yellow = { 0.95, 0.82, 0.15 },
    ydark  = { 0.72, 0.58, 0.05 },
}

local function p(x, y, w, h, c)
    love.graphics.setColor(c)
    love.graphics.rectangle("fill", x * PX, y * PX, w * PX, h * PX)
end

-- pose: "idle" | "walk1" | "walk2" | "jump"  (오른쪽을 보는 기준)
local function drawPlayerFrame(pose)
    p(4, 0, 8, 2, COL.red)            -- 모자 윗부분
    p(3, 2, 10, 1, COL.red)
    p(10, 3, 5, 1, COL.darkred)       -- 챙
    p(3, 3, 7, 4, COL.skin)           -- 얼굴
    p(2, 3, 1, 4, COL.brown)          -- 뒷머리
    p(8, 4, 1, 2, COL.dark)           -- 눈
    p(10, 6, 2, 1, COL.brown)         -- 콧수염 느낌
    p(3, 7, 9, 3, COL.red)            -- 셔츠
    p(4, 9, 8, 3, COL.blue)           -- 멜빵바지
    p(5, 8, 1, 1, COL.yellow)         -- 단추
    p(9, 8, 1, 1, COL.yellow)

    if pose == "jump" then
        p(1, 6, 2, 3, COL.red)        -- 팔 위로
        p(12, 5, 2, 3, COL.red)
        p(4, 12, 3, 2, COL.blue)      -- 다리 접기
        p(9, 12, 3, 2, COL.blue)
        p(3, 13, 3, 2, COL.brown)     -- 신발
        p(10, 13, 3, 2, COL.brown)
    else
        p(2, 8, 2, 3, COL.red)        -- 팔
        p(12, 8, 2, 3, COL.red)
        if pose == "walk1" then
            p(3, 12, 3, 2, COL.blue)  -- 다리 벌림
            p(10, 12, 3, 2, COL.blue)
            p(2, 14, 4, 2, COL.brown)
            p(10, 14, 4, 2, COL.brown)
        elseif pose == "walk2" then
            p(6, 12, 4, 2, COL.blue)  -- 다리 모음
            p(5, 14, 5, 2, COL.brown)
        else                          -- idle
            p(4, 12, 3, 2, COL.blue)
            p(9, 12, 3, 2, COL.blue)
            p(3, 14, 4, 2, COL.brown)
            p(9, 14, 4, 2, COL.brown)
        end
    end
end

-- pose: "walk1" | "walk2" | "squash"
local function drawEnemyFrame(pose)
    if pose == "squash" then
        p(2, 11, 12, 3, COL.ebrown)   -- 납작해진 몸통
        p(1, 14, 14, 2, COL.edark)
        return
    end
    p(4, 3, 8, 2, COL.ebrown)         -- 머리(돔)
    p(3, 5, 10, 4, COL.ebrown)
    p(2, 7, 12, 5, COL.ebrown)
    p(4, 7, 2, 3, COL.white)          -- 눈
    p(10, 7, 2, 3, COL.white)
    p(5, 8, 1, 2, COL.dark)
    p(10, 8, 1, 2, COL.dark)
    if pose == "walk1" then
        p(2, 13, 5, 3, COL.edark)     -- 발
        p(9, 12, 5, 3, COL.edark)
    else
        p(2, 12, 5, 3, COL.edark)
        p(9, 13, 5, 3, COL.edark)
    end
end

-- 코인 회전: 프레임별 폭이 다른 타원
local function drawCoinFrame(halfWidth)
    love.graphics.setColor(COL.yellow)
    love.graphics.ellipse("fill", 16, 16, halfWidth, 10)
    love.graphics.setColor(COL.ydark)
    love.graphics.ellipse("line", 16, 16, halfWidth, 10)
    if halfWidth > 5 then
        love.graphics.ellipse("line", 16, 16, halfWidth - 4, 6)
    end
end

local function makeSheet(frameCount, drawFrame)
    local canvas = love.graphics.newCanvas(frameCount * 32, 32)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    for i = 1, frameCount do
        love.graphics.push()
        love.graphics.translate((i - 1) * 32, 0)
        drawFrame(i)
        love.graphics.pop()
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    local img = love.graphics.newImage(canvas:newImageData())
    img:setFilter("nearest", "nearest")
    return img
end

function sprites.load()
    local playerPoses = { "idle", "walk1", "walk2", "jump" }
    sprites.playerImg = makeSheet(4, function(i) drawPlayerFrame(playerPoses[i]) end)
    sprites.playerGrid = anim8.newGrid(32, 32, sprites.playerImg:getWidth(), 32)

    local enemyPoses = { "walk1", "walk2", "squash" }
    sprites.enemyImg = makeSheet(3, function(i) drawEnemyFrame(enemyPoses[i]) end)
    sprites.enemyGrid = anim8.newGrid(32, 32, sprites.enemyImg:getWidth(), 32)

    local coinWidths = { 10, 6, 2, 6 }
    sprites.coinImg = makeSheet(4, function(i) drawCoinFrame(coinWidths[i]) end)
    sprites.coinGrid = anim8.newGrid(32, 32, sprites.coinImg:getWidth(), 32)
end

-- 애니메이션은 프레임 상태를 가지므로 엔티티마다 새로 만든다
function sprites.newPlayerAnims()
    return {
        idle = anim8.newAnimation(sprites.playerGrid(1, 1), 1),
        walk = anim8.newAnimation(sprites.playerGrid("2-3", 1), 0.12),
        jump = anim8.newAnimation(sprites.playerGrid(4, 1), 1),
    }
end

function sprites.newEnemyAnims()
    return {
        walk = anim8.newAnimation(sprites.enemyGrid("1-2", 1), 0.25),
        squash = anim8.newAnimation(sprites.enemyGrid(3, 1), 1),
    }
end

function sprites.newCoinAnim()
    return anim8.newAnimation(sprites.coinGrid("1-4", 1), 0.15)
end

return sprites
