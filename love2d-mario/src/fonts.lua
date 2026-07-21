local fonts = {}

function fonts.load()
    fonts.small = love.graphics.newFont(13)
    fonts.normal = love.graphics.newFont(18)
    fonts.big = love.graphics.newFont(40)
end

return fonts
