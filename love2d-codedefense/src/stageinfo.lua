-- 스테이지 적 구성 계산 (순수 모듈 — love 금지, 헤드리스 테스트 가능).
-- battle의 timeline/spawned/enemies를 읽기만 한다. 뷰(states/play.lua)가 이 값을 그린다.
local stageinfo = {}

-- 타임라인에서 종류별/전체 적 수와 마지막 스폰 종료 시각을 계산한다 (결정론).
function stageinfo.totals(timeline)
    local byType, total, lastEnd = {}, 0, 0
    for _, ev in ipairs(timeline) do
        byType[ev.spawn] = (byType[ev.spawn] or 0) + ev.count
        total = total + ev.count
        local eEnd = ev.at + (ev.count - 1) * ev.interval
        if eEnd > lastEnd then lastEnd = eEnd end
    end
    return { byType = byType, total = total, lastEnd = lastEnd, events = timeline }
end

-- 종류별 처리 수(처치+도달) = 전체 − (미스폰 잔여 + 필드 생존).
-- 미스폰 잔여은 이벤트 인덱스별 battle.spawned와 이벤트 count를 대조해 구한다.
function stageinfo.killedCounts(totals, battle)
    local unspawned = {}
    for i, ev in ipairs(totals.events) do
        local n = (battle.spawned and battle.spawned[i]) or 0
        local remain = ev.count - n
        if remain > 0 then
            unspawned[ev.spawn] = (unspawned[ev.spawn] or 0) + remain
        end
    end
    local onField = {}
    for _, e in ipairs(battle.enemies or {}) do
        local id = e.def.id
        onField[id] = (onField[id] or 0) + 1
    end
    local processed = {}
    for id, total in pairs(totals.byType) do
        local remain = (unspawned[id] or 0) + (onField[id] or 0)
        processed[id] = math.max(0, total - remain)
    end
    return processed
end

return stageinfo
