-- 타워는 코드로 설치합니다 (좌표는 화면의 행,열 번호)
build("printer", 7, 10, "a")
build("printer", 15, 3, "b")

-- for로 모든 적을 순회하며 조건에 맞는 타겟을 고릅니다
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
