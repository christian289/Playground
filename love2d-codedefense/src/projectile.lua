local Object = require("lib.classic")

local Projectile = Object:extend()

local SPLASH_RADIUS = 60   -- splash: 명중점 기준 이 반경(px) 안의 다른 적까지 함께 피해

function Projectile:new(x, y, target, damage, speed, size, splash)
    self.x, self.y = x, y
    self.target = target       -- Enemy 참조 (죽으면 소멸)
    self.damage, self.speed, self.size = damage, speed, size
    self.splash = splash or false  -- splash: gc-collector 등 ability="splash" 타워가 true로 생성
    self.done = false
    -- 뷰 전용 관측 필드(시뮬레이션 결과에는 전혀 영향 없음) — splash 폭발이 실제로 일어난
    -- 순간(주 타겟이 은신 중이 아니어서 데미지가 적용된 순간) true + 명중 좌표를 기록해,
    -- states/play.lua가 명중 프레임을 정확히 감지해 링 파티클을 스폰할 수 있게 한다.
    self.splashHit = false
    self.hitX, self.hitY = nil, nil
end

-- clock: phase(은신) 판정용 battle clock. 명중 순간 대상이 은신 중이면 데미지는 무효화되고
-- 투사체는 그대로 통과·소멸한다(발사 자체는 막지 않는다 — 자동 타겟 선택 단계에서 이미
-- world.enemies()/nearest() 등이 은신 적을 제외하므로, 여기서는 이미 발사된 투사체가
-- 도중에 대상이 은신으로 들어간 경우만 걸러낸다).
-- enemies: splash 폭발 판정에만 쓰이는 battle.enemies 전체 목록(비-splash 투사체는 무시해도
-- 무방하도록 nil이어도 안전하게 동작). 폭발은 명중 "순간" battle 좌표(주 타겟의 x,y) 기준으로
-- 1회만 판정하는 결정론적 계산이며, love API를 전혀 쓰지 않는다.
function Projectile:update(dt, clock, enemies)
    if self.target.dead or self.target.reached then self.done = true return end
    local dx, dy = self.target.x - self.x, self.target.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = self.speed * dt
    if dist <= step then
        if not self.target:isPhased(clock) then
            self.target.hp = self.target.hp - self.damage
            -- splash: 명중점(주 타겟 위치) 기준 반경 SPLASH_RADIUS 안의 "다른" 적에게
            -- 중심 100%→가장자리 50% 선형 낙폭 피해를 준다(신규 능력 경로 → floor·min1 적용).
            -- 주 타겟 자신은 이미 위에서 데미지를 받았으므로 이중 타격하지 않고, 은신 중인
            -- 피해자는 면제한다(phase와의 상호작용은 각 피해자마다 독립적으로 판정).
            if self.splash then
                self.splashHit = true
                self.hitX, self.hitY = self.target.x, self.target.y
                for _, e in ipairs(enemies or {}) do
                    if e ~= self.target and not e.dead and not e.reached and not e:isPhased(clock) then
                        local ex, ey = e.x - self.hitX, e.y - self.hitY
                        local ed = math.sqrt(ex * ex + ey * ey)
                        if ed <= SPLASH_RADIUS then
                            local falloff = 1 - 0.5 * (ed / SPLASH_RADIUS)
                            e.hp = e.hp - math.max(1, math.floor(self.damage * falloff))
                        end
                    end
                end
            end
        end
        self.done = true
    else
        self.x = self.x + dx / dist * step
        self.y = self.y + dy / dist * step
    end
end

return Projectile
