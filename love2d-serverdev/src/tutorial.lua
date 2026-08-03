local Object = require("lib.classic")

local Tutorial = Object:extend()

function Tutorial:new(steps)
    self.steps = steps or {}
    self.idx = 1
    self.skipped = false
    -- 뷰 전용 — 중앙 카드 모드일 때 버튼형 라벨의 화면 rect(states/play.lua의 mousepressed가
    -- 읽어 클릭을 Enter/Ctrl+X와 동일 처리한다). draw가 매 프레임 갱신하며, 로직에는 쓰이지 않는다.
    self.enterRect, self.skipRect = nil, nil
end

function Tutorial.load(path)
    local f = io.open(path, "rb")
    if not f then print("[튜토리얼] 파일 없음: " .. path) return nil end
    local src = f:read("*a"); f:close()
    local chunk = loadstring(src)
    if not chunk then print("[튜토리얼] 로드 실패: " .. path) return nil end
    local ok, steps = pcall(chunk)
    if not ok or type(steps) ~= "table" then print("[튜토리얼] 실행 실패: " .. path) return nil end
    return Tutorial(steps)
end

function Tutorial:current() return self.steps[self.idx] end
function Tutorial:done() return self.skipped or self.idx > #self.steps end

function Tutorial:allows(key, ctrl)
    if self:done() then return true end
    if key == "return" or key == "escape" or (ctrl and key == "x") then return true end
    local step = self:current()
    if not step.allow then return true end
    for _, k in ipairs(step.allow) do if k == key then return true end end
    return false
end

function Tutorial:allowsText()
    if self:done() then return true end
    local step = self:current()
    if not step.allow then return true end
    for _, k in ipairs(step.allow) do if k == "textinput" then return true end end
    return false
end

function Tutorial:advance() self.idx = self.idx + 1 end

-- key를 소비(진행에 사용)했으면 true, 아니면 false를 반환한다. 호출자(states/play.lua)는
-- true를 받으면 그 키를 여기서 멈춰야 한다 — 그렇지 않으면 예: 스테이지 3/4 설명 스텝에서
-- Enter가 에디터까지 새어들어가 빈 줄이 삽입된다.
function Tutorial:keypressed(key, ctrl)
    if self:done() then return false end
    if ctrl and key == "x" then self.skipped = true return true end
    local adv = self:current().advance
    if key == "return" and adv.on == "enter" then self:advance() return true
    elseif adv.on == "key" and adv.key == key then self:advance() return true end
    return false
end

function Tutorial:notify(event)
    if self:done() then return end
    local adv = self:current().advance
    if adv.on == "event" and adv.event == event then self:advance() end
end

-- 말풍선 박스 (화면 하단 고정, 입력 허용 스텝 전용). 그리드(1280x640, GRID_Y=48, 16행*32=512
-- ⇒ 그리드/서버라인은 y<=564)와 하단 힌트바(y=620) 사이의 좁은 띠에 배치 — 서버라인
-- 하이라이트를 가리지 않도록 y=580부터 시작한다 (버튼 스테이지의 버튼 목록도 play.lua 쪽에서
-- y<=575로 당겨져 있다). 폭은 창 전체(1280, x=8 여백 대칭)만큼 넓힌 1264.
local BOX_X, BOX_Y, BOX_W, BOX_H = 8, 580, 1264, 54

-- 앵커 하이라이트 및 두 렌더 모드가 공유하는 금색 톤(기존 anchor blink 톤 재사용 — UX 개편에서
-- 새 팔레트 항목을 만들지 않고 이 파일에 이미 있던 톤을 그대로 상수화했다).
local GOLD = { 1, 0.85, 0.3 }

