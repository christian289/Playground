local Object = require("lib.classic")

local Tutorial = Object:extend()

function Tutorial:new(steps)
    self.steps = steps or {}
    self.idx = 1
    self.skipped = false
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

function Tutorial:keypressed(key, ctrl)
    if self:done() then return end
    if ctrl and key == "x" then self.skipped = true return end
    local adv = self:current().advance
    if key == "return" and adv.on == "enter" then self:advance()
    elseif adv.on == "key" and adv.key == key then self:advance() end
end

function Tutorial:notify(event)
    if self:done() then return end
    local adv = self:current().advance
    if adv.on == "event" and adv.event == event then self:advance() end
end

-- 말풍선 박스 (화면 하단 고정). 그리드(960x640, GRID_Y=48, 16행*32=512 ⇒ 그리드/서버라인은
-- y<=564)와 하단 힌트바(y=620) 사이의 좁은 띠에 배치 — 서버라인 하이라이트를 가리지 않도록
-- y=580부터 시작한다 (버튼 스테이지의 버튼 목록도 play.lua 쪽에서 y<=575로 당겨져 있다).
local BOX_X, BOX_Y, BOX_W, BOX_H = 8, 580, 944, 54

function Tutorial:draw(fonts, gx, gy)
    if self:done() then return end
    local grid = require("src.grid")
    local step = self:current()
    -- 앵커 하이라이트 (깜빡임)
    local a = step.anchor
    local blink = (love.timer.getTime() * 3) % 2 < 1.2
    if a and a.type == "cell" and blink then
        local x, y = grid.toXY(a.r, a.c)
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", gx + x, gy + y, grid.CELL - 1, grid.CELL - 1)
        love.graphics.setLineWidth(1)
    elseif a and a.type == "ui" and blink then
        if a.id == "editor" then
            love.graphics.setColor(1, 0.85, 0.3, 0.8)
            love.graphics.rectangle("line", 398, 46, 556, 474)
        elseif a.id == "serverline" then
            -- 서버라인은 states/play.lua에서 (GRID_X, GRID_Y + 16*32, 12*32, 4)에 그려진다.
            love.graphics.setColor(1, 0.85, 0.3, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", gx - 2, gy + 16 * 32 - 3, 12 * 32 + 4, 10)
            love.graphics.setLineWidth(1)
        elseif a.id == "quickbar" then
            love.graphics.setColor(1, 0.85, 0.3, 0.8)
            love.graphics.rectangle("line", 398, 520, 372, 32)
        end
    end
    -- 말풍선 (하단 고정)
    love.graphics.setColor(0.1, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", BOX_X, BOX_Y, BOX_W, BOX_H, 8)
    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.rectangle("line", BOX_X, BOX_Y, BOX_W, BOX_H, 8)
    love.graphics.setFont(fonts.ui)
    love.graphics.setColor(0.92, 0.94, 0.97)
    love.graphics.printf(step.text, BOX_X + 12, BOX_Y + 7, BOX_W - 24, "left")
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.6, 0.65, 0.7)
    local guide = step.advance.on == "enter" and "Enter 다음 · Ctrl+X 건너뛰기" or "Ctrl+X 건너뛰기"
    love.graphics.printf(guide, BOX_X + 12, BOX_Y + BOX_H - 20, BOX_W - 24, "right")
end

return Tutorial
