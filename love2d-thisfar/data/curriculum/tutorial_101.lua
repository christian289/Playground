-- Wave D Task 4: 셸 진영 첫 스테이지(101) 튜토리얼 — 5스텝, 전부 한글.
-- 최종 리뷰 반영: termExec()가 이제 tut:notify("exec")를 실행 성공/실패와 무관하게 호출하므로
-- (states/play.lua 확인), 명령 실행을 지시하는 스텝(②③④)은 advance={on="event", event="exec"}로
-- 전환해 실제로 명령을 실행해야 다음 스텝으로 넘어가게 한다. 설명 전용 ①과 마무리 ⑤는 Enter
-- 전진을 유지한다. ②~④는 터미널 입력(글자·편집키·이력탐색)이 필요하므로 allow에 textinput +
-- 편집/이력 키를 열어 둔다("return"은 src/tutorial.lua의 Tutorial:allows가 항상 통과시키므로
-- 별도로 나열할 필요 없음 — advance.on=="event"인 스텝에서는 keypressed()도 Enter를 소비하지
-- 않고 그대로 states/play.lua의 termExec() 라우팅으로 흘려보낸다).
local TERM_ALLOW = { "textinput", "up", "down", "left", "right", "home", "end", "backspace", "delete" }
return {
  { text = "여기는 셸 진영. 코드 대신 명령줄로 서버를 지킨다.",
    allow = {}, advance = { on = "enter" } },
  { text = "ls 를 입력하고 Enter — 내 타워 목록을 본다.",
    allow = TERM_ALLOW, advance = { on = "event", event = "exec" } },
  { text = "build printer 4 3 a 로 첫 타워를 세운다. 인자 순서: 타워 행 열 이름.",
    anchor = { type = "cell", r = 4, c = 3 }, allow = TERM_ALLOW, advance = { on = "event", event = "exec" } },
  { text = "ls enemies 로 적을 정찰한다.",
    allow = TERM_ALLOW, advance = { on = "event", event = "exec" } },
  { text = "이제 방어를 완성하라. man build 로 언제든 문서를 열 수 있다.",
    advance = { on = "enter" } },
}
