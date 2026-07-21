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
