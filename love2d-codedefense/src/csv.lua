local csv = {}

-- 문자 단위 파서: 따옴표 필드, 필드 내 쉼표/줄바꿈/이스케이프("") 지원
function csv.parse(text)
    local rows, row, field = {}, {}, {}
    local i, len, inq = 1, #text, false
    while i <= len do
        local c = text:sub(i, i)
        if inq then
            if c == '"' then
                if text:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1
                else inq = false end
            else field[#field + 1] = c end
        elseif c == '"' then inq = true
        elseif c == ',' then row[#row + 1] = table.concat(field); field = {}
        elseif c == '\n' then
            row[#row + 1] = table.concat(field); field = {}
            rows[#rows + 1] = row; row = {}
        elseif c ~= '\r' then field[#field + 1] = c end
        i = i + 1
    end
    if #field > 0 or #row > 0 then
        row[#row + 1] = table.concat(field)
        rows[#rows + 1] = row
    end
    return rows
end

-- 첫 행을 헤더로 쓰는 레코드 배열. 모자란 셀은 ""
function csv.records(text)
    local rows = csv.parse(text)
    local header = table.remove(rows, 1) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local rec = {}
        for ci, name in ipairs(header) do rec[name] = r[ci] or "" end
        out[#out + 1] = rec
    end
    return out
end

-- "90;180" → {"90","180"} / "" → {}
function csv.list(cell)
    local out = {}
    for item in tostring(cell or ""):gmatch("[^;]+") do out[#out + 1] = item end
    return out
end

function csv.load(path)
    local f = assert(io.open(path, "rb"), "CSV 파일을 열 수 없음: " .. path)
    local text = f:read("*a")
    f:close()
    return csv.records(text)
end

return csv
