local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local art = require("src.art")
local csv = require("src.csv")
local stars = require("src.stars")
local utf8 = require("utf8")

local codex = {}

local TABS = { "타워", "몬스터", "내 함수", "프로필" }
local NO_FUNCS_MSG = "아직 수집된 함수가 없습니다. 전투 중 F5로 저장하면 기록됩니다."

-- ★/☆ 글리프: stageselect.lua/result.lua와 동일 — NanumGothic 정상 렌더 확인됨(스크린샷 검증 완료)
local STAR_FULL, STAR_EMPTY = "★", "☆"

-- 몬스터 abilities 키워드 → 한글 설명 (§3/설계서)
local ABILITY_KO = {
    crash_tower = "도달 시 최근접 타워를 크래시",
    split = "죽으면 둘로 분열",
    grow = "성장(시간당 체력 증가)",
    pair = "동반 경감(쌍 생존 시)",
    phase = "은신 주기(관측 불가)",
    split2 = "이중 분열",
    dash = "돌진(주기적 가속)",
    ["resist:printer"] = "프린터 저항",
}

-- 히든 타워(§4) 도감 수수께끼 문구 — 스펙 그대로
local HIDDEN_TEXT =
    "장애가 터지면 회의실 화면 앞에서 실시간으로 코딩을 시작한다는 전설의 클래스.\n" ..
    "Java로 짠 그것의 이름을 아는 자만이 소환할 수 있다."

