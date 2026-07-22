return function(t)
    local particles = require("src.particles")
    particles.clear()

    particles.spawn("spark", 10, 10, { count = 5 })
    t.eq(particles.count(), 5, "spark 5개 스폰")

    particles.spawn("float", 10, 10, { text = "+10" })
    t.eq(particles.count(), 6, "float 텍스트 스폰")

    -- 수명 만료 제거 (spark ttl 0.35, float ttl 0.9)
    particles.update(0.5)
    t.eq(particles.count(), 1, "spark 만료 후 float만 생존")
    particles.update(0.5)
    t.eq(particles.count(), 0, "float 만료")

    -- 상한: 오래된 것부터 제거
    particles.clear()
    for i = 1, 450 do particles.spawn("spark", i, 0, { count = 1 }) end
    t.eq(particles.count(), particles.MAX, "상한 400 유지")

    -- 이동 갱신 (결정론 무관, vy 존재 확인)
    particles.clear()
    particles.spawn("burst", 0, 0, { count = 3 })
    local before = particles.count()
    particles.update(0.01)
    t.eq(particles.count(), before, "짧은 dt에는 생존")
end
