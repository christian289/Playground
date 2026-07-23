return function(t)
    local stars = require("src.stars")

    -- 별점 산식(고정): HP>=8 ★3, HP>=4 ★2, 그 외(클리어 전제) ★1
    t.eq(stars.of(10), 3, "HP 10 → ★3")
    t.eq(stars.of(8), 3, "HP 8 → ★3 (경계값 포함)")
    t.eq(stars.of(7), 2, "HP 7 → ★2")
    t.eq(stars.of(4), 2, "HP 4 → ★2 (경계값 포함)")
    t.eq(stars.of(3), 1, "HP 3 → ★1")
    t.eq(stars.of(1), 1, "HP 1 → ★1")
    t.eq(stars.of(0), 1, "HP 0(클리어 전제) → ★1")
end
