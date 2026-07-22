local Object = require("lib.classic")
local utf8 = require("utf8")

local CHARS_PER_SEC = 30

local Cutscene = Object:extend()

function Cutscene:new(scenes)
    self.scenes = scenes
    self.idx = 1
    self.shown = 0        -- 표시된 글자 수 (실수 누적)
    self.finished = false
end

local function charLen(s)
    return utf8.len(s) or #s
end

local function sub(s, n)
    if n <= 0 then return "" end
    local total = charLen(s)
    if n >= total then return s end
    return s:sub(1, utf8.offset(s, n + 1) - 1)
end

function Cutscene:current() return self.scenes[self.idx] end
function Cutscene:sceneIndex() return self.idx end
function Cutscene:done() return self.finished end

function Cutscene:update(dt)
    if self.finished then return end
    self.shown = self.shown + dt * CHARS_PER_SEC
end

function Cutscene:visibleText()
    if self.finished then return "" end
    return sub(self:current().text, math.floor(self.shown))
end

function Cutscene:typingDone()
    return math.floor(self.shown) >= charLen(self:current().text)
end

function Cutscene:press()
    if self.finished then return end
    if not self:typingDone() then
        self.shown = charLen(self:current().text)
    elseif self.idx < #self.scenes then
        self.idx = self.idx + 1
        self.shown = 0
    else
        self.finished = true
    end
end

function Cutscene:skip()
    self.finished = true
end

return Cutscene
