local csv = require("src.csv")
local db = {}

local function index(recs, numfields)
    local out = {}
    for _, r in ipairs(recs) do
        for _, f in ipairs(numfields) do
            if r[f] == "" then r[f] = nil else r[f] = tonumber(r[f]) or r[f] end
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
        { "cost", "damage", "range", "cooldown", "bullet_speed", "limit", "hidden" })
    d.enemies = index(csv.load(root .. "/data/enemies.csv"), { "hp", "speed", "reward" })
    d.items = index(csv.load(root .. "/data/items.csv"), {})
    d.stages = index(csv.load(root .. "/data/stages.csv"), { "budget", "wave_clock", "countdown", "puzzle" })

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
        local mazeRow1Cache = {}
        local function mazeRow1(mazeFile)
            if mazeRow1Cache[mazeFile] == nil then
                local f = io.open(root .. "/data/" .. mazeFile, "rb")
                if f then
                    local line = f:read("*l") or ""
                    f:close()
                    mazeRow1Cache[mazeFile] = line
                else
                    mazeRow1Cache[mazeFile] = false
                end
            end
            return mazeRow1Cache[mazeFile] or nil
        end
        for _, e in ipairs(events) do
            if not d.enemies[e.spawn] then
                errs[#errs + 1] = ("timelines: 스테이지 %s의 spawn '%s'가 enemies.csv에 없음")
                    :format(tostring(e.stage_id), tostring(e.spawn))
            end
            if not d.stages[e.stage_id] then
                errs[#errs + 1] = "timelines: 없는 스테이지 " .. tostring(e.stage_id)
            else
                local stage = d.stages[e.stage_id]
                local line = mazeRow1(stage.maze_file)
                if line then
                    if line:sub(e.col, e.col) ~= "." then
                        errs[#errs + 1] = ("timelines: 스테이지 %s의 스폰 열 %d는 1행 통로가 아님")
                            :format(tostring(e.stage_id), e.col)
                    end
                end
            end
        end
        for id, s in pairs(d.stages) do
            if s.mode == "normal" then
                local tl = d.timeline(id)
                if #tl > 0 then
                    local prevEnd = nil
                    for _, e in ipairs(tl) do
                        local eEnd = e.at + (e.count - 1) * e.interval
                        if prevEnd then
                            local gap = e.at - prevEnd
                            if gap > 40 then
                                errs[#errs + 1] = ("timelines: 스테이지 %s 스폰 공백 %d초 > 40초 (at %d)")
                                    :format(tostring(id), math.floor(gap + 0.5), math.floor(e.at + 0.5))
                            end
                        end
                        prevEnd = eEnd
                    end
                    if prevEnd < 240 then
                        errs[#errs + 1] = ("timelines: 스테이지 %s 마지막 스폰 종료 %d초 < 240초")
                            :format(tostring(id), math.floor(prevEnd + 0.5))
                    end
                end
            end
        end
        for id, s in pairs(d.stages) do
            if not fileExists(s.maze_file) then
                errs[#errs + 1] = ("stages %s: 미로 파일 없음 %s"):format(id, s.maze_file)
            end
            if s.solution_file ~= "" and not fileExists(s.solution_file) then
                errs[#errs + 1] = ("stages %s: 정답 파일 없음 %s"):format(id, s.solution_file)
            end
            -- Wave D Task 4: ui=shell 스테이지는 solution_file이 ".sh" 확장자로 실제
            -- 존재해야 한다(러너가 이 파일을 줄 단위 shell:exec로 읽으므로 .lua 파일이나
            -- 빈 값이면 안 된다). 위 일반 검사는 solution_file이 빈 값이면 통과시키므로
            -- (s.solution_file ~= "" 게이트) 셸 스테이지는 별도로 걸러야 한다.
            if s.ui == "shell" then
                local sf = s.solution_file or ""
                if sf == "" or not sf:match("%.sh$") or not fileExists(sf) then
                    errs[#errs + 1] = ("stages %s: 솔루션(.sh) 파일 없음 %s"):format(id, sf)
                end
            end
            if s.hints_file ~= "" and not fileExists(s.hints_file) then
                errs[#errs + 1] = ("stages %s: 힌트 파일 없음 %s"):format(id, s.hints_file)
            end
            if s.reward_item ~= "" and not d.items[s.reward_item] then
                errs[#errs + 1] = ("stages %s: 없는 보상 아이템 %s"):format(id, s.reward_item)
            end
            if s.tutorial_file ~= "" and not fileExists(s.tutorial_file) then
                errs[#errs + 1] = ("stages %s: 튜토리얼 파일 없음 %s"):format(id, s.tutorial_file)
            end
            if s.buttons_file ~= "" and not fileExists(s.buttons_file) then
                errs[#errs + 1] = ("stages %s: 버튼 파일 없음 %s"):format(id, s.buttons_file)
            end
            if s.naive_file and s.naive_file ~= "" and not fileExists(s.naive_file) then
                errs[#errs + 1] = ("stages %s: 순진 배치 파일 없음 %s"):format(id, s.naive_file)
            end
            if s.lore_file and s.lore_file ~= "" and not fileExists(s.lore_file) then
                errs[#errs + 1] = ("stages %s: 로어 파일 없음 %s"):format(id, s.lore_file)
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
