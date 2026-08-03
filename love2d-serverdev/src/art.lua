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
    purple = c("#a06ce8"), white = c("#e8ecf4"), blue = c("#4f74e8"),
    yellow = c("#f2e050"),
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

-- 알파 있는 도트(반투명 효과용, monoColor 실루엣 오버라이드는 동일하게 존중)
local function dotA(col, a, x, y, w, h)
    setCol(monoColor or col, a)
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
-- 이미지 1논리픽셀 = PX(2)이므로 imageScale = logicalPx / PX. alpha(선택, 기본1)는 하이젠버그
-- 은신 깜빡임처럼 스프라이트 전체를 반투명하게 찍어야 할 때만 넘긴다(호출부가 없으면 기존과
-- 동일하게 완전 불투명).
local function drawSheet(name, frame, screenX, screenY, logicalPx, alpha)
    local img = art._img[name]
    if not img then return end
    local nF = art._nframes[name]
    if frame > nF then frame = nF end
    if frame < 1 then frame = 1 end
    local s = logicalPx / PX
    setCol(art.pal.white, alpha)
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

-- memory-leak: 부풀어 오르는 초록 물방울 + 우측 게이지(프레임2에서 몸집·게이지 모두 증가)
local function drawMemleakFrame(f)
    local P = art.pal
    local grn, dgrn, hl, eye = P.green, c("#1c6b38"), c("#b8f4cc"), c("#0e2414")
    local o = (f == 2) and 1 or 0 -- 프레임2: 살짝 부풀어오름
    dot(grn, 3 - o, 6 - o, 8 + o * 2, 7 + o)
    dot(grn, 4 - o, 4, 6 + o * 2, 2)
    dot(grn, 6, 2, 2, 2) -- 꼭짓점
    dot(dgrn, 3 - o, 12 + o, 8 + o * 2, 1) -- 밑단 음영
    dot(hl, 4 - o, 6 - o, 2, 3) -- 하이라이트
    dot(eye, 5, 9, 1, 1); dot(eye, 8, 9, 1, 1)
    -- 우측 게이지(누적 표시 — grow 능력의 시각적 예고)
    dot(dgrn, 13, 3, 2, 11)
    dot(grn, 13, 11, 2, 3)
    if o == 1 then dot(grn, 13, 7, 2, 4); dot(hl, 13, 3, 2, 2) end
end

-- deadlock: 서로 맞물린 자물쇠 2개(걸쇠가 중앙에서 교차) — 프레임별 팽팽한 당김(1px 진동)
local function drawDeadlockFrame(f)
    local P = art.pal
    local blu, dblu, lblu = P.blue, c("#22367a"), c("#a8bdf5")
    local o = (f == 2) and 1 or 0
    -- 왼쪽 자물쇠 몸체
    dot(blu, 1, 9 + o, 6, 6)
    dot(lblu, 1, 9 + o, 6, 1)
    dot(dblu, 1, 14 + o, 6, 1)
    dot(c("#101830"), 3, 11 + o, 1, 2)
    -- 왼쪽 걸쇠(우상단으로 뻗어 중앙에서 교차)
    dot(dblu, 4, 4, 6, 3)
    dot(blu, 5, 5, 4, 2)
    -- 오른쪽 자물쇠 몸체
    dot(blu, 9, 9 - o, 6, 6)
    dot(lblu, 9, 9 - o, 6, 1)
    dot(dblu, 9, 14 - o, 6, 1)
    dot(c("#101830"), 12, 11 - o, 1, 2)
    -- 오른쪽 걸쇠(좌상단으로 뻗어 중앙에서 교차)
    dot(dblu, 6, 3, 6, 3)
    dot(blu, 7, 4, 4, 2)
end

-- heisenbug: 각진 반투명 유령(관측하면 사라진다 — 프레임2에서 몸체 알파가 크게 옅어짐).
-- 눈·물음표는 항상 또렷하게 남긴다("정체는 분명한데 실체가 안 잡힌다").
local function drawHeisenbugFrame(f)
    local P = art.pal
    local pur, dpur = P.purple, c("#4a2c78")
    local a = (f == 1) and 0.55 or 0.2
    dotA(pur, a, 4, 3, 8, 9)
    dotA(pur, a, 3, 5, 1, 7); dotA(pur, a, 12, 5, 1, 7)
    dotA(dpur, a, 4, 3, 8, 1)
    -- 밑단 각진 지그재그(null-ptr의 둥근 물결과 구분)
    dotA(pur, a, 4, 12, 2, 2); dotA(pur, a, 8, 12, 2, 2); dotA(pur, a, 11, 12, 1, 2)
    dotA(pur, a, 6, 13, 2, 1); dotA(pur, a, 10, 13, 1, 1)
    -- 눈(어두운 세로 2도트, 항상 또렷)
    dot(c("#180c28"), 6, 6, 1, 2); dot(c("#180c28"), 9, 6, 1, 2)
    -- 흰 물음표(항상 또렷)
    dot(P.white, 6, 8, 3, 1)
    dot(P.white, 8, 9, 1, 1)
    dot(P.white, 7, 10, 1, 1)
