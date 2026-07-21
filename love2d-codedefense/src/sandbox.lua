local sandbox = {}
sandbox.QUANTUM = 50  -- 훅 1회 = 50 명령

local function copyTable(t)
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
end

-- 유저 코드에 보이는 전역: 순수 함수만. love/io/os/debug 없음
function sandbox.baseEnv()
    return {
        math = copyTable(math), string = copyTable(string), table = copyTable(table),
        pairs = pairs, ipairs = ipairs, select = select, next = next,
        tostring = tostring, tonumber = tonumber, type = type, unpack = unpack,
    }
end

-- source의 최상위(함수 정의부)를 env에서 실행. 성공 시 env 반환
function sandbox.compile(source, env, name)
    local chunk, err = loadstring(source, "@" .. (name or "tower"))
    if not chunk then return nil, err end
    if jit then jit.off(chunk, true) end  -- count 훅이 JIT 코드에서 무시되는 것 방지
    setfenv(chunk, env)
    local ok, rerr = pcall(chunk)
    if not ok then return nil, rerr end
    return env
end

-- fn을 명령 예산 안에서 실행. return ok, err, usedInstr(QUANTUM 배수 근사)
function sandbox.call(fn, budget, ...)
    local used, limit = 0, math.ceil(budget / sandbox.QUANTUM)
    debug.sethook(function()
        used = used + 1
        if used >= limit then
            debug.sethook()
            error("명령 예산 초과 (무한 루프?)", 2)
        end
    end, "", sandbox.QUANTUM)
    local ok, err = pcall(fn, ...)
    debug.sethook()
    return ok, ok and nil or err, used * sandbox.QUANTUM
end

return sandbox
