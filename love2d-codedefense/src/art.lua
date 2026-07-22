-- art.lua — 네온 서버실 픽셀아트 모듈
-- 16x16 도트를 px=2로 시트화(=32px)해 quad로 그린다. 전장 타일은 직접 rectangle 조합.
-- 모든 draw 함수는 setColor를 스스로 관리하고 끝에 흰색을 복원한다. love.timer 미사용(t는 인자).
local art = {}

local function c(hex) -- "#RRGGBB" → {r,g,b}
    local r = tonumber(hex:sub(2, 3), 16) / 255
    local g = tonumber(hex:sub(4, 5), 16) / 255
    local b = tonumber(hex:sub(6, 7), 16) / 255
    return { r, g, b }
end

art.pal = {
    bg = c("#0e1220"), panel = c("#171c2e"), panelLight = c("#232a42"),
    grid = c("#1c2338"), green = c("#3cf07c"), cyan = c("#41d8e0"),
    magenta = c("#e04fd8"), red = c("#e8483f"), orange = c("#f0a03c"),
    purple = c("#a06ce8"), white = c("#e8ecf4"),
}

local function setCol(col, a)
    love.graphics.setColor(col[1], col[2], col[3], a or 1)
end

-- 단색 실루엣용 오버라이드. nil이면 정상 색, 아니면 이 색으로 모든 도트를 찍는다.
local monoColor = nil

-- 프레임 내부에서 1px 단위 도트를 찍는 헬퍼
local function dot(col, x, y, w, h)
    setCol(monoColor or col)
    love.graphics.rectangle("fill", x, y, w or 1, h or 1)
end

-- PX 단위 픽셀 사각형을 캔버스에 찍는 헬퍼로 16x16 시트를 그린 뒤 Image화
local function makeSheet(frames, px, size, drawFrame)
    local canvas = love.graphics.newCanvas(frames * size * px, size * px)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    for f = 1, frames do
        love.graphics.push()
        love.graphics.translate((f - 1) * size * px, 0)
        love.graphics.scale(px)
        drawFrame(f)
        love.graphics.pop()
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    local img = love.graphics.newImage(canvas:newImageData())
    img:setFilter("nearest", "nearest")
    return img
end

local SZ, PX = 16, 2
local FRAME = SZ * PX -- 32

art._img = {}
art._q = {}
art._nframes = {}

local function buildSheet(name, nFrames, drawFn, mono)
    local prev = monoColor
    monoColor = mono
    local img = makeSheet(nFrames, PX, SZ, drawFn)
    monoColor = prev
    art._img[name] = img
    art._nframes[name] = nFrames
    local q = {}
    for f = 1, nFrames do
        q[f] = love.graphics.newQuad((f - 1) * FRAME, 0, FRAME, FRAME, img:getDimensions())
    end
    art._q[name] = q
end

-- 시트 프레임을 화면에 그린다. logicalPx = 논리 픽셀 1개의 화면 크기(px).
-- 이미지 1논리픽셀 = PX(2)이므로 imageScale = logicalPx / PX.
local function drawSheet(name, frame, screenX, screenY, logicalPx)
    local img = art._img[name]
    if not img then return end
    local nF = art._nframes[name]
    if frame > nF then frame = nF end
    if frame < 1 then frame = 1 end
    local s = logicalPx / PX
    setCol(art.pal.white)
    love.graphics.draw(img, art._q[name][frame], screenX, screenY, 0, s, s)
end

--------------------------------------------------------------------------------
-- 에셋 프레임 정의 (16x16 논리 좌표)
--------------------------------------------------------------------------------

-- bug 몬스터 (2프레임 걷기 — 다리 위치 교차)
local function drawBugFrame(f)
    local P = art.pal
    dot(P.red, 4, 5, 8, 7)
    dot(P.red, 3, 6, 10, 5)
    dot(c("#a83028"), 8, 5, 1, 7) -- 등 갈라진 선
    dot(c("#a83028"), 5, 3, 6, 3) -- 머리
    dot(P.white, 5, 3, 2, 2); dot(c("#101018"), 6, 4, 1, 1) -- 눈
    dot(P.white, 9, 3, 2, 2); dot(c("#101018"), 9, 4, 1, 1)
    dot(c("#a83028"), 4, 1, 1, 2); dot(c("#a83028"), 11, 1, 1, 2) -- 더듬이
    local o = (f == 1) and 0 or 1
    dot(c("#601814"), 2, 7 + o, 2, 1); dot(c("#601814"), 12, 8 - o, 2, 1)
    dot(c("#601814"), 2, 9 - o, 2, 1); dot(c("#601814"), 12, 10 + o, 2, 1)
    dot(c("#601814"), 2, 11 + o, 2, 1); dot(c("#601814"), 12, 12 - o, 2, 1)