end

-- fork-bomb: 포크(3갈래) + 손잡이 + 도화선 스파크(프레임별 위치 교차 — 자기복제 폭발 예고)
local function drawForkbombFrame(f)
    local P = art.pal
    local org, dork, hl, wht = P.orange, c("#a3501c"), c("#ffe0a0"), P.white
    dot(org, 7, 6, 2, 7) -- 손잡이
    dot(dork, 7, 12, 2, 1)
    dot(org, 4, 2, 2, 5); dot(org, 7, 1, 2, 6); dot(org, 10, 2, 2, 5) -- 갈래 3개
    dot(hl, 4, 2, 1, 2); dot(hl, 7, 1, 1, 2); dot(hl, 10, 2, 1, 2)
    dot(org, 4, 6, 8, 1) -- 갈래를 잇는 목
    dot(dork, 6, 13, 1, 2); dot(dork, 9, 13, 1, 2) -- 도화선
    if f == 1 then
        dot(wht, 5, 14, 1, 1); dot(hl, 10, 14, 1, 1)
    else
        dot(hl, 5, 14, 1, 1); dot(wht, 10, 14, 1, 1); dot(hl, 7, 15, 1, 1)
    end
end

-- race-cond: 앞으로 기울어진 주자 + 왼쪽으로 뻗은 번개 꼬리(교차 스텝 애니메이션)
local function drawRacecondFrame(f)
    local P = art.pal
    local yl, dyl, wht = P.yellow, c("#a37800"), P.white
    local o = (f == 1) and 0 or 1
    dot(yl, 7, 5, 5, 6) -- 몸통
    dot(dyl, 7, 10, 5, 1)
    dot(yl, 8, 2, 3, 3) -- 머리
    dot(c("#3a2c08"), 9, 3, 1, 1) -- 눈
    dot(dyl, 12, 6, 2, 2) -- 앞으로 뻗은 팔
    dot(dyl, 7, 11 + o, 2, 3 - o); dot(dyl, 10, 12 - o, 2, 2 + o) -- 교차 다리
    -- 번개 꼬리(지그재그)
    dot(wht, 4, 6, 3, 1); dot(wht, 2, 7, 3, 1); dot(wht, 0, 8, 3, 1)
    dot(yl, 3, 9, 2, 1); dot(yl, 1, 10, 2, 1)
end

-- legacy: 먼지 쌓인 거미줄 상자(두 모서리 거미줄 + 미세한 먼지 부유)
local function drawLegacyFrame(f)
    local wood, dwood, lwood, web = c("#8a6a3c"), c("#5c4322"), c("#b4956a"), c("#d8d0c0")
    dot(wood, 3, 5, 10, 9)
    dot(lwood, 3, 5, 10, 1)
    dot(dwood, 3, 13, 10, 1)
    dot(dwood, 6, 5, 1, 9); dot(dwood, 9, 5, 1, 9) -- 나무결
    -- 거미줄(좌상단)
    dot(web, 3, 5, 4, 1); dot(web, 3, 5, 1, 4)
    dot(web, 4, 6, 2, 1); dot(web, 4, 6, 1, 2)
    -- 거미줄(우상단)
    dot(web, 9, 5, 4, 1); dot(web, 12, 5, 1, 4)
    dot(web, 10, 6, 2, 1); dot(web, 11, 6, 1, 2)
    -- 먼지(프레임별 위치 이동)
    if f == 1 then
        dot(web, 5, 3, 1, 1); dot(web, 11, 9, 1, 1); dot(web, 8, 2, 1, 1)
    else
        dot(web, 6, 2, 1, 1); dot(web, 10, 10, 1, 1); dot(web, 9, 3, 1, 1)
    end
end

-- ddos-bot: 작은 미니 드론 한 대(개별은 하찮다는 컨셉으로 캔버스 중앙에 작게)
-- 프로펠러가 "+"형/"x"형으로 교차해 회전감을 준다
local function drawDdosbotFrame(f)
    local P = art.pal
    local red, dred, hl = P.red, c("#7a1e18"), c("#ffb0a0")
    dot(dred, 6, 6, 4, 4); dot(red, 7, 7, 2, 2) -- 몸체
    dot(dred, 4, 4, 2, 1); dot(dred, 10, 4, 2, 1)
    dot(dred, 4, 11, 2, 1); dot(dred, 10, 11, 2, 1)
    if f == 1 then
        dot(hl, 4, 3, 2, 1); dot(hl, 10, 3, 2, 1)
        dot(hl, 4, 12, 2, 1); dot(hl, 10, 12, 2, 1)
    else
        dot(hl, 3, 4, 1, 2); dot(hl, 12, 4, 1, 2)
        dot(hl, 3, 10, 1, 2); dot(hl, 12, 10, 1, 2)
    end
    dot(f == 1 and P.white or red, 7, 7, 1, 1) -- 점멸 표시등
end