-- 말풍선/카드 렌더(뷰 전용 — allows/keypressed/notify 로직과 무관). UX 개편(문제 카드와의
-- Enter 의미 충돌·말풍선이 하단 구석이라 눈에 안 띄는 문제) 대응으로 2계층화했다:
--   · 입력 잠금 스텝(allowsText()==false — allow={} 설명 스텝, allow={"1"} 등 버튼 전용 스텝
--     모두 포함): 화면 중앙에 문제 카드와 같은 자리 감각의 큰 카드 + 클릭 가능한 버튼형 라벨.
--   · 입력 허용 스텝(allowsText()==true — allow에 textinput이 있거나 allow 자체가 없는 스텝):
--     기존 하단 말풍선을 유지해 에디터 타이핑 시야를 가리지 않는다.
-- shake(0~0.3, states/play.lua가 세팅하는 원시 dt 타이머)가 양수면 0.3초간 흔들림 + 진행
-- 안내 라벨을 강조해 "키를 눌렀는데 왜 반응이 없는지" 피드백을 준다.
function Tutorial:draw(fonts, gx, gy, midW, shake)
    self.enterRect, self.skipRect = nil, nil
    if self:done() then return end
    local grid = require("src.grid")
    local step = self:current()
    local idx, total = self.idx, #self.steps
    shake = shake or 0
    local sx = shake > 0 and math.sin(love.timer.getTime() * 50) * (4 * shake / 0.3) or 0

    -- 앵커 하이라이트 (깜빡임) — 위치·조건은 기존과 동일, 색만 GOLD 상수 재사용.
    local a = step.anchor
    local blink = (love.timer.getTime() * 3) % 2 < 1.2
    if a and a.type == "cell" and blink then
        local x, y = grid.toXY(a.r, a.c)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3])
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", gx + x, gy + y, grid.CELL - 1, grid.CELL - 1)
        love.graphics.setLineWidth(1)
    elseif a and a.type == "ui" and blink then
        if a.id == "editor" then
            -- 에디터는 states/play.lua에서 Editor(656, 48, 610, 470)로 생성된다 — 2px 여유로 감싼다.
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
            love.graphics.rectangle("line", 654, 46, 614, 474)
        elseif a.id == "serverline" then
            -- 서버라인은 states/play.lua에서 (GRID_X, GRID_Y + 16*32, 12*32, 4)에 그려진다.
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", gx - 2, gy + 16 * 32 - 3, 12 * 32 + 4, 10)
            love.graphics.setLineWidth(1)
        elseif a.id == "quickbar" then
            -- 퀵바는 에디터 바로 아래(x=654, y=editor.y+editor.h+2=520)에 그려진다.
            love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
            love.graphics.rectangle("line", 654, 520, 372, 32)
        end
    end

    local pulse = 0.55 + 0.35 * math.sin(love.timer.getTime() * 3)
    local locked = not self:allowsText()

    if locked then
        -- 입력 잠금 스텝: 중앙 카드(전장+정보 칼럼을 아우르는 폭 = midW, 문제 카드와 같은 자리
        -- 감각). 버튼형 라벨의 rect를 self.enterRect/self.skipRect에 남겨 마우스 클릭도 받는다.
        love.graphics.setFont(fonts.ui)
        local cardW = math.min((midW or 632) - 40, 560)
        local pad = 16
        local _, wrapped = fonts.ui:getWrap(step.text, cardW - pad * 2)
        local bodyLines = math.max(1, #wrapped)
        local lineH = fonts.ui:getHeight() + 4
        local titleH = 26
        local btnH = 30
        local cardH = pad * 2 + titleH + bodyLines * lineH + 14 + btnH
        local cardX = gx + ((midW or 632) - cardW) / 2 + sx
        local cardY = gy + (grid.ROWS * grid.CELL - cardH) / 2

        love.graphics.setColor(0.08, 0.09, 0.14, 0.96)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 8)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], shake > 0 and 1 or pulse)
        love.graphics.setLineWidth(shake > 0 and 4 or 3)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 8)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3])
        love.graphics.print(("튜토리얼 %d/%d"):format(idx, total), cardX + pad, cardY + pad)

        love.graphics.setColor(0.94, 0.96, 0.98)
        love.graphics.printf(step.text, cardX + pad, cardY + pad + titleH, cardW - pad * 2, "left")

        local by = cardY + cardH - pad - btnH
        local bx = cardX + pad
        if step.advance.on == "enter" then
            local label = "[ Enter ▶ 다음 ]"
            local bw = fonts.ui:getWidth(label) + 16
            love.graphics.setColor(0.15, shake > 0 and 0.55 or 0.4, 0.3, 0.95)
            love.graphics.rectangle("fill", bx, by, bw, btnH, 5)
            love.graphics.setColor(0.6, 0.95, 0.75)
            love.graphics.print(label, bx + 8, by + 6)
            self.enterRect = { x0 = bx, y0 = by, x1 = bx + bw, y1 = by + btnH }
            bx = bx + bw + 10
        end
        do
            local label = "[ Ctrl+X 건너뛰기 ]"
            local bw = fonts.ui:getWidth(label) + 16
            love.graphics.setColor(0.3, 0.18, 0.18, 0.9)
            love.graphics.rectangle("fill", bx, by, bw, btnH, 5)
            love.graphics.setColor(1, 0.7, 0.65)
            love.graphics.print(label, bx + 8, by + 6)
            self.skipRect = { x0 = bx, y0 = by, x1 = bx + bw, y1 = by + btnH }
        end
        love.graphics.setColor(1, 1, 1)
    else
        -- 입력 허용 스텝: 기존 하단 말풍선 유지(타이핑 시야 확보) + 테두리 펄스 + 진행도 배지.
        local bx0 = BOX_X + sx
        love.graphics.setColor(0.1, 0.12, 0.18, 0.95)
        love.graphics.rectangle("fill", bx0, BOX_Y, BOX_W, BOX_H, 8)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], shake > 0 and 1 or pulse)
        love.graphics.setLineWidth(shake > 0 and 3 or 2)
        love.graphics.rectangle("line", bx0, BOX_Y, BOX_W, BOX_H, 8)
        love.graphics.setLineWidth(1)

        love.graphics.setFont(fonts.small)
        local badge = ("튜토리얼 %d/%d"):format(idx, total)
        local badgeW = fonts.small:getWidth(badge) + 12
        love.graphics.setColor(0.15, 0.4, 0.3, 0.9)
        love.graphics.rectangle("fill", bx0 + BOX_W - badgeW - 8, BOX_Y - 16, badgeW, 16, 3)
        love.graphics.setColor(0.6, 0.95, 0.75)
        love.graphics.print(badge, bx0 + BOX_W - badgeW - 2, BOX_Y - 15)

        love.graphics.setFont(fonts.ui)
        love.graphics.setColor(0.92, 0.94, 0.97)
        love.graphics.printf(step.text, bx0 + 12, BOX_Y + 7, BOX_W - 24, "left")
        love.graphics.setFont(fonts.small)
        if shake > 0 then love.graphics.setColor(1, 0.55, 0.3)
        else love.graphics.setColor(0.6, 0.65, 0.7) end
        local guide = step.advance.on == "enter" and "Enter 다음 · Ctrl+X 건너뛰기" or "Ctrl+X 건너뛰기"
        love.graphics.printf(guide, bx0 + 12, BOX_Y + BOX_H - 20, BOX_W - 24, "right")
        love.graphics.setColor(1, 1, 1)
    end
end

return Tutorial
