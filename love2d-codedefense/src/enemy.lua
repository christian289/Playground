local Object = require("lib.classic")
local grid = require("src.grid")

local Enemy = Object:extend()

-- 능력 상수(코어 상수 — 스탯 수치 자체는 CSV에서 옴)
local GROW_EVERY = 1.0     -- grow: 이 주기(초)마다 성장
local GROW_AMOUNT = 2      -- grow: 성장 시 maxHP/HP 증가량
local GROW_CAP_MULT = 5    -- grow: 상한 = 기본(CSV) maxHP × 이 배수
local DASH_PERIOD = 1.5    -- dash: 이 주기(초)마다 대시 창이 돌아옴
local DASH_LEN = 0.3       -- dash: 대시 창의 길이(초)
local DASH_MULT = 3        -- dash: 창 안에서의 속도 배율
local PHASE_VISIBLE = 3.0  -- phase: 이 길이(초)만큼 가시 상태
local PHASE_HIDDEN = 2.0   -- phase: 이어서 이 길이(초)만큼 은신 상태(가시→은신 반복)
local SLOW_MULT = 0.6      -- slowfield: 디버거 사거리 안이면 실효 speed에 이 배율(비중첩)

Enemy.PHASE_VISIBLE, Enemy.PHASE_HIDDEN = PHASE_VISIBLE, PHASE_HIDDEN
Enemy.SLOW_MULT = SLOW_MULT

-- abilities 문자열("a;b:arg;c")을 세미콜론으로 분리해 토큰 "완전 일치"로 파싱한다.
-- 반환: { [능력이름] = 인자문자열(콜론 뒤) 또는 true(인자 없음), ... }
-- 부분 문자열 검사가 아니므로 "split2"가 "split" 검사에 오탐되지 않는다(Task 1 핸드오프 이슈
-- 수정). battle.lua의 grow/dash/resist/split/crash_tower 판정과 Task 3(phase)·Task 4(slowfield)
-- 가 모두 이 헬퍼를 재사용한다.
function Enemy.parseAbilities(s)
    local out = {}
    for token in tostring(s or ""):gmatch("[^;]+") do
        local name, arg = token:match("^([^:]+):(.+)$")
        if name then out[name] = arg else out[token] = true end
    end
    return out
end

function Enemy:new(def, r, c)
    self.def = def
    self.id = nil          -- battle이 부여
    self.hp, self.max_hp = def.hp, def.hp
    self.abilities = Enemy.parseAbilities(def.abilities)
    self.r, self.c = r, c
    self.x, self.y = grid.toXY(r, c)
    self.x = self.x + grid.CELL / 2
    self.y = self.y + grid.CELL / 2
    self.dead, self.reached = false, false
    self.spawnedAt = 0        -- battle이 스폰 시 clock으로 덮어씀(스폰 시각 기준 산술)
    self.age = 0               -- 스폰 후 경과 초(battle clock 기반), 스냅샷 필드로도 노출
    self.growApplied = 0       -- grow: 이미 적용된 성장 횟수(중복 적용 방지)
    self.speed = def.speed     -- 실효 속도(px/s) — 스냅샷/월드가 참조, 매 프레임 갱신
    self.slowed = false        -- slowfield: battle이 매 프레임 갱신(디버거 사거리 내 여부, 중첩 불가)
end

-- grow 능력: 스폰 후 GROW_EVERY마다 maxHP/HP를 GROW_AMOUNT만큼 증가시킨다. age(경과초)로부터
-- "몇 번 적용됐어야 하는가"를 계산해 델타만 적용한다 — hp는 데미지로 줄 수 있으므로 절대값
-- 재계산이 아니라 증분 적용이어야 기존 피해가 보존된다. 상한은 기본(CSV) maxHP × GROW_CAP_MULT.
function Enemy:applyGrowth()
    if not self.abilities.grow then return end
    local due = math.floor(self.age / GROW_EVERY)
    if due <= self.growApplied then return end
    local cap = self.def.hp * GROW_CAP_MULT
    local delta = (due - self.growApplied) * GROW_AMOUNT
    self.growApplied = due
    local newMax = math.min(cap, self.max_hp + delta)
    self.hp = self.hp + (newMax - self.max_hp)
    self.max_hp = newMax
end

-- 실효 속도 계산 훅(단일 지점) — dash 배율을 여기서 곱한다. slowfield(Task 4)도 같은 훅에
-- 배율을 곱해 넣는다 — self.slowed는 battle이 매 프레임(디버거 사거리 내 여부, 중첩 불가·OR
-- 판정)로 갱신하는 순수 불리언이라, dash와 겹치면 그대로 곱해져 3×0.6처럼 복합된다.
function Enemy:effectiveSpeed()
    local mult = 1
    if self.abilities.dash then
        if (self.age % DASH_PERIOD) < DASH_LEN then mult = mult * DASH_MULT end
    end
    if self.slowed then mult = mult * SLOW_MULT end
    return self.def.speed * mult
end

-- phase 능력: 스폰 시각 기준 순수 산술로만 은신 여부를 판정한다(grow/dash와 같은 방식의
-- recomputation — 은신 여부를 별도 필드로 저장하지 않으므로 매 호출 결정론이 보장된다).
-- 가시(PHASE_VISIBLE)·은신(PHASE_HIDDEN) 구간이 스폰 시각부터 번갈아 반복되며, 은신 구간의
-- 시작 경계는 포함(>=)이고 재출현 경계는 배타(< 다음 주기 시작 전까지)다.
function Enemy:isPhased(clock)
    if not self.abilities.phase then return false end
    local age = (clock or 0) - self.spawnedAt
    if age < 0 then return false end
    local cycle = PHASE_VISIBLE + PHASE_HIDDEN
    return (age % cycle) >= PHASE_VISIBLE
end

-- 스폰 이후 경과(age)를 battle clock 기준으로 갱신하고, grow/실효 속도를 계산한다.
-- 그리드 이동과 분리되어 있어 이동 없이도(또는 테스트에서 그리드 없이도) 호출 가능하다.
function Enemy:updateStats(clock)
    self.age = (clock or 0) - self.spawnedAt
    self:applyGrowth()
    self.speed = self:effectiveSpeed()
end

-- 플로우필드를 따라 칸 중심에서 칸 중심으로 이동
function Enemy:update(dt, g, clock)
    self:updateStats(clock)
    local tx, ty = grid.toXY(self.r, self.c)
    tx, ty = tx + grid.CELL / 2, ty + grid.CELL / 2
    local dx, dy = tx - self.x, ty - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.speed * dt
    if dist <= step then
        self.x, self.y = tx, ty
        if g.dist[self.r][self.c] == 0 then
            self.reached = true              -- 서버라인 도달
            return
        end
        local f = g.flow[self.r][self.c]
        if f then self.r, self.c = self.r + f[1], self.c + f[2] end
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Enemy