-- kernel-panic: 깨진 화면(BSOD 청색 + 적색 균열) — 프레임2에서 균열이 마젠타/흰색으로 번쩍인다
local function drawKernelpanicFrame(f)
    local P = art.pal
    local bsod, dbsod, red = c("#1030a0"), c("#0a1c60"), P.red
    dot(c("#22283a"), 2, 2, 12, 12) -- 베젤
    dot(bsod, 3, 3, 10, 10) -- 화면
    dot(c("#c0d0f0"), 4, 4, 6, 1); dot(c("#c0d0f0"), 4, 6, 4, 1) -- 코드 라인 흔적
    -- 균열(지그재그로 화면을 가로지름)
    dot(red, 5, 3, 1, 2); dot(red, 6, 5, 1, 2); dot(red, 5, 7, 1, 2)
    dot(red, 4, 9, 1, 2); dot(red, 6, 9, 2, 1); dot(red, 8, 8, 1, 3)
    dot(red, 9, 6, 1, 2); dot(red, 10, 4, 1, 2)
    dot(dbsod, 6, 14, 4, 1) -- 받침대
    if f == 2 then -- 글리치 플래시
        dotA(P.magenta, 0.6, 3, 3, 10, 10)
        dotA(P.white, 0.8, 5, 3, 1, 2); dotA(P.white, 0.8, 8, 8, 1, 3)
    end
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

-- gugu-class 타워: 김이 나는 커피잔(자바 밈, 구구단 상징 "9" 도트). 받침(소서) + 머그컵 + 손잡이 +
-- 컵 표면 주황 "9" + 김(스팀, 프레임별 위상 교차 유휴 애니). f>=3 → 김 위 흰/주황 플래시 오버레이
local function drawGuguFrame(f)
    local P = art.pal
    local cream, creamLight, creamDark = c("#f0ece0"), c("#fbf8f0"), c("#c8c0a8")
    local dgray, lgray, steamCol = c("#454c5c"), c("#6a7488"), c("#dfe4ee")
    local anim = (f - 1) % 2 -- 0/1: 김 위상 교차
    local firing = f >= 3
    -- 받침(소서)
    dot(dgray, 2, 14, 12, 2)
    dot(lgray, 2, 14, 12, 1)
    -- 머그컵 몸체
    dot(cream, 4, 6, 7, 7)
    dot(creamLight, 4, 6, 7, 1) -- 윗변 하이라이트
    dot(creamDark, 4, 12, 7, 1) -- 아랫단 음영
    -- 손잡이(오른쪽 고리)
    dot(cream, 11, 8, 2, 1)
    dot(cream, 12, 9, 1, 2)
    dot(cream, 11, 11, 2, 1)
    -- 컵 표면 "9" 도트 문양(구구단 상징, 주황)
    dot(P.orange, 6, 7, 3, 1)
    dot(P.orange, 6, 8, 1, 1); dot(P.orange, 8, 8, 1, 1)
    dot(P.orange, 6, 9, 3, 1)
    dot(P.orange, 8, 10, 1, 1)
    -- 김(스팀) 2가닥, 프레임별 위상 교차
    if anim == 0 then
        dot(steamCol, 5, 3, 1, 3)
        dot(steamCol, 4, 1, 1, 2)
        dot(steamCol, 8, 2, 1, 3)
        dot(steamCol, 9, 0, 1, 2)
    else
        dot(steamCol, 5, 2, 1, 3)
        dot(steamCol, 6, 0, 1, 2)
        dot(steamCol, 8, 3, 1, 3)
        dot(steamCol, 7, 1, 1, 2)
    end
    -- 발사 시 김 위쪽 흰/주황 스파크 플래시(십자 버스트 — 뚜껑처럼 안 보이게 중앙만 밝힌다)
    if firing then
        dot(P.orange, 4, 1, 1, 1); dot(P.orange, 11, 1, 1, 1) -- 좌우 플레어
        dot(P.white, 6, 0, 4, 2) -- 중앙 밝은 코어
        dot(P.orange, 7, 0, 2, 1)
    end
end

-- gc-collector 타워: 쓰레기통 몸체 + 재활용 마크 + 옆 집게 팔. f>=3 → 상단 광역 수거 플래시
local function drawGcCollectorFrame(f)
    local P = art.pal
    local mint, dmint, lmint = c("#3f9a72"), c("#215c42"), c("#8fe0bc")
    local anim = (f - 1) % 2
    local firing = f >= 3
    dot(dmint, 4, 6, 8, 8) -- 몸통
    dot(mint, 4, 6, 8, 1)
    dot(dmint, 4, 13, 8, 1)
    local lidY = 4 + anim -- 뚜껑(살짝 열린 각도 애니메이션)
    dot(lmint, 3, lidY, 10, 2)
    dot(c("#173226"), 6, 8, 4, 4) -- 재활용 마크
    dot(mint, 7, 9, 2, 2)
    -- 집게 팔(프레임별 벌림/오므림)
    local armO = (anim == 0) and 0 or 1
    dot(dmint, 12, 7, 2, 1 + armO)
    dot(dmint, 12, 10 - armO, 2, 1 + armO)
    dot(lmint, 14, 6 - armO, 1, 2)
    dot(lmint, 14, 10 + armO, 1, 2)
    dot(dmint, 4, 14, 8, 1) -- 발
    if firing then -- 광역 수거 플래시(상단으로 퍼지는 링)
        dot(P.white, 5, 1, 6, 2)
        dot(mint, 3, 0, 10, 1)
    end
