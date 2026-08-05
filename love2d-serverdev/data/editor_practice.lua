return {
    lore_file = "lore/editor_practice.lua",
    documents = {
        {
            name = "README.md",
            text = "# 서버실 편집기\n\n이 작업공간은 Nano를 내장하지 않고, Nano의 단순한 편집 경험을 따라 구현했습니다.\n\nF1~F3으로 문서를 열고, Ctrl+S로 현재 문서를 저장하세요.\n",
        },
        {
            name = "deploy.lua",
            text = "-- 새벽 배포 점검\nlocal target = world.nearest()\nself:attack(target)\n",
        },
        {
            name = "notes.txt",
            text = "점검 메모\n- Ctrl+O: 다음 문서 열기\n- Ctrl+S: 현재 문서 저장\n- Ctrl+Z / Ctrl+Y: 되돌리기 / 다시 실행\n",
        },
    },
}
