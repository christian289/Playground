-- src/factions.lua — 진영(Lua/Shell) 필터·언락 순수 로직(뷰 비의존, 헤드리스 테스트 가능).
-- love API를 전혀 참조하지 않는다. states/faction.lua·states/stageselect.lua·states/play.lua·
-- states/result.lua가 이 모듈을 통해 "어느 진영 목록에 속하는가" / "그 목록 안에서 언락됐는가"를
-- 판정한다.
--
-- 배경(버그 예방): 과거 stageselect의 언락 판정은 "d.stages를 mode=="normal"로만 걸러 전역
-- id 오름차순 정렬한 리스트"에서 "리스트상 바로 이전 항목"을 봤다. Lua 진영(1~20)만 있을 때는
-- 이 리스트가 우연히 진영 경계와 일치해 정상 동작했지만, 불연속 id(예: 셸 진영 101~106)가
-- 같은 전역 리스트에 섞이면 셸 스테이지 101의 "리스트상 이전 항목"이 Lua 스테이지 20이 되어
-- 버려 20을 클리어해야 101이 열리는 잘못된 잠금이 생긴다. 이 모듈은 리스트 구성 단계에서부터
-- 진영별로 분리해 이 문제를 근본적으로 없앤다 — "진영 내 목록 이전 항목 클리어" 기준.
local factions = {}

-- stages.csv의 languages 칼럼 규칙: 빈 값은 "lua"로 취급한다(db.lua의 텍스트 필드 규칙과 동일,
-- `x ~= ""` 비교 — nil 체크가 아니다). 즉 languages 칼럼이 아예 없던 옛 세이브/데이터와도 호환.
function factions.languageOf(stage)
    local lang = stage and stage.languages
    if not lang or lang == "" then return "lua" end
    return lang
end

-- 특정 진영(faction: "lua"|"shell")에 속하는 mode=="normal" 스테이지 id를 id 오름차순으로 반환.
-- (d.stages는 해시라 순서가 없으므로 항상 정렬해서 반환 — stageselect.lua의 기존 관례와 동일.)
function factions.idsFor(stages, faction)
    local ids = {}
    for id, s in pairs(stages) do
        if s.mode == "normal" and factions.languageOf(s) == faction then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

-- ids(진영 내 오름차순 목록) 기준 언락 판정: 목록의 첫 항목은 항상 언락, 그 외는 "목록상 바로
-- 이전 항목"이 cleared[해당 id]여야 언락된다. 목록에 없는 id는 항상 잠김(false).
function factions.unlocked(ids, cleared, id)
    for i, sid in ipairs(ids) do
        if sid == id then
            if i == 1 then return true end
            return cleared and cleared[ids[i - 1]]
        end
    end
    return false
end

return factions