end

-- debugger 타워: 돋보기(렌즈+손잡이) + 렌즈 안 일시정지 막대 2개(브레이크포인트 상징).
-- 공격하지 않으므로 firing 프레임 없음(compiler와 동일하게 2프레임 유휴만).
local function drawDebuggerFrame(f)
    local P = art.pal
    local cy, dcy, lcy = P.cyan, c("#1c5860"), c("#b0eef2")
    dot(dcy, 4, 2, 8, 8) -- 렌즈
    dot(cy, 5, 3, 6, 6)
    dot(lcy, 6, 4, 2, 2) -- 유리 하이라이트
    dot(c("#2a3140"), 11, 10, 2, 2); dot(c("#2a3140"), 12, 11, 2, 2); dot(c("#2a3140"), 13, 12, 2, 2) -- 손잡이
    dot(c("#0a2226"), 6, 4, 2, 5); dot(c("#0a2226"), 9, 4, 2, 5) -- 일시정지 막대 2개
    if f == 1 then
        dot(P.white, 5, 3, 1, 1)
    else
        dot(P.white, 10, 3, 1, 1)
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
    -- Wave B 신규 적 8종 (정상 + 흰 실루엣)
    buildSheet("enemy_memleak", 2, drawMemleakFrame)
    buildSheet("enemy_memleak_white", 2, drawMemleakFrame, P.white)
    buildSheet("enemy_deadlock", 2, drawDeadlockFrame)
    buildSheet("enemy_deadlock_white", 2, drawDeadlockFrame, P.white)
    buildSheet("enemy_heisenbug", 2, drawHeisenbugFrame)
    buildSheet("enemy_heisenbug_white", 2, drawHeisenbugFrame, P.white)
    buildSheet("enemy_forkbomb", 2, drawForkbombFrame)
    buildSheet("enemy_forkbomb_white", 2, drawForkbombFrame, P.white)
    buildSheet("enemy_racecond", 2, drawRacecondFrame)
    buildSheet("enemy_racecond_white", 2, drawRacecondFrame, P.white)
    buildSheet("enemy_legacy", 2, drawLegacyFrame)
    buildSheet("enemy_legacy_white", 2, drawLegacyFrame, P.white)
    buildSheet("enemy_ddos", 2, drawDdosbotFrame)
    buildSheet("enemy_ddos_white", 2, drawDdosbotFrame, P.white)
    buildSheet("enemy_kernelpanic", 2, drawKernelpanicFrame)
    buildSheet("enemy_kernelpanic_white", 2, drawKernelpanicFrame, P.white)
    -- 타워 (printer/sniper: 1-2 유휴, 3-4 발사 / compiler: 2 유휴)
    buildSheet("tower_printer", 4, drawPrinterFrame)
    buildSheet("tower_compiler", 2, drawCompilerFrame)
    buildSheet("tower_sniper", 4, drawSniperFrame)
    buildSheet("tower_gugu-class", 4, drawGuguFrame)
    -- Wave B 신규 타워 2종
    buildSheet("tower_gc-collector", 4, drawGcCollectorFrame)
    buildSheet("tower_debugger", 2, drawDebuggerFrame)
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
local ENEMY = {
    bug = "enemy_bug", ["null-ptr"] = "enemy_null", ["concat-nil"] = "enemy_concat",
    ["memory-leak"] = "enemy_memleak", deadlock = "enemy_deadlock", heisenbug = "enemy_heisenbug",
    ["fork-bomb"] = "enemy_forkbomb", ["race-cond"] = "enemy_racecond", legacy = "enemy_legacy",
    ["ddos-bot"] = "enemy_ddos", ["kernel-panic"] = "enemy_kernelpanic",
}

