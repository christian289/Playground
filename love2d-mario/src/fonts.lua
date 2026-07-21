local fonts = {}

local PATH = "assets/fonts/NanumGothic-Regular.ttf"

function fonts.load()
    fonts.small = love.graphics.newFont(PATH, 14)
    fonts.normal = love.graphics.newFont(PATH, 18)
    fonts.big = love.graphics.newFont(PATH, 40)
end

return fonts