end

-- null-ptr: 보라 유령, 밑단 물결(프레임별 위상), 흰 물음표, 어두운 세로 눈
local function drawNullFrame(f)
    local P = art.pal
    local pur, dpur, dark = P.purple, c("#6c48a0"), c("#241640")
    dot(pur, 4, 3, 8, 10)
    dot(pur, 5, 2, 6, 1); dot(pur, 6, 1, 4, 1) -- 둥근 머리
    dot(dpur, 10, 3, 2, 10); dot(dpur, 10, 2, 1, 1) -- 오른쪽 음영
    dot(c("#c0a0f0"), 4, 3, 1, 8) -- 왼쪽 하이라이트
    -- 밑단 물결(3굴곡, 프레임별 위상 반전)
    if f == 1 then
        dot(pur, 4, 13, 2, 1); dot(pur, 7, 13, 2, 1); dot(pur, 10, 13, 2, 1)
    else
        dot(pur, 4, 13, 1, 1); dot(pur, 5, 13, 2, 1); dot(pur, 8, 13, 2, 1); dot(pur, 11, 13, 1, 1)
    end
    -- 눈 (어두운 세로 2도트)
    dot(dark, 6, 5, 1, 2); dot(dark, 9, 5, 1, 2)
    -- 흰 물음표
    dot(P.white, 6, 8, 3, 1) -- 상단 곡선
    dot(P.white, 8, 9, 1, 1) -- 오른쪽
    dot(P.white, 7, 10, 1, 1) -- 중앙으로
    dot(P.white, 7, 12, 1, 1) -- 점(gap 위)
end

-- concat-nil: 주황 슬라임 두 덩이 + 가운데 1px 다리(분열 예고), 프레임별 높이 교차
local function drawConcatFrame(f)
    local P = art.pal
    local org, dk, hl, eye = P.orange, c("#b06820"), c("#f8c860"), c("#3a2408")
    local lo = (f == 1) and 0 or 1 -- 왼쪽 눌림
    local ro = (f == 1) and 1 or 0 -- 오른쪽 눌림
    -- 왼쪽 덩이 (cols 2-6)
    dot(org, 2, 8 + lo, 5, 7 - lo)
    dot(org, 3, 6 + lo, 3, 2)
    dot(dk, 2, 14, 5, 1)
    dot(hl, 3, 8 + lo, 1, 2)
    dot(eye, 4, 10 + lo, 1, 1)
    -- 오른쪽 덩이 (cols 9-13)
    dot(org, 9, 8 + ro, 5, 7 - ro)
    dot(org, 10, 6 + ro, 3, 2)
    dot(dk, 9, 14, 5, 1)
    dot(hl, 10, 8 + ro, 1, 2)
    dot(eye, 11, 10 + ro, 1, 1)
    -- 연결 다리 (1px)
    dot(org, 6, 11, 4, 1)
end

-- printer 타워: 회색 몸체 + 상단 총구 슬릿(그린) + 측면 배기구 + 상태 LED. f>=3 → firing 플래시
local function drawPrinterFrame(f)
    local P = art.pal
    local gray, dgray, lgray = c("#5a6478"), c("#38414f"), c("#7a8498")
    local anim = (f - 1) % 2 -- 0/1
    local firing = f >= 3
    -- 총구 슬릿
    dot(P.green, 6, 3, 4, 1)
    -- 상단 하우징
    dot(dgray, 4, 4, 8, 2)
    -- 몸체
    dot(gray, 3, 6, 10, 9)
    dot(lgray, 3, 6, 10, 1) -- 윗변 하이라이트
    -- 측면 배기구
    dot(dgray, 4, 9, 1, 4); dot(dgray, 11, 9, 1, 4)
    dot(dgray, 4, 9, 8, 1); dot(dgray, 4, 11, 8, 1) -- 앞판 슬랫
    -- 상태 LED (프레임별 색 변화)
    dot(anim == 0 and P.green or P.cyan, 6, 12, 2, 2)
    dot(anim == 0 and P.cyan or P.orange, 8, 12, 2, 2)
    -- 발
    dot(dgray, 3, 14, 10, 1)
    -- 총구 플래시 오버레이 (3x3 흰/그린)
    if firing then
        dot(P.green, 5, 0, 6, 3)
        dot(P.white, 6, 0, 4, 2)
        dot(P.white, 7, 3, 2, 1)
    end