-- alpha(선택, 기본1): 하이젠버그 은신 중 스프라이트를 반투명(0.25)으로 깜빡이는 용도.
function art.drawEnemy(id, x, y, t, hit, alpha)
    local base = ENEMY[id]
    if not base then return end
    local name = hit and (base .. "_white") or base
    local frame = (math.floor(t * 6) % 2) + 1
    drawSheet(name, frame, x - 16, y - 16, 2, alpha) -- 32px, 중심 정렬
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
-- 게임 심볼 — 룩(Rook, 체스 성탑). 타워 디펜스를 상징하는 16x16 도트.
-- 하단 받침 2줄 + 몸통 기둥 + 상단 총안(crenellation) 3개 돌출. green 몸체 + cyan 하이라이트.
-- 시트로 캐싱하지 않고 매 호출 직접 그린다(art.drawRook) — 창 아이콘은 rookIconData()가
-- 같은 도트를 ImageData에 2배 스케일로 직접 찍어 만든다(정적, t 없음).
--------------------------------------------------------------------------------
-- {컬러키, x, y, w, h} — 16x16 논리 좌표. green을 먼저 채우고 cyan을 나중에 겹쳐 하이라이트로 삼는다.
local ROOK_DOTS = {
    -- 상단 총안 3개 돌출
    { "green", 3, 1, 2, 3 }, { "green", 7, 1, 2, 3 }, { "green", 11, 1, 2, 3 },
    -- 총안 사이를 잇는 브릿지(몸통 상단)
    { "green", 3, 4, 10, 1 },
    -- 몸통 기둥
    { "green", 4, 5, 8, 8 },
    -- 하단 받침 2줄(몸통보다 넓게)
    { "green", 2, 13, 12, 1 }, { "green", 2, 14, 12, 1 },
    -- cyan 하이라이트: 총안 캡 + 몸통 좌측 세로선
    { "cyan", 3, 1, 2, 1 }, { "cyan", 7, 1, 2, 1 }, { "cyan", 11, 1, 2, 1 },
    { "cyan", 4, 5, 1, 8 },
}

-- (x, y) 좌상단 기준으로 scale배 확대해 룩을 직접 그린다. t로 가운데 총안 위 미세한 발광이 변한다.
function art.drawRook(x, y, scale, t)
    local P = art.pal
    for _, dd in ipairs(ROOK_DOTS) do
        setCol(P[dd[1]])
        love.graphics.rectangle("fill", x + dd[2] * scale, y + dd[3] * scale, dd[4] * scale, dd[5] * scale)
    end
    -- 가운데 총안 위 미세 발광 펄스
    local glow = 0.35 + 0.25 * math.sin((t or 0) * 3)
    setCol(P.cyan, glow)
    love.graphics.rectangle("fill", x + 7 * scale, y, 2 * scale, 1 * scale)
    love.graphics.setColor(1, 1, 1)
end

-- 같은 16x16 도트를 2배 스케일(=32x32)로 ImageData에 직접 찍어 만든다. 투명 배경, 정적(t 없음) —
-- love.window.setIcon(art.rookIconData())로 창/작업표시줄 아이콘에 쓴다.
function art.rookIconData()
    local P = art.pal
    local px = 2
    local img = love.image.newImageData(SZ * px, SZ * px)
    img:mapPixel(function() return 0, 0, 0, 0 end)
    for _, dd in ipairs(ROOK_DOTS) do
        local col = P[dd[1]]
        for oy = 0, dd[5] * px - 1 do
            for ox = 0, dd[4] * px - 1 do
                img:setPixel(dd[2] * px + ox, dd[3] * px + oy, col[1], col[2], col[3], 1)
            end
        end
    end
    return img
end

--------------------------------------------------------------------------------
-- 타이틀 메인 게임명("서버실"/"개발자") — 폰트 렌더 기반(문장형 제목이라 5x7 도트 픽셀
-- 레터링 대신 큰 폰트 2줄로 배치). 룩 심볼과 마찬가지로 love.timer를 직접 부르지 않고 t를
-- 인자로 받아 미세한 발광 펄스만 준다. 모토(부제)·기존 설명 태그라인은 이 블록 아래
-- (states/title.lua)에서 별도로 그린다 — 이 모듈은 메인 타이틀 2줄(그린→시안 네온)만 담당한다.
--------------------------------------------------------------------------------
local TITLE_LINE1, TITLE_LINE2 = "서버실", "개발자"

-- 2줄 제목 블록의 총 높이(그리지 않고 계산만) — 호출부(title.lua)가 draw 전에 레이아웃을
-- 잡을 때 drawTitleText와 동일한 lh 공식을 쓰도록 단일 지점으로 뽑아 둔다(드리프트 방지).
local function titleLineH(font) return font:getHeight() + 4 end
function art.titleTextHeight(font) return titleLineH(font) * 2 end

-- (cx, y) 상단 중앙 기준으로 title 폰트 2줄을 그린다. 그린→시안 그라데이션 + 옅은 자홍 글로우
-- 레이어를 살짝 오프셋해 겹쳐 네온 발광 느낌을 낸다(픽셀 시절 CODE=green/DEFENSE=cyan 배색을
-- 이어받아 2026-07-27 재개명 후에도 "서버실"=green/"개발자"=cyan으로 유지).
function art.drawTitleText(cx, y, font, t)
    local P = art.pal
    local W = love.graphics.getWidth()
    love.graphics.setFont(font)
    local lh = titleLineH(font)
    local glow = 0.28 + 0.1 * math.sin((t or 0) * 2)

    -- 글로우 레이어(자홍, 약간의 오프셋으로 번짐 표현)
    setCol(P.magenta, glow)
    love.graphics.printf(TITLE_LINE1, cx - W / 2 - 1, y - 1, W, "center")
    love.graphics.printf(TITLE_LINE2, cx - W / 2 - 1, y + lh - 1, W, "center")
    setCol(P.magenta, glow)
    love.graphics.printf(TITLE_LINE1, cx - W / 2 + 1, y + 1, W, "center")
    love.graphics.printf(TITLE_LINE2, cx - W / 2 + 1, y + lh + 1, W, "center")

    -- 메인 텍스트
    setCol(P.green)
    love.graphics.printf(TITLE_LINE1, cx - W / 2, y, W, "center")
    setCol(P.cyan)
    love.graphics.printf(TITLE_LINE2, cx - W / 2, y + lh, W, "center")
    love.graphics.setColor(1, 1, 1)
    return lh * 2 -- 호출부가 다음 요소(부제)를 배치할 때 쓰라고 총 높이를 돌려준다
