return function(t)
    local sb = require("src.sandbox")

    -- 정상 실행
    local env = sb.baseEnv()
    local ok = sb.compile("function on_tick() return math.max(1, 2) end", env, "t1")
    t.ok(ok, "compile 성공")
    local ok2, _, used = sb.call(env.on_tick, 10000)
    t.ok(ok2, "call 성공")
    t.ok(used >= 0, "명령 수 반환")

    -- 문법 오류
    local bad, err = sb.compile("function on_tick( return end", sb.baseEnv(), "t2")
    t.ok(bad == nil and err ~= nil, "문법 오류 감지")

    -- 샌드박스 탈출 차단
    local esc = sb.baseEnv()
    t.ok(esc.io == nil and esc.os == nil and esc.love == nil and esc.debug == nil
        and esc.loadstring == nil and esc.getfenv == nil and esc.setfenv == nil
        and esc.rawset == nil and esc._G == nil,
        "io/os/love/debug/loadstring/_G 차단")

    -- 전역 오염 차단: 유저 코드의 전역은 env에만 남는다
    local iso = sb.baseEnv()
    sb.compile("leaked = 123", iso, "t3")
    t.ok(_G.leaked == nil and iso.leaked == 123, "전역 오염 격리")

    -- 무한 루프 → 예산 초과 오류
    local loopEnv = sb.baseEnv()
    sb.compile("function on_tick() while true do end end", loopEnv, "t4")
    local ok3, err3 = sb.call(loopEnv.on_tick, 5000)
    t.ok(not ok3, "무한 루프 중단")
    t.ok(tostring(err3):find("예산"), "예산 초과 메시지")

    -- 런타임 오류가 pcall로 격리
    local errEnv = sb.baseEnv()
    sb.compile("function on_tick() local x = nil; return x.y end", errEnv, "t5")
    local ok4, err4 = sb.call(errEnv.on_tick, 5000)
    t.ok(not ok4 and err4 ~= nil, "런타임 오류 격리")

    -- 정의부 무한 루프도 예산으로 차단
    local topLoop, terr = sb.compile("while true do end", sb.baseEnv(), "t6")
    t.ok(topLoop == nil and tostring(terr):find("예산"), "정의부 무한 루프 차단")
end
