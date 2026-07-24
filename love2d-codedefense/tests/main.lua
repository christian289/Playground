-- 프로젝트 루트를 package.path에 추가해 src.* 를 require 가능하게 한다
local ROOT = love.filesystem.getSource():gsub("[/\\]tests$", "")
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path
_G.PROJECT_ROOT = ROOT   -- 데이터 파일 io 접근용

local suites = { "test_csv", "test_grid", "test_sandbox", "test_battle", "test_data", "test_editor", "test_progress", "test_tutorial", "test_particles", "test_cutscene", "test_stageinfo", "test_demolish", "test_stars", "test_abilities", "test_shell" }
local pass, fail = 0, 0

local t = {}
function t.ok(cond, label)
    if cond then pass = pass + 1; print("PASS " .. label)
    else fail = fail + 1; print("FAIL " .. label) end
end
function t.eq(a, b, label)
    if a == b then pass = pass + 1; print("PASS " .. label)
    else fail = fail + 1; print(("FAIL %s: got %s, want %s"):format(label, tostring(a), tostring(b))) end
end

function love.load()
    for _, name in ipairs(suites) do
        local path = ROOT .. "/tests/" .. name .. ".lua"
        local f = io.open(path, "rb")
        if f then
            f:close()
            print("== " .. name)
            local chunk = assert(loadfile(path))
            local okRun, err = pcall(chunk(), t)
            if not okRun then fail = fail + 1; print("FAIL (suite error) " .. tostring(err)) end
        end
    end
    print(("RESULT pass=%d fail=%d"):format(pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
end