end

--------------------------------------------------------------------------------
-- 인트로 컷신 일러스트 4종 (960×420 영역, 0,0 기준. love.timer 미사용 — t 인자)
--------------------------------------------------------------------------------

-- drawWall 을 s배 확대해 (x,y)에 그린다 (서버랙 확대용)
local function bigWall(x, y, s, t)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(s)
    art.drawWall(0, 0, t)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- 하트 (cx, cy 중심)
local function heart(col, cx, cy, r)
    setCol(col)
    love.graphics.circle("fill", cx - r * 0.55, cy - r * 0.35, r * 0.6)
    love.graphics.circle("fill", cx + r * 0.55, cy - r * 0.35, r * 0.6)
    love.graphics.polygon("fill", cx - r, cy, cx + r, cy, cx, cy + r * 1.2)
end

-- 말풍선 (꼬리 아래) + 안의 심볼 그리기
local function bubble(cx, cy, w, h, kind)
    local P = art.pal
    setCol(P.white)
    love.graphics.rectangle("fill", cx - w / 2, cy - h / 2, w, h, 5, 5)
    love.graphics.polygon("fill", cx - 5, cy + h / 2 - 1, cx + 5, cy + h / 2 - 1, cx - 2, cy + h / 2 + 8)
    if kind == "heart" then
        heart(P.magenta, cx, cy - 2, 7)
    else -- "!"
        setCol(P.red)
        love.graphics.rectangle("fill", cx - 2, cy - 9, 4, 11)
        love.graphics.rectangle("fill", cx - 2, cy + 4, 4, 4)
    end
    love.graphics.setColor(1, 1, 1)
end

-- 지상 서비스 이용자 (발밑 중심 px, 바닥 py)
local function drawCitizen(px, py, shirt, kind, t)
    local skin, hair = c("#f2cca0"), c("#3a2a1c")
    -- 다리 + 신발
    rect(c("#33405e"), px - 10, py - 24, 8, 24)
    rect(c("#33405e"), px + 2, py - 24, 8, 24)
    rect(c("#20283c"), px - 11, py - 3, 9, 3); rect(c("#20283c"), px + 2, py - 3, 9, 3)
    -- 몸통
    rect(shirt, px - 12, py - 50, 24, 27)
    rect(c("#000000"), px - 12, py - 50, 24, 2, 0.12) -- 어깨 음영
    -- 목/머리
    rect(skin, px - 4, py - 54, 8, 5)
    rect(skin, px - 9, py - 71, 18, 18)
    rect(hair, px - 10, py - 74, 20, 8)
    rect(hair, px - 10, py - 71, 3, 9); rect(hair, px + 7, py - 71, 3, 9)
    -- 폰 든 팔 (앞으로) + 스마트폰
    rect(shirt, px + 8, py - 47, 7, 5)
    rect(skin, px + 13, py - 47, 5, 15)
    rect(c("#161a24"), px + 15, py - 55, 13, 21)
    local glow = 0.55 + 0.35 * math.sin(t * 3 + px)
    setCol(art.pal.cyan, glow)
    love.graphics.rectangle("fill", px + 17, py - 52, 9, 15)
    setCol(art.pal.white, glow * 0.7)
    love.graphics.rectangle("fill", px + 18, py - 50, 7, 3)
    love.graphics.setColor(1, 1, 1)
    -- 말풍선 (머리 위, 부드러운 상하 진동)
    local by = py - 92 + math.sin(t * 2 + px) * 2
    bubble(px + 4, by, 34, 26, kind)
end

-- 벽시계 (아날로그, 3:00 표시)
local function drawWallClock(cx, cy, r)
    local P = art.pal
    setCol(c("#e8ecf4"))
    love.graphics.circle("fill", cx, cy, r)
    setCol(c("#20283c"))
    love.graphics.circle("line", cx, cy, r)
    setCol(c("#3a4256"))
    for i = 0, 11 do
        local a = i * math.pi / 6
        love.graphics.rectangle("fill", cx + math.cos(a) * (r - 3) - 1, cy + math.sin(a) * (r - 3) - 1, 2, 2)
    end
    -- 3:00 — 분침 위(12), 시침 우(3)
    love.graphics.setLineWidth(2)
    setCol(c("#20283c"))
    love.graphics.line(cx, cy, cx, cy - r * 0.62)          -- 분침
    setCol(c("#b03028"))
    love.graphics.line(cx, cy, cx + r * 0.5, cy)            -- 시침
    love.graphics.setLineWidth(1)
    setCol(P.red)
    love.graphics.circle("fill", cx, cy, 2)
    love.graphics.setColor(1, 1, 1)
