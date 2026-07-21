local fonts = {}
local PATH = "assets/fonts/NanumGothic-Regular.ttf"

function fonts.load()
    fonts.small = love.graphics.newFont(PATH, 14)
    fonts.ui = love.graphics.newFont(PATH, 18)
    fonts.mono = love.graphics.newFont(PATH, 16)
    fonts.big = love.graphics.newFont(PATH, 32)
end

return fonts
