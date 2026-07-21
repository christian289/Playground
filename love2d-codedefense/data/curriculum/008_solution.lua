local function pick(world)
  local best = nil
  for _, e in ipairs(world.enemies()) do
    if e.type == "concat-nil" then
      if not best or e.hp < best.hp then best = e end
    end
  end
  return best or world.nearest()
end

function on_tick(self, world)
  self:attack(pick(world))
end