end

-- 서버실 공용 배경 (씬 2·3 공유). alarm=true 면 붉은 비상 톤
local function drawServerRoom(t, alarm)
    local P = art.pal
    -- 어두운 바닥/벽
    rect(c("#080b14"), 0, 0, 960, 420)
    rect(c("#0c1120"), 0, 250, 960, 170)          -- 바닥
    -- 바닥 원근 격자
    setCol(P.grid, 0.5)
    for i = 0, 960, 48 do love.graphics.rectangle("fill", i, 250, 1, 170) end
    for j = 0, 170, 24 do love.graphics.rectangle("fill", 0, 250 + j, 960, 1) end
    -- 서버랙 6대 (뒤열 3 + 앞열 3, 원근감)
    bigWall(70, 70, 2.4, t)
    bigWall(190, 70, 2.4, t)
    bigWall(310, 70, 2.4, t)
    bigWall(40, 190, 3.0, t)
    bigWall(180, 190, 3.0, t)
    bigWall(320, 190, 3.0, t)
    -- 구석 책상 (우측)
    rect(c("#241a12"), 640, 300, 260, 90)          -- 책상
    rect(c("#160f0a"), 640, 300, 260, 6)
    -- 모니터
    rect(c("#0a0e18"), 720, 190, 130, 96)          -- 베젤
    local scr = alarm and P.red or P.cyan
    setCol(scr, alarm and 0.9 or 0.8)
    love.graphics.rectangle("fill", 728, 198, 114, 80)
    -- 화면 코드 라인
    setCol(P.white, 0.5)
    for i = 0, 6 do love.graphics.rectangle("fill", 736, 206 + i * 10, 60 + (i % 3) * 20, 3) end
    rect(c("#0a0e18"), 780, 286, 10, 18)           -- 스탠드
    rect(c("#0a0e18"), 760, 304, 50, 4)
    -- 모니터 발광 원뿔 (알파 다각형, 개발자 쪽으로)
    setCol(scr, alarm and 0.16 or 0.12)
    love.graphics.polygon("fill", 785, 240, 690, 340, 690, 400, 900, 400, 900, 300)
    love.graphics.setColor(1, 1, 1)
    -- 개발자 (책상 앞, 모니터 불빛 아래) — idle
    art.drawDev(alarm and "alarm" or "idle", 630, 250, 4, t)
    -- 벽시계 (3:00)
    drawWallClock(560, 90, 34)
    if alarm then
        -- 붉은 앰비언트 워시 + 랙 사이 붉은 LED 오버레이
        setCol(P.red, 0.10 + 0.05 * math.sin(t * 6))
        love.graphics.rectangle("fill", 0, 0, 960, 420)
        setCol(P.red, 0.6 + 0.4 * math.sin(t * 8))
        for _, xy in ipairs({ { 96, 155 }, { 216, 155 }, { 336, 155 }, { 70, 320 }, { 210, 320 }, { 350, 320 } }) do
            love.graphics.rectangle("fill", xy[1], xy[2], 10, 6)
        end
        love.graphics.setColor(1, 1, 1)
    end
end

-- 확대된 적 (id, 중심 px,py, s배)
local function bigEnemy(id, px, py, s, t)
    love.graphics.push()
    love.graphics.translate(px, py)
    love.graphics.scale(s)
    art.drawEnemy(id, 0, 0, t, false)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- 씬 1: 지상 — 화려한 서비스
local function drawIntro1(t)
    local P = art.pal
    -- 하늘 그라데이션 3단
    rect(c("#7ec8ee"), 0, 0, 960, 130)
    rect(c("#a9dcf0"), 0, 130, 960, 90)
    rect(c("#d8eee2"), 0, 220, 960, 70)
    -- 해 + 글로우
    setCol(c("#fff4c0"), 0.5); love.graphics.circle("fill", 810, 78, 62)
    setCol(c("#fff8dc")); love.graphics.circle("fill", 810, 78, 38)
    -- 건물 스카이라인 (실루엣 + 창문)
    local blds = {
        { 20, 150, 110, "#4a6a86" }, { 120, 110, 150, "#3e5c78" }, { 260, 90, 200, "#48678a" },
        { 450, 130, 130, "#3a5670" }, { 570, 100, 170, "#42627e" }, { 730, 120, 150, "#3e5c78" },
        { 870, 150, 130, "#48678a" },
    }
    for _, b2 in ipairs(blds) do
        rect(c(b2[4]), b2[1], 290 - b2[3], b2[2], b2[3])
        setCol(c("#fff0a0"), 0.55)
        for wy = 290 - b2[3] + 12, 290 - 14, 22 do
            for wx = b2[1] + 8, b2[1] + b2[2] - 12, 20 do
                if (wx + wy) % 3 ~= 0 then love.graphics.rectangle("fill", wx, wy, 8, 10) end
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
    -- 인도
    rect(c("#cfc7b6"), 0, 290, 960, 130)
    rect(c("#b6ad9a"), 0, 290, 960, 5)
    setCol(c("#a49a86"))
    for i = 60, 960, 120 do love.graphics.rectangle("fill", i, 296, 2, 124) end
    love.graphics.setColor(1, 1, 1)
    -- 사람 3명 (폰 사용, 말풍선)
    drawCitizen(230, 410, c("#e0554e"), "heart", t)
    drawCitizen(480, 415, c("#4f8de0"), "bang", t)
    drawCitizen(720, 408, c("#4fc07c"), "heart", t)
