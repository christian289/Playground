-- 별점 산식(순수 모듈, 뷰 비의존): 클리어 시 서버 HP 기준으로 별 개수를 매긴다.
-- 산식(고정): HP>=8 → ★3, HP>=4 → ★2, 그 외 → ★1 (클리어를 전제로 한다 — 미클리어에는 의미 없음)
local stars = {}

function stars.of(hp)
    hp = hp or 0
    if hp >= 8 then return 3 end
    if hp >= 4 then return 2 end
    return 1
end

return stars
