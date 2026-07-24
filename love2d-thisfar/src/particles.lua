-- 뷰 전용 파티클. 시뮬 상태를 절대 만지지 않는다.
local particles = {}
particles.MAX = 400

local pool = {}

-- 각 파티클: {kind, x, y, vx, vy, ttl, age, color, text, size}
-- 방향은 스폰 인덱스 기반 고정 각도(랜덤 금지 — 뷰라도 코드 단순성/재현성 유지)
local function push(p)
    if #pool >= particles.MAX then table.remove(pool, 1) end
    pool[#pool + 1] = p
end

local KIND = {
    spark = { ttl = 0.35, speed = 90, size = 2 },
    burst = { ttl = 0.5, speed = 60, size = 3 },
    float = { ttl = 0.9, speed = 30, size = 0 },
    smoke = { ttl = 0.6, speed = 18, size = 4 },
    flash = { ttl = 0.18, speed = 0, size = 14 },
}

function particles.spawn(kind, x, y, opts)
    opts = opts or {}
    local def = KIND[kind]
    if not def then return end
    local n = opts.count or 1
    if kind == "float" or kind == "flash" then n = 1 end
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + (kind == "spark" and 0.4 or 0)
        push({
            kind = kind, x = x, y = y,
            vx = math.cos(ang) * def.speed,
            vy = (kind == "float" or kind == "smoke") and -def.speed
                or math.sin(ang) * def.speed,
            ttl = opts.ttl or def.ttl, age = 0,
            color = opts.color or { 1, 1, 1 },
            text = opts.text, size = def.size,
        })
    end
end

function particles.update(dt)
    for i = #pool, 1, -1 do
        local p = pool[i]
        p.age = p.age + dt
        if p.age >= p.ttl then
            table.remove(pool, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

function particles.draw(ox, oy)
    for _, p in ipairs(pool) do
        local a = 1 - p.age / p.ttl
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
        if p.text then
            love.graphics.print(p.text, ox + p.x, oy + p.y)
        elseif p.kind == "flash" then
            love.graphics.circle("line", ox + p.x, oy + p.y, p.size * (1 - a) * 2 + 4)
        else
            local s = p.size
            love.graphics.rectangle("fill", ox + p.x - s / 2, oy + p.y - s / 2, s, s)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function particles.count() return #pool end
function particles.clear() pool = {} end

return particles
