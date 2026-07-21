-- 스테이지 1 버튼: 누르면 이 스크립트가 에디터에 자동 타이핑된 뒤 저장된다
return {
  { label = "프린터 설치 (3,10)", script = 'build("printer", 3, 10, "a")\n\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend\n' },
  { label = "프린터 추가 (11,3)", script = 'build("printer", 3, 10, "a")\nbuild("printer", 11, 3, "b")\n\nfunction on_tick(self, world)\n  self:attack(world.nearest())\nend\n' },
}
