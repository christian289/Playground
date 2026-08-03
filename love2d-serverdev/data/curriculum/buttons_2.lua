-- 스테이지 2 버튼: 누르면 이 스크립트가 에디터에 자동 타이핑된 뒤 저장된다
return {
  { label = "프린터 설치 (3,3)", script = 'build("printer", 3, 3, "a")\n\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend\n' },
  { label = "프린터 추가 (7,3)", script = 'build("printer", 3, 3, "a")\nbuild("printer", 7, 3, "b")\n\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend\n' },
  { label = "전략: 약한 적 우선", script = 'build("printer", 3, 3, "a")\nbuild("printer", 7, 3, "b")\n\nfunction on_tick(self, world)\n  self:attack(world.weakest())\nend\n' },
}
