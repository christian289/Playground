function on_tick(self, world)
    local t = world.nearest()
    self:attack(t)
end
