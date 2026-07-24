-- src/shell.lua — Code Defense 셸 진영 파서(순수 Lua, love API/love.timer 금지).
-- "문자열 in → 문자열 out" 게이트웨이: Shell.new(battle) → shell:exec(line, opts)
-- → { ok, output, [open], [clear] }. shell:tick(clock)이 cron 예약 명령을 실행한다.
-- 이후 회차(외부 제어 어댑터)가 이 계약을 그대로 재사용할 예정이므로, 여기서 view(states/*)를
-- 직접 호출하지 않는다 — man/clear는 신호 필드(open/clear)만 반환해 뷰가 소비하게 한다.
local stageinfo = require("src.stageinfo")
local Enemy = require("src.enemy")

local Shell = {}
Shell.__index = Shell

local MAX_OUTPUT_LINES = 20   -- 명령당 출력 절단 상한(계획서 §Global Constraints)

-- ps1 별칭 → 정규 명령 토큰열. 별칭은 첫 토큰만 치환하고 나머지 인자는 그대로 이어붙인다
-- (별칭 라우팅이 원 명령과 완전히 동일한 코드 경로를 타게 하기 위함 — 별도 분기 없음).
local PS1_ALIASES = {
    ["Remove-Item"] = { "rm" },
    ["Get-Process"] = { "ls", "enemies" },
    ["Get-Content"] = { "man" },
    ["dir"] = { "ls" },
}

-- 오타 제안 후보 명령어 집합(인자는 대상이 아니다 — 레벤슈타인은 명령어 토큰에만 적용)
local COMMAND_NAMES = { "build", "rm", "ls", "top", "target", "cron", "man", "history", "clear" }

local USAGE = {
    build = "usage: build <타워> <행> <열> <이름>",
    rm = "usage: rm <이름>",
    target = "usage: target <타워> <전략>",
    cron = 'usage: cron <초간격> "<명령>"',
    man = "usage: man <명령>",
    ls = "usage: ls [enemies]",
}

----------------------------------------------------------------
-- 토크나이저: 공백(다중/앞뒤) 허용, 큰따옴표로 감싼 인자는 내부 공백을 보존한 채
-- 한 토큰으로 취급한다(예: cron 2 "target a nearest" → {"cron","2","target a nearest"}).
----------------------------------------------------------------
local function tokenize(line)
    local tokens = {}
    local i, n = 1, #line
    while i <= n do
        local c = line:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == '"' then
            local close = line:find('"', i + 1, true)
            if close then
                tokens[#tokens + 1] = line:sub(i + 1, close - 1)
                i = close + 1
            else
                tokens[#tokens + 1] = line:sub(i + 1)
                i = n + 1
            end
        else
            local j = i
            while j <= n and not line:sub(j, j):match("%s") and line:sub(j, j) ~= '"' do
                j = j + 1
            end
            tokens[#tokens + 1] = line:sub(i, j - 1)
            i = j
        end
    end
    return tokens
end

----------------------------------------------------------------
-- 레벤슈타인 거리(명령어 오타 제안 전용 — 인자에는 적용하지 않는다)
----------------------------------------------------------------
local function levenshtein(a, b)
    local la, lb = #a, #b
    if la == 0 then return lb end
    if lb == 0 then return la end
    local prev = {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        local cur = { [0] = i }
        local ca = a:sub(i, i)
        for j = 1, lb do
            local cost = (ca == b:sub(j, j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        end
        prev = cur
    end
    return prev[lb]
end

-- 거리 1 이내 후보가 있으면 그 명령 이름을, 없으면 nil을 반환한다.
local function suggest(input)
    local best, bestDist
    for _, name in ipairs(COMMAND_NAMES) do
        local dist = levenshtein(input, name)
        if not bestDist or dist < bestDist then best, bestDist = name, dist end
    end
    if bestDist and bestDist <= 1 then return best end
    return nil
end

-- 명령당 출력 20줄 초과 시 20줄 + "…외 n건"으로 절단한다.
local function truncate(output)
    if #output <= MAX_OUTPUT_LINES then return output end
    local out = {}
    for i = 1, MAX_OUTPUT_LINES do out[i] = output[i] end
    out[MAX_OUTPUT_LINES + 1] = ("…외 %d건"):format(#output - MAX_OUTPUT_LINES)
    return out
end

local function prepend(welcome, rest)
    if #welcome == 0 then return rest end
    local out = {}
    for _, l in ipairs(welcome) do out[#out + 1] = l end
    for _, l in ipairs(rest) do out[#out + 1] = l end
    return out
end

----------------------------------------------------------------
-- 명령 구현: 각 run(shell, args, opts)은 { ok, output, [open], [clear] }을 반환한다.
-- battle.log를 재사용할 수 있는 경우(로그를 이미 남기는 API)는 그대로 전달하고,
-- 그렇지 않은 성공 경로(예: target 성공)는 셸이 직접 메시지를 구성한다.
----------------------------------------------------------------
local function cmdBuild(shell, args)
    if #args ~= 4 then return { ok = false, output = { USAGE.build } } end
    local battle = shell.battle
    local before = #battle.log
    local ok, err = battle:buildTower(args[1], args[2], args[3], args[4])
    if ok then
        if #battle.log > before then
            return { ok = true, output = { battle.log[#battle.log] } }
        end
        return { ok = true, output = { ("이미 존재하는 타워입니다 — \"%s\""):format(args[4]) } }
    end
    return { ok = false, output = { "[오류] " .. tostring(err) } }
end

local function cmdRm(shell, args)
    if #args ~= 1 then return { ok = false, output = { USAGE.rm } } end
    local battle = shell.battle
    local ok = battle:demolishTower(args[1])
    return { ok = ok, output = { battle.log[#battle.log] } }
end

local function cmdLs(shell, args)
    local battle = shell.battle
    if #args == 0 then
        if #battle.towers == 0 then return { ok = true, output = { "배치된 타워가 없습니다" } } end
        local out = {}
        for _, tw in ipairs(battle.towers) do
            out[#out + 1] = ("\"%s\" %s (%d,%d) · 전략 %s")
                :format(tw.name, tw.def.name, tw.r, tw.c, tw.strategy or "nearest")
        end
        return { ok = true, output = out }
    elseif #args == 1 and args[1] == "enemies" then
        local list = {}
        for _, e in ipairs(battle.enemies) do
            if not e.dead and not e.reached and not e:isPhased(battle.clock) then
                list[#list + 1] = e
            end
        end
        table.sort(list, function(a, b)
            if a.spawnedAt ~= b.spawnedAt then return a.spawnedAt < b.spawnedAt end
            return a.id < b.id
        end)
        if #list == 0 then return { ok = true, output = { "필드에 적이 없습니다" } } end
        local out = {}
        for _, e in ipairs(list) do
            out[#out + 1] = ("%s HP %d (%d,%d)"):format(e.def.name, e.hp, e.r, e.c)
        end
        return { ok = true, output = out }
    else
        return { ok = false, output = { USAGE.ls } }
    end
end

local function cmdTop(shell, args, opts)
    local battle = shell.battle
    local line = ("서버 HP %d · 잔액 $%d · 처치 %d/%d")
        :format(battle.serverHP, battle.money, battle.kills or 0, shell.totalEnemies or 0)
    if opts and opts.speed then
        line = line .. (" · 배속 x%g"):format(opts.speed)
    end
    return { ok = true, output = { line } }
end

local function cmdTarget(shell, args)
    if #args ~= 2 then return { ok = false, output = { USAGE.target } } end
    local battle = shell.battle
    local ok = battle:setTargetStrategy(args[1], args[2])
    if ok then
        return { ok = true, output = { ("전략 변경 — \"%s\" → %s"):format(args[1], args[2]) } }
    end
    return { ok = false, output = { battle.log[#battle.log] } }
end

local function cmdCron(shell, args)
    if args[1] == "-l" then
        if #shell.cronJobs == 0 then return { ok = true, output = { "등록된 cron 작업이 없습니다" } } end
        local out = {}
        for _, job in ipairs(shell.cronJobs) do
            out[#out + 1] = ("cron#%d · %g초마다 · 다음 %g · \"%s\""):format(job.id, job.interval, job.nextAt, job.line)
        end
        return { ok = true, output = out }
    elseif args[1] == "-r" then
        local id = #args == 2 and tonumber(args[2]) or nil
        if not id then return { ok = false, output = { USAGE.cron } } end
        for i, job in ipairs(shell.cronJobs) do
            if job.id == id then
                table.remove(shell.cronJobs, i)
                return { ok = true, output = { ("cron#%d 삭제됨"):format(id) } }
            end
        end
        return { ok = false, output = { ("[오류] cron#%d 없음"):format(id) } }
    else
        if #args ~= 2 then return { ok = false, output = { USAGE.cron } } end
        local interval = tonumber(args[1])
        local line = args[2]
        if not interval then return { ok = false, output = { USAGE.cron } } end
        if interval < 1.0 then
            return { ok = false, output = { "[오류] 간격은 1초 이상이어야 합니다" } }
        end
        local id = shell.nextCronId
        shell.nextCronId = shell.nextCronId + 1
        local job = { id = id, interval = interval, line = line, nextAt = shell.battle.clock + interval }
        shell.cronJobs[#shell.cronJobs + 1] = job
        return { ok = true, output = { ("cron#%d 등록 · %g초마다 · \"%s\""):format(id, interval, line) } }
    end
end

local function cmdMan(shell, args)
    if #args ~= 1 then return { ok = false, output = { USAGE.man } } end
    return { ok = true, output = {}, open = args[1] }
end

local function cmdHistory(shell)
    local out = {}
    for i, line in ipairs(shell.history) do
        out[#out + 1] = ("%d  %s"):format(i, line)
    end
    return { ok = true, output = out }
end

local function cmdClear()
    return { ok = true, output = {}, clear = true }
end

local COMMANDS = {
    build = cmdBuild,
    rm = cmdRm,
    ls = cmdLs,
    top = cmdTop,
    target = cmdTarget,
    cron = cmdCron,
    man = cmdMan,
    history = cmdHistory,
    clear = cmdClear,
}

----------------------------------------------------------------
-- Shell 객체
----------------------------------------------------------------
-- "처치 k/N"의 N: 타임라인 스폰 수(stageinfo.totals)가 기본이지만, split/split2 능력을
-- 지닌 적(예: concat-nil)은 처치될 때마다 자식으로 갈라져 battle.kills를 스폰 수보다 더
-- 늘릴 수 있다(부모+자식 모두 처치되면 kills가 스폰 1기당 최대 3배(split)·7배(split2)까지
-- 누적 — src/battle.lua의 분열 처리 참고). 그대로 두면 "처치 k/N"에서 k가 N을 넘어서는
-- 모순된 표기가 나올 수 있으므로(스테이지 104 concat-nil로 실측 재현, k=90 > N=61),
-- N을 "모든 분열 자손까지 처치했을 때의 최대 가능 처치 수"로 보정한다. split이 없는
-- 스테이지는 보정량이 0이라 기존 표기(스폰 수 그대로)와 완전히 동일하다.
function Shell.expectedTotal(battle)
    local total = stageinfo.totals(battle.timeline).total
    for _, ev in ipairs(battle.timeline) do
        local def = battle.d.enemies[ev.spawn]
        local abilities = def and Enemy.parseAbilities(def.abilities)
        if abilities then
            if abilities.split2 then
                total = total + ev.count * 6   -- 자식 2(깊이1) + 손자 4(깊이2)
            elseif abilities.split then
                total = total + ev.count * 2   -- 자식 2(깊이1, 더 분열하지 않음)
            end
        end
    end
    return total
end

function Shell.new(battle)
    local self = setmetatable({}, Shell)
    self.battle = battle
    self.history = {}
    self.cronJobs = {}
    self.nextCronId = 1
    self.ps1WelcomeShown = false
    self.totalEnemies = Shell.expectedTotal(battle)
    return self
end

-- exec/tick 공용 내부 실행기(히스토리에는 기록하지 않는다 — exec만 기록).
-- 별칭은 여기서 토큰만 치환한 뒤 정규 명령과 완전히 동일한 경로(COMMANDS 조회)로 흘러간다.
function Shell:runLine(line, opts)
    local tokens = tokenize(line)
    if #tokens == 0 then return { ok = true, output = {} } end

    local cmdName = tokens[1]
    local args = {}
    for i = 2, #tokens do args[#args + 1] = tokens[i] end

    local welcome = {}
    local alias = PS1_ALIASES[cmdName]
    if alias then
        if not self.ps1WelcomeShown then
            self.ps1WelcomeShown = true
            welcome[#welcome + 1] = "PowerShell 사용자를 환영합니다"
        end
        local rewritten = {}
        for _, tk in ipairs(alias) do rewritten[#rewritten + 1] = tk end
        for _, tk in ipairs(args) do rewritten[#rewritten + 1] = tk end
        cmdName = rewritten[1]
        args = {}
        for i = 2, #rewritten do args[#args + 1] = rewritten[i] end
    end

    local handler = COMMANDS[cmdName]
    if not handler then
        local candidate = suggest(cmdName)
        local msg = "command not found: " .. cmdName
        if candidate then msg = msg .. (" — '%s'를 의미했나요?"):format(candidate) end
        return { ok = false, output = truncate(prepend(welcome, { msg })) }
    end

    local result = handler(self, args, opts)
    result.output = truncate(prepend(welcome, result.output or {}))
    return result
end

-- 외부(뷰/테스트/향후 어댑터)가 부르는 유일한 실행 진입점. 실행한 원문을 이력에 남긴다.
function Shell:exec(line, opts)
    self.history[#self.history + 1] = line
    return self:runLine(line, opts)
end

-- battle clock(인자)만으로 due한 cron 작업을 id 순으로 실행한다. 자체 시계를 두지
-- 않으며, 등록 시각 기준 산술(nextAt += interval)이라 드리프트가 없다. 한 번의 호출에서
-- 여러 간격을 건너뛴 경우(큰 clock 점프) 그만큼 반복 실행해 캐치업한다.
function Shell:tick(clock)
    local out = {}
    for _, job in ipairs(self.cronJobs) do
        while clock >= job.nextAt do
            out[#out + 1] = ("[cron#%d] %s"):format(job.id, job.line)
            local result = self:runLine(job.line, {})
            for _, l in ipairs(result.output or {}) do out[#out + 1] = l end
            job.nextAt = job.nextAt + job.interval
        end
    end
    return out
end

return Shell
