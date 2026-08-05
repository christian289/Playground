-- 프로젝트 루트를 package.path에 추가해 src.* 를 require 가능하게 한다
local ROOT = love.filesystem.getSource():gsub("[/\\]tests$", "")
package.path = ROOT .. "/?.lua;" .. ROOT .. "/?/init.lua;" .. package.path
_G.PROJECT_ROOT = ROOT   -- 데이터 파일 io 접근용

local suites = { "test_csv", "test_grid", "test_sandbox", "test_api", "test_battle", "test_data", "test_editor", "test_editorpractice", "test_progress", "test_tutorial", "test_particles", "test_cutscene", "test_stageinfo", "test_demolish", "test_stars", "test_abilities", "test_shell", "test_factions" }
local requestedSuite = os.getenv("LOVE_TEST_SUITE")
local pass, fail = 0, 0

if requestedSuite then
    local known = false
    for _, name in ipairs(suites) do
        if name == requestedSuite then known = true; break end
    end
    if not known then
        fail = 1
        print("FAIL 알 수 없는 테스트 스위트: " .. requestedSuite)
    end
end

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
        if not requestedSuite or name == requestedSuite then
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
    end
    print(("RESULT pass=%d fail=%d"):format(pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
end
