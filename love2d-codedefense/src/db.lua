local csv = require("src.csv")
local db = {}

local function index(recs, numfields)
    local out = {}
    for _, r in ipairs(recs) do
        for _, f in ipairs(numfields) do
            r[f] = (r[f] ~= "" and tonumber(r[f])) or (r[f] == "" and nil or r[f])
        end
        local id = tonumber(r.id) or r.id
        r.id = id
        out[id] = r
    end
    return out
end

function db.load(root)
    local d = { root = root }
    d.towers = index(csv.load(root .. "/data/towers.csv"),
        { "cost", "damage", "range", "cooldown", "bullet_speed" })
    d.enemies = index(csv.load(root .. "/data/enemies.csv"), { "hp", "speed", "reward" })
    d.items = index(csv.load(root .. "/data/items.csv"), {})
    d.stages = index(csv.load(root .. "/data/stages.csv"), { "budget", "wave_clock" })
    for _, s in pairs(d.stages) do
        local pauses = {}
        for _, v in ipairs(csv.list(s.pause_at)) do pauses[#pauses + 1] = tonumber(v) end
        s.pause_at = pauses
    end

    local events = csv.load(root .. "/data/timelines.csv")
    for _, e in ipairs(events) do
        e.stage_id = tonumber(e.stage_id)
        e.at, e.count, e.interval, e.col =
            tonumber(e.at), tonumber(e.count), tonumber(e.interval) or 0, tonumber(e.col)
    end
    function d.timeline(stageId)
        local out = {}
        for _, e in ipairs(events) do
            if e.stage_id == stageId then out[#out + 1] = e end
        end
        table.sort(out, function(a, b) return a.at < b.at end)
        return out
    end

    function d.validate()
        local errs = {}
        local function fileExists(rel)
            local f = io.open(root .. "/data/" .. rel, "rb")
            if f then f:close(); return true end
            return false
        end
        for _, e in ipairs(events) do
            if not d.enemies[e.spawn] then
                errs[#errs + 1] = ("timelines: 스테이지 %s의 spawn '%s'가 enemies.csv에 없음")
                    :format(tostring(e.stage_id), tostring(e.spawn))
            end
            if not d.stages[e.stage_id] then
                errs[#errs + 1] = "timelines: 없는 스테이지 " .. tostring(e.stage_id)
            end
        end
        for id, s in pairs(d.stages) do
            if not fileExists(s.maze_file) then
                errs[#errs + 1] = ("stages %s: 미로 파일 없음 %s"):format(id, s.maze_file)
            end
            if s.solution_file ~= "" and not fileExists(s.solution_file) then
                errs[#errs + 1] = ("stages %s: 정답 파일 없음 %s"):format(id, s.solution_file)
            end
            if s.hints_file ~= "" and not fileExists(s.hints_file) then
                errs[#errs + 1] = ("stages %s: 힌트 파일 없음 %s"):format(id, s.hints_file)
            end
            if s.reward_item ~= "" and not d.items[s.reward_item] then
                errs[#errs + 1] = ("stages %s: 없는 보상 아이템 %s"):format(id, s.reward_item)
            end
        end
        for id, tw in pairs(d.towers) do
            if tw.requires ~= "" and not d.towers[tw.requires] then
                errs[#errs + 1] = ("towers %s: 없는 requires %s"):format(id, tw.requires)
            end
        end
        return errs
    end
    return d
end

return db