end

-- compiler 타워: 티얼 몸체 + 중앙 기어(프레임별 45도 회전 느낌), 공격 없음
local function drawCompilerFrame(f)
    local P = art.pal
    local teal, dteal = c("#1f6b72"), c("#123c40")
    dot(teal, 3, 5, 10, 10)
    dot(P.cyan, 3, 5, 10, 1) -- 윗변 하이라이트
    dot(dteal, 3, 14, 10, 1) -- 밑
    dot(dteal, 3, 5, 1, 10); dot(dteal, 12, 5, 1, 10) -- 측면 음영
    -- 중앙 기어 코어
    dot(P.cyan, 6, 8, 4, 4)
    dot(dteal, 7, 9, 2, 2) -- 축 구멍
    -- 기어 이빨 (프레임별 위치 교차)
    if f == 1 then
        dot(P.cyan, 7, 6, 2, 1); dot(P.cyan, 7, 12, 2, 1) -- 상/하
        dot(P.cyan, 4, 9, 1, 2); dot(P.cyan, 11, 9, 1, 2) -- 좌/우
    else
        dot(P.cyan, 5, 6, 1, 1); dot(P.cyan, 10, 6, 1, 1) -- 대각 4개
        dot(P.cyan, 5, 11, 1, 1); dot(P.cyan, 10, 11, 1, 1)
    end
end

-- sniper 타워: 좁은 받침 + 긴 안테나 + 끝 마젠타 발광(프레임별 크기). f>=3 → 안테나 끝 흰 플래시
local function drawSniperFrame(f)
    local P = art.pal
    local gray, dgray, lgray = c("#5a6478"), c("#38414f"), c("#8a94a8")
    local anim = (f - 1) % 2
    local firing = f >= 3
    -- 받침
    dot(gray, 5, 11, 6, 4)
    dot(lgray, 5, 11, 6, 1)
    dot(dgray, 4, 14, 8, 1)
    -- 기둥
    dot(gray, 7, 6, 2, 5)
    -- 안테나 (세로 6px)
    dot(lgray, 7, 1, 1, 7)
    -- 끝 마젠타 발광 (프레임별 크기)
    if anim == 0 then
        dot(P.magenta, 6, 0, 2, 2)
    else
        dot(P.magenta, 5, 0, 3, 2)
        dot(c("#f4a8ec"), 6, 0, 1, 1)
    end
    -- 발사 시 안테나 끝 흰 플래시
    if firing then
        dot(P.white, 5, 0, 3, 2)
        dot(P.white, 7, 1, 1, 4)
    end
end

-- 개발자 캐릭터 (16x16, 안경 쓴 남성)
local function drawDevFrame(pose, f)
    local P = art.pal
    local skin, hair, hood = c("#f0c8a0"), c("#4a3626"), c("#3a4a6a")
    dot(hood, 3, 10, 10, 6) -- 후드티 몸통
    dot(c("#2c3a54"), 3, 10, 10, 1) -- 어깨선
    dot(skin, 4, 3, 8, 7) -- 얼굴
    dot(hair, 3, 2, 10, 2); dot(hair, 3, 3, 1, 3); dot(hair, 12, 3, 1, 3) -- 머리카락
    dot(hair, 4, 4, 2, 1); dot(hair, 10, 4, 2, 1)
    -- 안경
    dot(c("#202430"), 4, 5, 3, 3); dot(c("#202430"), 9, 5, 3, 3)
    dot(P.cyan, 5, 6, 1, 1); dot(P.cyan, 10, 6, 1, 1) -- 모니터 빛 반사
    dot(c("#202430"), 7, 6, 2, 1) -- 브릿지
    if pose == "alarm" then
        dot(P.white, 4, 5, 3, 3); dot(P.white, 9, 5, 3, 3) -- 안경 흰 번쩍
        dot(c("#202430"), 6, 9, 4, 2) -- 벌린 입
    elseif pose == "idle" and f == 2 then
        dot(skin, 5, 6, 1, 1); dot(skin, 10, 6, 1, 1) -- 감은 눈
    end
    if pose ~= "alarm" then dot(c("#c09070"), 7, 9, 2, 1) end -- 입
    -- 팔/손
    if pose == "typing" then
        local o = (f == 1) and 0 or 1
        dot(hood, 2, 11, 1, 2); dot(hood, 13, 11, 1, 2)
        dot(skin, 2, 13 + o, 2, 1); dot(skin, 12, 14 - o, 2, 1)
    else
        dot(hood, 2, 12, 1, 3); dot(hood, 13, 12, 1, 3)
    end
