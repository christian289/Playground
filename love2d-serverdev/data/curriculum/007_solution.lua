-- 스택 · 반복문: for로 모든 적을 순회하며 체력이 가장 낮은 적을 고른다
build("printer", 6, 7, "a")
build("printer", 12, 8, "b")

function on_tick(self, world)
    local target = nil
    for _, e in ipairs(world.enemies()) do
        if not target or e.hp < target.hp then
            target = e
        end
    end
    if target then
        self:attack(target)
    end
end
