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
    t.ok(type(empty.tutorial_done) == "table" and next(empty.tutorial_done) == nil, "tutorial_done 기본값")
    local p2 = progress.load()
    p2.intro_seen = true
    progress.save(p2)
    t.ok(progress.load().intro_seen, "intro_seen 저장/복원")

    local pr = progress.load()
    pr.records = { [3] = { tries = 2, clears = 1, bestHP = 9, lastResult = "clear", gugu = true } }
    progress.save(pr)
    local qr = progress.load()
    t.eq(qr.records[3].bestHP, 9, "records 왕복")
    t.ok(qr.records[3].gugu, "gugu 기록 왕복")

    local pf = progress.load()
    pf.funcbook = { on_tick = { first = 3, count = 5 } }
    progress.save(pf)
    t.eq(progress.load().funcbook.on_tick.count, 5, "funcbook 왕복")
    t.ok(type(progress.load().funcbook) == "table", "funcbook 기본값 보강")
    local practice = progress.load("없는연습진행도.lua")
    t.eq(practice.editor_practice_done, false, "에디터 워밍업 미완료 기본값")
    practice.editor_practice_done = true
    progress.save(practice)
    t.ok(progress.load().editor_practice_done, "에디터 워밍업 완료 저장/복원")
    local fresh = progress.load("없는배속진행도.lua")
    t.eq(fresh.play_speed, 1, "기본 배속은 x1")
    fresh.play_speed = 4
    progress.save(fresh)
    t.eq(progress.load().play_speed, 4, "선호 배속 저장/복원")
end