end

--------------------------------------------------------------------------------
-- 시트 로드
--------------------------------------------------------------------------------
function art.load()
    if art._loaded then return end
    local P = art.pal
    -- 몬스터 (정상 + 흰 실루엣)
    buildSheet("enemy_bug", 2, drawBugFrame)
    buildSheet("enemy_bug_white", 2, drawBugFrame, P.white)
    buildSheet("enemy_null", 2, drawNullFrame)
    buildSheet("enemy_null_white", 2, drawNullFrame, P.white)
    buildSheet("enemy_concat", 2, drawConcatFrame)
    buildSheet("enemy_concat_white", 2, drawConcatFrame, P.white)
    -- 타워 (printer/sniper: 1-2 유휴, 3-4 발사 / compiler: 2 유휴)
    buildSheet("tower_printer", 4, drawPrinterFrame)
    buildSheet("tower_compiler", 2, drawCompilerFrame)
    buildSheet("tower_sniper", 4, drawSniperFrame)
    -- 개발자
    buildSheet("dev_idle", 2, function(f) drawDevFrame("idle", f) end)
    buildSheet("dev_typing", 2, function(f) drawDevFrame("typing", f) end)
    buildSheet("dev_alarm", 1, function(f) drawDevFrame("alarm", f) end)
    art._loaded = true
end

--------------------------------------------------------------------------------
-- 전장 타일 (32px, 좌상단 기준, 직접 rectangle 조합)
--------------------------------------------------------------------------------
local function rect(col, x, y, w, h, a)
    setCol(col, a)
    love.graphics.rectangle("fill", x, y, w, h)
end

function art.drawFloor(x, y)
    local P = art.pal
    rect(P.bg, x, y, 32, 32)
    setCol(P.grid)
    for i = 0, 32, 8 do
        love.graphics.rectangle("fill", x + i, y, 1, 32)
        love.graphics.rectangle("fill", x, y + i, 32, 1)
    end
    love.graphics.setColor(1, 1, 1)
end

function art.drawWall(x, y, t)
    local P = art.pal
    rect(P.panel, x, y, 32, 32)
    rect(P.panelLight, x, y, 32, 2) -- 상단 테두리
    rect(P.panelLight, x, y + 30, 32, 2) -- 하단 테두리
    rect(P.grid, x + 2, y + 4, 28, 22) -- 랙 창
    -- 서버 유닛 슬랫
    for i = 0, 3 do
        rect(P.panelLight, x + 3, y + 6 + i * 5, 26, 2)
    end
    -- LED 2개 (t 기반 green/cyan 점멸)
    local blink = (math.floor(t * 2) % 2) == 0
    rect(P.green, x + 5, y + 26, 4, 3, blink and 1 or 0.25)
    rect(P.cyan, x + 23, y + 26, 4, 3, blink and 0.25 or 1)
    love.graphics.setColor(1, 1, 1)
end

function art.drawPad(x, y, t)
    local P = art.pal
    art.drawFloor(x, y)
    -- 중앙 은은한 발광
    local a = 0.15 + 0.1 * math.sin(t * 3)
    rect(P.green, x + 8, y + 8, 16, 16, a)
    -- 모서리 브래킷 4개 (L자)
    setCol(P.green)
    local b = 6
    -- 좌상
    love.graphics.rectangle("fill", x + 3, y + 3, b, 2)
    love.graphics.rectangle("fill", x + 3, y + 3, 2, b)
    -- 우상
    love.graphics.rectangle("fill", x + 29 - b, y + 3, b, 2)
    love.graphics.rectangle("fill", x + 27, y + 3, 2, b)
    -- 좌하
    love.graphics.rectangle("fill", x + 3, y + 27, b, 2)
    love.graphics.rectangle("fill", x + 3, y + 29 - b, 2, b)
    -- 우하
    love.graphics.rectangle("fill", x + 29 - b, y + 27, b, 2)
    love.graphics.rectangle("fill", x + 27, y + 29 - b, 2, b)
    love.graphics.setColor(1, 1, 1)
