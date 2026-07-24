-- Wave D Task 4: 셸 진영 첫 스테이지(101) 튜토리얼 — 5스텝, 전부 한글.
-- 셸 스테이지는 termExec()가 tut:notify를 호출하지 않아 이벤트 기반 진행이 배선돼 있지
-- 않다(states/play.lua 확인) — 모든 스텝을 advance={on="enter"}로 두어 안전하게 진행한다
-- (이벤트 대기로 인한 영구 정지 방지). 설명 전용인 ①만 allow={}로 입력을 잠근다.
return {
  { text = "여기는 셸 진영. 코드 대신 명령줄로 서버를 지킨다.",
    allow = {}, advance = { on = "enter" } },
  { text = "ls 를 입력하고 Enter — 내 타워 목록을 본다.",
    advance = { on = "enter" } },
  { text = "build printer 4 3 a 로 첫 타워를 세운다. 인자 순서: 타워 행 열 이름.",
    anchor = { type = "cell", r = 4, c = 3 }, advance = { on = "enter" } },
  { text = "ls enemies 로 적을 정찰한다.",
    advance = { on = "enter" } },
  { text = "이제 방어를 완성하라. man build 로 언제든 문서를 열 수 있다.",
    advance = { on = "enter" } },
}