end

-- 씬 2: 지하 — 서버실
local function drawIntro2(t)
    drawServerRoom(t, false)
end

-- 씬 3: 장애 발생
local function drawIntro3(t)
    local P = art.pal
    drawServerRoom(t, true)
    -- 랙 사이에서 기어나오는 버그/널포인터 6마리
    bigEnemy("bug", 130, 300, 2.0, t)
    bigEnemy("null-ptr", 250, 340, 2.2, t)
    bigEnemy("bug", 380, 300, 1.8, t)
    bigEnemy("null-ptr", 110, 250, 1.6, t)
    bigEnemy("bug", 300, 250, 1.6, t)
    bigEnemy("null-ptr", 440, 350, 2.4, t)
    -- 상단 알림 박스 3개 (red 테두리 + "!")
    local blink = (math.floor(t * 4) % 2) == 0
    for i = 0, 2 do
        local bx = 560 + i * 130
        setCol(c("#1a0e0e"), 0.92)
        love.graphics.rectangle("fill", bx, 24 + i * 6, 120, 40, 4, 4)
        setCol(P.red, (i == 0 and blink) and 1 or 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, 24 + i * 6, 120, 40, 4, 4)
        love.graphics.setLineWidth(1)
        -- "!" 아이콘
        setCol(P.red)
        love.graphics.rectangle("fill", bx + 12, 32 + i * 6, 5, 16)
        love.graphics.rectangle("fill", bx + 12, 51 + i * 6, 5, 5)
        setCol(P.white, 0.8)
        love.graphics.rectangle("fill", bx + 28, 34 + i * 6, 76, 4)
        love.graphics.rectangle("fill", bx + 28, 44 + i * 6, 56, 4)
    end
    love.graphics.setColor(1, 1, 1)
end

-- 씬 4: 결의
local function drawIntro4(t)
    local P = art.pal
    rect(c("#070a12"), 0, 0, 960, 420)
    -- 배경 은은한 랙 실루엣
    setCol(P.panel, 0.5)
    for i = 0, 5 do love.graphics.rectangle("fill", 40 + i * 70, 30, 50, 150) end
    love.graphics.setColor(1, 1, 1)
    -- 모니터 (우측) + 깜빡이는 커서
    rect(c("#0a0e18"), 560, 60, 340, 220)
    rect(c("#0e1424"), 574, 74, 312, 192)
    setCol(P.green, 0.7)
    for i = 0, 8 do
        love.graphics.rectangle("fill", 590, 90 + i * 20, 120 + (i * 37) % 160, 5)
    end
    -- 깜빡이는 커서 블록
    if (math.floor(t * 2) % 2) == 0 then
        setCol(P.green)
        love.graphics.rectangle("fill", 590 + (8 * 37) % 160 + 130, 90 + 8 * 20, 12, 16)
    end
    love.graphics.setColor(1, 1, 1)
    -- 모니터 발광
    setCol(P.green, 0.10)
    love.graphics.polygon("fill", 730, 200, 430, 420, 900, 420, 900, 280)
    love.graphics.setColor(1, 1, 1)
    -- 개발자 타이핑 대형 클로즈업 (scale 6 → 96px)
    art.drawDev("typing", 150, 90, 6, t)
    -- 키보드
    rect(c("#181d2a"), 130, 340, 340, 60)
    rect(c("#0e121c"), 130, 340, 340, 5)
    setCol(c("#2a3346"))
    for row = 0, 2 do
        for kx = 0, 11 do
            love.graphics.rectangle("fill", 142 + kx * 27 + row * 8, 350 + row * 16, 22, 12)
        end
    end
    -- 타이핑 하이라이트 키 (t 기반)
    setCol(P.green, 0.8)
    local kk = math.floor(t * 9) % 12
    love.graphics.rectangle("fill", 142 + kk * 27, 350, 22, 12)
    love.graphics.setColor(1, 1, 1)
end

local INTRO = { drawIntro1, drawIntro2, drawIntro3, drawIntro4 }

-- n(1..4) 장면을 960×420 영역(0,0 기준)에 그린다. 뷰가 translate/여백 담당.
function art.drawIntroScene(n, t)
    local fn = INTRO[n]
    if fn then fn(t or 0) end
    love.graphics.setColor(1, 1, 1)
end

return art
