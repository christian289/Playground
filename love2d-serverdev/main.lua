local Gamestate = require("lib.hump.gamestate")
local fonts = require("src.fonts")
local db = require("src.db")
local progress = require("src.progress")

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setKeyRepeat(true)
    fonts.load()
    local art = require("src.art")
    art.load()
    love.window.setIcon(art.rookIconData())
    -- 개발 시(love .): 소스 폴더에서 io로 데이터를 읽는다.
    -- 패키징(fuse) 시: 데이터는 zip 밖 exe 옆 data/ 폴더로 배포되므로 exe가 있는 폴더를 루트로 쓴다.
    local root = love.filesystem.getSource()
    if love.filesystem.isFused() then
        root = love.filesystem.getSourceBaseDirectory()
    elseif root:match("%.love$") then
        -- 비융합 .love 단독 실행: 게임 데이터(data/)는 exe 옆 폴더로 배포되므로 성립하지 않는 실행 방식
        error("이 .love 파일은 단독 실행용이 아닙니다.\n" ..
            "배포 폴더(ServerDev)의 ServerDev.exe를 실행해 주세요.\n" ..
            "(개발 실행은 소스 폴더에서: lovec .)")
    end
    local d = db.load(root)
    local errs = d.validate()
    if #errs > 0 then
        error("데이터 무결성 오류:\n" .. table.concat(errs, "\n"))
    end
    Gamestate.registerEvents()
    local p = progress.load()
    if p.intro_seen then
        Gamestate.switch(require("states.title"), d, p)
    else
        Gamestate.switch(require("states.intro"), d, p)
    end
end
