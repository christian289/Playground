-- 룩 아이콘 PNG 내보내기 (패키징용) — art.rookIconData를 단일 소스로 여러 크기 생성
-- 실행: & "C:\Program Files\LOVE\lovec.exe" tools/genicon   (package.ps1이 자동 호출)
-- 출력: dist/icon/rook-<size>.png  (폴더는 package.ps1이 미리 생성)

function love.load()
    local root = love.filesystem.getSource():gsub("[/\\]tools[/\\]genicon$", "")
    package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
    love.graphics.setDefaultFilter("nearest", "nearest")
    local art = require("src.art")
    art.load()
    local base = art.rookIconData() -- 32x32 ImageData

    local function scaled(size)
        local out = love.image.newImageData(size, size)
        for y = 0, size - 1 do
            for x = 0, size - 1 do
                local sx = math.floor(x * 32 / size)
                local sy = math.floor(y * 32 / size)
                out:setPixel(x, y, base:getPixel(sx, sy))
            end
        end
        return out
    end

    for _, s in ipairs({ 16, 32, 48, 256 }) do
        local png = scaled(s):encode("png"):getString()
        local f = assert(io.open(root .. "/dist/icon/rook-" .. s .. ".png", "wb"),
            "dist/icon 폴더가 없습니다 — tools/package.ps1로 실행하세요")
        f:write(png)
        f:close()
    end
    print("ICON_OK")
    love.event.quit(0)
end
