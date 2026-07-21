return function(t)
    local progress = require("src.progress")
    local p = { cleared = { [1] = true, [2] = true }, items = { "cache" },
        codes = { [1] = 'function on_tick(self, world)\n  self:attack(world.nearest())\nend' } }
    progress.save(p)
    local q = progress.load()
    t.ok(q.cleared[1] and q.cleared[2], "클리어 저장/복원")
    t.eq(q.items[1], "cache", "아이템 저장/복원")
    t.ok(q.codes[1]:find("on_tick"), "코드 저장/복원")
    local empty = progress.load("없는파일.lua")
    t.ok(type(empty.cleared) == "table" and next(empty.cleared) == nil, "빈 진행도 기본값")
end
