return function(t)
    local csv = require("src.csv")

    local recs = csv.records("id,name\n1,버그\n2,널포인터\n")
    t.eq(#recs, 2, "csv 레코드 수")
    t.eq(recs[1].id, "1", "csv 첫 행 id")
    t.eq(recs[2].name, "널포인터", "csv 한글 값")

    local q = csv.records('id,desc\n1,"쉼표, 포함"\n')
    t.eq(q[1].desc, "쉼표, 포함", "csv 따옴표 필드")

    local qq = csv.records('id,desc\n1,"안에 ""따옴표"""\n')
    t.eq(qq[1].desc, '안에 "따옴표"', "csv 이스케이프 따옴표")

    local crlf = csv.records("id,x\r\n1,a\r\n")
    t.eq(crlf[1].x, "a", "csv CRLF")

    t.eq(#csv.list(""), 0, "csv.list 빈 값")
    local l = csv.list("90;180")
    t.eq(l[1], "90", "csv.list 첫 항목")
    t.eq(l[2], "180", "csv.list 둘째 항목")

    local missing = csv.records("a,b,c\n1,2\n")
    t.eq(missing[1].c, "", "csv 모자란 셀은 빈 문자열")
end