-- "r;g;b" → {r,g,b} (실패 시 무난한 회색)
local function parseColor(s)
    local out = {}
    for v in tostring(s or ""):gmatch("[^;]+") do out[#out + 1] = tonumber(v) end
    if #out == 3 then return out end
    return { 0.5, 0.55, 0.62 }
end

local function fmtVal(v)
    if v == nil or v == "" then return "—" end
    return tostring(v)
end

-- UTF8 안전 말줄임(…). 목록 폭보다 넓은 라벨(예: concat-nil의 긴 영문 이름)을 잘라낸다.
local function truncate(font, text, maxW)
    if font:getWidth(text) <= maxW then return text end
    local len = utf8.len(text) or #text
    for n = len - 1, 0, -1 do
        local byteEnd = (n > 0) and (utf8.offset(text, n + 1) - 1) or 0
        local s = text:sub(1, byteEnd) .. "…"
        if font:getWidth(s) <= maxW then return s end
    end
    return "…"
end

local function firstChar(s)
    local e = utf8.offset(s, 2)
    if not e then return s end
    return s:sub(1, e - 1)
end

-- towers.csv 원본 순서를 그대로 얻는다(색인화된 d.towers는 해시라 순서가 없음).
-- gugu-class(또는 hidden=1 타워)는 순서와 무관하게 항상 마지막에 배치한다.
local function towerOrder(d)
    local recs = csv.load(d.root .. "/data/towers.csv")
    local ids, last = {}, {}
    for _, r in ipairs(recs) do
        if r.id == "gugu-class" then last[#last + 1] = r.id
        else ids[#ids + 1] = r.id end
    end
    for _, id in ipairs(last) do ids[#ids + 1] = id end
    return ids
end

local function enemyOrder(d)
    local recs = csv.load(d.root .. "/data/enemies.csv")
    local ids = {}
    for _, r in ipairs(recs) do ids[#ids + 1] = r.id end
    return ids
end

-- d.stages는 배열이 아니라 id→row 해시라 순서가 없다. stageselect.lua와 동일한 순서
-- 소스(mode=="normal" 필터 + id 오름차순 정렬)를 그대로 재사용해 프로필 탭의 스테이지
-- 순서를 스테이지 선택 화면과 일치시킨다.
local function stageOrder(d)
    local ids = {}
    for id, s in pairs(d.stages) do
        if s.mode == "normal" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

local function isHiddenTower(def, p)
    return def.hidden == 1 and not p.gugu_found
end

-- progress.funcbook(이름→{first,count})의 키를 이름 정렬 배열로 뽑는다.
local function funcNameOrder(p)
    local names = {}
    for name in pairs(p.funcbook or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function codex:enter(_, d, p)
    self.d, self.p = d, p
    self.tab = 1
    self.cursor = 1
    self.profileScroll = 0 -- [프로필] 탭 스테이지 목록 스크롤(다른 탭의 cursor 스크롤과 별도 관리)
    self.lists = { towerOrder(d), enemyOrder(d), funcNameOrder(p), stageOrder(d) }
end

function codex:currentList()
    return self.lists[self.tab]
end

-- 타워 시트가 로드돼 있는지("art.load()"가 만든 art._img["tower_"..id])를 확인한다.
-- 전용 스프라이트가 아직 없는 타워가 추가되더라도 자동으로 폴백 배지로 우아하게 대체된다.
local function hasTowerSheet(id)
    return art._img ~= nil and art._img["tower_" .. id] ~= nil
end

-- 카드 스프라이트 영역: 컬러 배지 배경(팔레트) + 시트 스프라이트.
-- 전용 스프라이트가 없는 타워는 배지를 진하게 칠하고 이름 첫 글자를 큼직하게 얹어
-- 빈 카드로 보이지 않게 한다. 히든이면 검정 실루엣으로 완전히 덮는다.
local function drawCardSprite(kind, def, cx, cy, s, t, hidden)
    local half = 16 * s
    local col = parseColor(def.color)
    local hasSheet = kind ~= "tower" or hasTowerSheet(def.id)
    love.graphics.setColor(col[1], col[2], col[3], hasSheet and 0.22 or 0.4)
    love.graphics.rectangle("fill", cx - half, cy - half, half * 2, half * 2, 8, 8)
    love.graphics.setColor(1, 1, 1)
    if hidden then
        love.graphics.setColor(0, 0, 0, 0.86)
        love.graphics.rectangle("fill", cx - half, cy - half, half * 2, half * 2, 8, 8)
        love.graphics.setColor(1, 1, 1)
        return
    end
    if hasSheet then
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(s)
        if kind == "tower" then
            art.drawTower(def.id, 0, 0, t, false)
        else
            art.drawEnemy(def.id, 0, 0, t, false)
        end
        love.graphics.pop()
    else
        love.graphics.setFont(fonts.big)
        love.graphics.setColor(col[1], col[2], col[3])
        local ch = firstChar(def.name)
        local fw = fonts.big:getWidth(ch)
        love.graphics.print(ch, cx - fw / 2, cy - 20)
    end
    love.graphics.setColor(1, 1, 1)
end

local CARD_X, CARD_Y, CARD_W, CARD_H = 300, 100, 630, 468
local SPRITE_CX, SPRITE_CY, SPRITE_S = CARD_X + 130, CARD_Y + 110, 5

-- text를 font로 (x,y,w) 안에 줄바꿈해 그리고, 실제로 차지한 줄 수만큼 내려간 다음 y를 반환한다.
-- (concat-nil처럼 긴 영문 이름이 카드 밖으로 새는 것을 막기 위해 고정 좌표 대신 동적으로 쌓는다.)
local function stackText(font, text, x, y, w, col, gap)
    love.graphics.setFont(font)
    love.graphics.setColor(col[1], col[2], col[3], col[4])
    love.graphics.printf(text, x, y, w, "left")
    local _, wrapped = font:getWrap(text, w)
    local n = math.max(1, #wrapped)
    love.graphics.setColor(1, 1, 1)
    return y + n * font:getHeight() + (gap or 0)
end

local function drawTowerCard(self, id, t)
    local P = art.pal
    local d, p = self.d, self.p
    local def = d.towers[id]
    local hidden = isHiddenTower(def, p)

    drawCardSprite("tower", def, SPRITE_CX, SPRITE_CY, SPRITE_S, t, hidden)

    local textX = CARD_X + 270
    local textW = CARD_X + CARD_W - textX - 20
    local y = CARD_Y + 16

    local name = hidden and "???" or def.name
    local nameFont = fonts.big:getWidth(name) <= textW and fonts.big or fonts.ui
    local nameCol = hidden and { 0.6, 0.55, 0.7 } or P.green
    y = stackText(nameFont, name, textX, y, textW, nameCol, 10)

    y = stackText(fonts.small, hidden and HIDDEN_TEXT or def.desc, textX, y, textW, { 0.78, 0.82, 0.88 }, 20)

    -- 스탯 표
    local rows = {
        { "비용", def.cost }, { "데미지", def.damage }, { "사거리", def.range },
        { "쿨다운", def.cooldown },
        { "요구 테크", def.requires ~= "" and (d.towers[def.requires] and d.towers[def.requires].name or def.requires) or nil },
    }
    local rowY = math.max(y, CARD_Y + 130)
    love.graphics.setFont(fonts.ui)
    for _, row in ipairs(rows) do
        local label, val = row[1], row[2]
        love.graphics.setColor(0.6, 0.66, 0.74)
        love.graphics.print(label, textX, rowY)
        local valCol = hidden and { 0.75, 0.7, 0.85 } or { 0.9, 0.92, 0.96 }
        love.graphics.setColor(valCol[1], valCol[2], valCol[3])
        love.graphics.print(hidden and "?" or fmtVal(val), textX + 130, rowY)
        rowY = rowY + 28
    end

    -- 예시 코드
    local codeY = rowY + 14
    love.graphics.setColor(P.panelLight[1], P.panelLight[2], P.panelLight[3], 0.9)
    love.graphics.rectangle("fill", textX, codeY, textW, 34, 5, 5)
    love.graphics.setFont(fonts.mono)
    local codeCol = hidden and { 0.55, 0.55, 0.6 } or P.cyan
    love.graphics.setColor(codeCol[1], codeCol[2], codeCol[3])
    local codeLine = hidden and 'build("?", ?, ?, "?")' or ('build("%s", 3, 10, "a")'):format(id)
    love.graphics.print(codeLine, textX + 10, codeY + 8)

    love.graphics.setColor(1, 1, 1)
end

local function drawEnemyCard(self, id, t)
    local P = art.pal
    local d = self.d
    local def = d.enemies[id]

    drawCardSprite("enemy", def, SPRITE_CX, SPRITE_CY, SPRITE_S, t, false)

    local textX = CARD_X + 270
    local textW = CARD_X + CARD_W - textX - 20
    local y = CARD_Y + 16

    local nameFont = fonts.big:getWidth(def.name) <= textW and fonts.big or fonts.ui
    y = stackText(nameFont, def.name, textX, y, textW, P.magenta, 10)
    y = stackText(fonts.small, def.desc, textX, y, textW, { 0.78, 0.82, 0.88 }, 20)
    if def.origin and def.origin ~= "" then
        y = stackText(fonts.small, "유래: " .. def.origin, textX, y, textW, { 0.55, 0.6, 0.65 }, 20)
    end

    local abilityY = math.max(y, CARD_Y + 130)
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.6, 0.66, 0.74)
    love.graphics.print("능력", textX, abilityY)

    local list = csv.list(def.abilities)
    love.graphics.setColor(0.9, 0.92, 0.96)
    if #list == 0 then
        love.graphics.print("—", textX, abilityY + 30)
    else
        local ay = abilityY + 30
        for _, key in ipairs(list) do
            love.graphics.print("· " .. (ABILITY_KO[key] or key), textX, ay)
            ay = ay + 26
        end
    end

    love.graphics.setColor(1, 1, 1)
end

-- [내 함수] 탭 카드 — 이름 + "스테이지 N에서 처음 정의 · M회" (§2.3, 스프라이트 없음)
local function drawFuncCard(self, name)
    local P = art.pal
    local entry = self.p.funcbook[name]
    local textX = CARD_X + 40
    local textW = CARD_X + CARD_W - textX - 40
    local y = CARD_Y + 60

    local nameFont = fonts.big:getWidth(name) <= textW and fonts.big or fonts.ui
    y = stackText(nameFont, name, textX, y, textW, P.green, 16)
    local detail = ("스테이지 %d에서 처음 정의 · %d회"):format(entry.first, entry.count)
    stackText(fonts.ui, detail, textX, y, textW, { 0.85, 0.88, 0.92 }, 0)
end

-- [프로필] 탭 — 전부 기존 저장 데이터(records/funcbook/gugu_found)에서 파생, 새 필드 없음.
-- 좌측 패널: 요약 집계. 우측 패널: 스테이지별 한 줄 기록(스크롤 가능).
local function computeProfileSummary(d, p, stageIds)
    local totalTries, clearedCount, starSum = 0, 0, 0
    for _, id in ipairs(stageIds) do
        local rec = p.records and p.records[id]
        if rec then totalTries = totalTries + (rec.tries or 0) end
        if p.cleared[id] then
            clearedCount = clearedCount + 1
            starSum = starSum + stars.of(rec and rec.bestHP or 0)
        end
    end
    local funcCount = 0
    for _ in pairs(p.funcbook or {}) do funcCount = funcCount + 1 end
    return totalTries, clearedCount, starSum, funcCount
end

local function drawProfileSummary(self, x, y, w)
    local P = art.pal
    local d, p = self.d, self.p
    local stageIds = self.lists[4]
    local totalTries, clearedCount, starSum, funcCount = computeProfileSummary(d, p, stageIds)

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(P.green[1], P.green[2], P.green[3])
    love.graphics.print("요약", x + 16, y + 14)

    local rows = {
        { "총 배포", ("%d회"):format(totalTries) },
        { "클리어", ("%d / %d"):format(clearedCount, #stageIds) },
        { "별 합계", ("%d★"):format(starSum) },
        { "등록 함수", ("%d개"):format(funcCount) },
        { "구구 클래스", p.gugu_found and "발견" or "???" },
    }
    local ry = y + 56
    for _, row in ipairs(rows) do
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.6, 0.66, 0.74)
        love.graphics.print(row[1], x + 16, ry)
        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.9, 0.92, 0.96)
        love.graphics.print(row[2], x + 16, ry + 22)
        ry = ry + 58
    end
    love.graphics.setColor(1, 1, 1)
end

-- 스테이지 한 줄: 클리어면 "N. 이름 — 시도 n · ★★☆", 미클리어는 "N. 이름 — 미클리어"
-- (시도 기록이 있으면 "N. 이름 — 시도 n · 미클리어").
local function profileStageLine(d, p, id)
    local s = d.stages[id]
    local rec = p.records and p.records[id]
    if p.cleared[id] then
        local n = stars.of(rec and rec.bestHP or 0)
        local starText = STAR_FULL:rep(n) .. STAR_EMPTY:rep(3 - n)
        return ("%d. %s — 시도 %d · %s"):format(id, s.concept, rec and rec.tries or 0, starText)
    elseif rec and (rec.tries or 0) > 0 then
        return ("%d. %s — 시도 %d · 미클리어"):format(id, s.concept, rec.tries)
    end
    return ("%d. %s — 미클리어"):format(id, s.concept)
end

-- 스크롤 지오메트리는 stageselect.lua의 목록 스크롤 패턴을 그대로 재사용한다.
-- 클램프된 최대 스크롤 값을 self.profileMaxScroll에 저장해 keypressed가 참조한다.
local function drawProfileStages(self, x, y, w, h)
    local P = art.pal
    local d, p = self.d, self.p
    local stageIds = self.lists[4]

    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(P.green[1], P.green[2], P.green[3])
    love.graphics.print("스테이지 기록", x + 24, y + 16)

    local rowSpacing = 30
    local listTop, listBottom = y + 60, y + h - 20
    local visibleRows = math.max(1, math.floor((listBottom - listTop) / rowSpacing))
    local maxScroll = math.max(0, #stageIds - visibleRows)
    self.profileScroll = math.max(0, math.min(self.profileScroll, maxScroll))
    self.profileMaxScroll = maxScroll

    love.graphics.setFont(fonts.small)
    for j = 1, visibleRows do
        local i = self.profileScroll + j
        local id = stageIds[i]
        if not id then break end
        local ry = listTop + (j - 1) * rowSpacing
        local col = p.cleared[id] and P.green or { 0.75, 0.78, 0.82 }
        love.graphics.setColor(col[1], col[2], col[3])
        love.graphics.print(profileStageLine(d, p, id), x + 24, ry)
    end

    if self.profileScroll > 0 then
        love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
        love.graphics.printf("↑ 더 있음", x, y + 6, w, "center")
    end
    if self.profileScroll + visibleRows < #stageIds then
        love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
        love.graphics.printf("↓ 더 있음", x, listBottom + 4, w, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function codex:draw()
    local t = love.timer.getTime()
    local P = art.pal
    local W = love.graphics.getWidth()
    local OX = (W - 960) / 2 -- 960 기준 레이아웃을 창 폭 중앙에 배치하는 오프셋
    love.graphics.setColor(P.bg[1], P.bg[2], P.bg[3])
    love.graphics.rectangle("fill", 0, 0, W, 640)

    -- 이하 좌표는 전부 원래 960 기준 그대로 두고, OX만큼 평행이동해 창 중앙에 놓는다.
    love.graphics.push()
    love.graphics.translate(OX, 0)

    love.graphics.setFont(fonts.big)
    love.graphics.setColor(P.cyan[1], P.cyan[2], P.cyan[3])
    love.graphics.printf("도감", 0, 20, 960, "center")

    -- 탭
    love.graphics.setFont(fonts.ui)
    local tabX = 370
    for i, label in ipairs(TABS) do
        if i == self.tab then
            love.graphics.setColor(P.green[1], P.green[2], P.green[3])
            love.graphics.print("[ " .. label .. " ]", tabX, 66)
        else
            love.graphics.setColor(0.5, 0.55, 0.6)
            love.graphics.print("  " .. label .. "  ", tabX, 66)
        end
        tabX = tabX + 90
    end

    -- 좌측 목록 패널
    local listX, listY, listW, listH = 30, 100, 250, 468
    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.85)
    love.graphics.rectangle("fill", listX, listY, listW, listH, 8, 8)

    -- 우측 카드 패널
    love.graphics.setColor(P.panel[1], P.panel[2], P.panel[3], 0.85)
    love.graphics.rectangle("fill", CARD_X, CARD_Y, CARD_W, CARD_H, 8, 8)

    if self.tab == 4 then
        -- [프로필] 탭: 좌측=요약 집계, 우측=스테이지별 한 줄 기록(스크롤) — 다른 탭의
        -- 커서 기반 목록/카드 패턴 대신 두 패널을 요약/기록 뷰로 재활용한다.
        drawProfileSummary(self, listX, listY, listW)
        drawProfileStages(self, CARD_X, CARD_Y, CARD_W, CARD_H)
    else
        local list = self:currentList()
        love.graphics.setFont(fonts.ui)
        local labelMaxW = listW - 42 -- "> " 접두 폭 + 좌우 여백
        for i, id in ipairs(list) do
            local y = listY + 14 + (i - 1) * 34
            local label
            if self.tab == 1 then
                local def = self.d.towers[id]
                label = isHiddenTower(def, self.p) and "???" or def.name
            elseif self.tab == 2 then
                label = self.d.enemies[id].name
            else
                label = id -- 내 함수 탭: id 자체가 함수 이름 문자열
            end
            label = truncate(fonts.ui, label, labelMaxW)
            if i == self.cursor then
                love.graphics.setColor(P.green[1], P.green[2], P.green[3], 0.14)
                love.graphics.rectangle("fill", listX + 8, y - 4, listW - 16, 28, 5, 5)
                love.graphics.setColor(P.green[1], P.green[2], P.green[3])
            else
                love.graphics.setColor(0.82, 0.85, 0.9)
            end
            local prefix = (i == self.cursor) and "> " or "   "
            love.graphics.print(prefix .. label, listX + 14, y)
        end

        local id = list[self.cursor]
        if self.tab == 3 then
            if id then
                drawFuncCard(self, id)
            else
                love.graphics.setFont(fonts.ui)
                love.graphics.setColor(0.6, 0.65, 0.7)
                love.graphics.printf(NO_FUNCS_MSG, CARD_X + 40, CARD_Y + CARD_H / 2 - 20, CARD_W - 80, "center")
                love.graphics.setColor(1, 1, 1)
            end
        elseif id then
            if self.tab == 1 then
                drawTowerCard(self, id, t)
            else
                drawEnemyCard(self, id, t)
            end
        end
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.55, 0.6, 0.66)
    love.graphics.printf("←/→ 탭 · ↑↓ 이동 · ESC 타이틀", 0, 600, 960, "center")
    love.graphics.setColor(1, 1, 1)

    love.graphics.pop()
end

function codex:keypressed(key)
    if key == "up" then
        if self.tab == 4 then
            self.profileScroll = math.max(0, self.profileScroll - 1)
        else
            self.cursor = math.max(1, self.cursor - 1)
        end
    elseif key == "down" then
        if self.tab == 4 then
            self.profileScroll = math.min(self.profileMaxScroll or 0, self.profileScroll + 1)
        else
            local list = self:currentList()
            self.cursor = math.min(#list, self.cursor + 1)
        end
    elseif key == "left" then
        self.tab = self.tab == 1 and #TABS or self.tab - 1
        self.cursor = 1
        self.profileScroll = 0
    elseif key == "right" then
        self.tab = self.tab % #TABS + 1
        self.cursor = 1
        self.profileScroll = 0
    elseif key == "escape" then
        Gamestate.switch(require("states.title"), self.d, self.p)
    end
end

return codex