end

function art.drawServerline(x, y, w, t)
    local P = art.pal
    local a = 0.5 + 0.3 * math.sin(t * 4)
    rect(P.cyan, x, y, w, 32, a * 0.5) -- 게이트 바
    rect(P.cyan, x, y, w, 4, a) -- 진한 상단부
    rect(P.white, x, y, w, 1) -- 상단 1px 흰 라인
    -- 스캔 눈금
    setCol(P.cyan, a * 0.6)
    for i = 0, w, 8 do
        love.graphics.rectangle("fill", x + i, y, 1, 6)
    end
    love.graphics.setColor(1, 1, 1)
end

--------------------------------------------------------------------------------
-- 시트 기반 draw 헬퍼
--------------------------------------------------------------------------------
local ENEMY = { bug = "enemy_bug", ["null-ptr"] = "enemy_null", ["concat-nil"] = "enemy_concat" }

function art.drawEnemy(id, x, y, t, hit)
    local base = ENEMY[id]
    if not base then return end
    local name = hit and (base .. "_white") or base
    local frame = (math.floor(t * 6) % 2) + 1
    drawSheet(name, frame, x - 16, y - 16, 2) -- 32px, 중심 정렬
    love.graphics.setColor(1, 1, 1)
end

function art.drawTower(id, x, y, t, firing)
    local name = "tower_" .. id
    if not art._img[name] then return end
    local anim = math.floor(t * 3) % 2
    local frame
    if firing and art._nframes[name] >= 4 then
        frame = 3 + anim
    else
        frame = 1 + anim
    end
    drawSheet(name, frame, x - 16, y - 16, 2) -- 32px, 중심 정렬
    love.graphics.setColor(1, 1, 1)
end

function art.drawDev(pose, x, y, scale, t)
    local name = "dev_" .. pose
    if not art._img[name] then return end
    local frame
    if pose == "idle" then
        frame = ((t % 3.5) < 0.15) and 2 or 1 -- 3.5초 주기 0.15초 깜빡임
    elseif pose == "typing" then
        frame = (math.floor(t * 8) % 2) + 1
    else
        frame = 1
    end
    drawSheet(name, frame, x, y, scale) -- 좌상단, 논리픽셀 = scale
    love.graphics.setColor(1, 1, 1)
end

--------------------------------------------------------------------------------
-- 로고 "CODE DEFENSE" (5x7 도트 폰트, cx 중심)
--------------------------------------------------------------------------------
local GLYPH = {
    C = { ".###.", "#...#", "#....", "#....", "#....", "#...#", ".###." },
    O = { ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
    D = { "###..", "#..#.", "#...#", "#...#", "#...#", "#..#.", "###.." },
    E = { "#####", "#....", "#....", "####.", "#....", "#....", "#####" },
    F = { "#####", "#....", "#....", "####.", "#....", "#....", "#...." },
    N = { "#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#" },
    S = { ".####", "#....", "#....", ".###.", "....#", "....#", "####." },
    [" "] = { ".....", ".....", ".....", ".....", ".....", ".....", "....." },
}

local function glyphW() return 5 end

local function drawGlyph(ch, px, py, s, col)
    local g = GLYPH[ch]
    if not g then return end
    setCol(col)
    for row = 1, 7 do
        local line = g[row]
        for cx2 = 1, 5 do
            if line:sub(cx2, cx2) == "#" then
                love.graphics.rectangle("fill", px + (cx2 - 1) * s, py + (row - 1) * s, s, s)
            end
        end
    end
end

function art.drawLogo(cx, y)
    local P = art.pal
    local s = 3 -- px=3
    local word1, word2 = "CODE", "DEFENSE"
    local gap = 1 -- 글자 사이 여백(도트)
    local spaceGap = 4 -- 단어 사이 여백(도트)
    local advance = (glyphW() + gap) * s
    local w1 = #word1 * advance - gap * s
    local w2 = #word2 * advance - gap * s
    local total = w1 + spaceGap * s + w2
    local startX = cx - total / 2
    local px = startX
    for i = 1, #word1 do
        drawGlyph(word1:sub(i, i), px, y, s, P.green)
        px = px + advance
    end
    px = px - gap * s + spaceGap * s
    for i = 1, #word2 do
        drawGlyph(word2:sub(i, i), px, y, s, P.cyan)
        px = px + advance
    end
    love.graphics.setColor(1, 1, 1)
end

return art
