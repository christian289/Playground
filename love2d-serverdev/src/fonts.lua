local fonts = {}
local PATH = "assets/fonts/NanumGothic-Regular.ttf"

function fonts.load()
    fonts.small = love.graphics.newFont(PATH, 14)
    fonts.ui = love.graphics.newFont(PATH, 18)
    fonts.mono = love.graphics.newFont(PATH, 16)
    fonts.big = love.graphics.newFont(PATH, 32)
    fonts.subtitle = love.graphics.newFont(PATH, 26) -- 타이틀 화면 모토(부제) 전용 — 메인 타이틀과 태그라인 사이 중간 크기
    fonts.title = love.graphics.newFont(PATH, 40) -- 타이틀 화면 게임명(문장형 제목) 전용, 폰트 렌더 기반
end

return fonts
