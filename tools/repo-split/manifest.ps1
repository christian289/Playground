# Playground 분할의 단일 진실 공급원.
# Split-Project.ps1 / Verify-Split.ps1 / Add-Bootstrap.ps1 / Push-Repos.ps1 가 점 소싱한다.
#
# Repo   : 새 저장소 이름
# Source : $SourceRepos 의 키
# Refs   : 원본 ref -> 새 저장소 브랜치. 첫 항목이 기본 브랜치가 된다.
# Paths  : 루트로 승격시킬 원본 폴더 (뒤 슬래시 없이)
# Globs  : 경로를 유지한 채 가져올 파일 글로브
# Desc   : GitHub 저장소 설명

$WorkRoot = Join-Path $env:TEMP 'repo-split'
$Org      = 'christian289-playground'

# 소스 저장소는 전부 로컬 경로로 참조한다. 검증이 기준값을 여기서 읽기 때문에
# 원격 URL로는 안 된다. Playground 외의 소스는 Initialize-Sources 단계에서 복제한다.
$SourceRepos = @{
    Playground           = 'C:\Users\chris\personal\Playground'
    DotnetWithClaudeCode = Join-Path $WorkRoot '_sources\dotnet-with-claudecode.git'
}

# 외부 소스의 복제 원본. Initialize-Sources 단계가 읽는다.
$SourceClones = @{
    DotnetWithClaudeCode = 'https://github.com/christian289/dotnet-with-claudecode.git'
}

$Projects = @(
    @{ Repo   = 'love2d-serverdev'
       Source = 'Playground'
       Refs   = @( @{ From = 'feature/serverdev'; To = 'main' },
                   @{ From = 'main';              To = 'legacy/codedefense-0.1' } )
       Paths  = @('love2d-codedefense', 'love2d-thisfar', 'love2d-serverdev')
       Globs  = @('docs/superpowers/*/*codedefense*')
       Desc   = '서버실 개발자 — Lua 코딩 교육용 실시간 타워디펜스 (LÖVE)' }

    @{ Repo   = 'PretextWpf'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('PretextWpf')
       Globs  = @('docs/superpowers/*/*pretext*')
       Desc   = 'pretext 텍스트 레이아웃 엔진의 WPF 포팅과 Playground 데모' }

    @{ Repo   = 'PolyLab3DStudio'
       Source = 'DotnetWithClaudeCode'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('samples/PolyLab3DStudio')
       Globs  = @('docs/superpowers/*/*polylab*')
       Desc   = 'WPF Viewport3D 3D 학습 스튜디오 — 코스·용어사전·씬 편집·프로젝트 내보내기' }

    @{ Repo   = 'love2d-mario'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('love2d-mario'); Globs = @()
       Desc   = 'LÖVE 2D 플랫포머 — STI 타일맵 + anim8' }

    @{ Repo   = 'love2d-tetris'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('love2d-tetris'); Globs = @()
       Desc   = 'LÖVE 2D 테트리스' }

    @{ Repo   = 'MultiProcessTabbedBrowser'
       Source = 'Playground'
       Refs   = @( @{ From = 'claude/multi-process-tabbed-browser-BIML2'; To = 'main' } )
       Paths  = @('MultiProcessTabbedBrowser'); Globs = @()
       Desc   = 'named pipe IPC로 탭마다 프로세스를 분리한 WPF 브라우저 셸' }

    @{ Repo   = 'DotNetOAuth2Learning'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('DotNetOAuth2Learning'); Globs = @()
       Desc   = '.NET OAuth2 학습 자료 — Authorization Code / Client Credentials / JWT 검증' }

    @{ Repo   = 'WpfOnnxWinUI3Demo'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('WpfOnnxWinUI3Demo'); Globs = @()
       Desc   = 'WPF + WinUI 3 XAML Islands + ONNX Runtime 이미지 분류 데모' }

    @{ Repo   = 'WpfAutomationDemo'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('WpfAutomationDemo'); Globs = @()
       Desc   = 'WPF UI Automation — 커스텀 컨트롤에 AutomationPeer 붙이기' }

    @{ Repo   = 'WinAppCliOcr'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('WinAppCliOcr'); Globs = @()
       Desc   = 'winapp CLI로 만든 Windows OCR 앱' }

    @{ Repo   = 'MewUIPixelAnimation'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('MewUIPixelAnimation'); Globs = @()
       Desc   = 'MewUI 80x60 픽셀 그리드 스틱맨 애니메이션 (.NET 10 AOT)' }

    @{ Repo   = 'Wpf3DTutorial'
       Source = 'Playground'
       Refs   = @( @{ From = 'main'; To = 'main' } )
       Paths  = @('Wpf3DTutorial'); Globs = @()
       Desc   = 'WPF Viewport3D 튜토리얼 — 궤도 카메라, 패닝, 줌' }

    @{ Repo   = 'OldNewThingMcpServer'
       Source = 'Playground'
       Refs   = @( @{ From = 'add-old-new-thing-mcp-server'; To = 'main' } )
       Paths  = @('OldNewThingMcpServer'); Globs = @()
       Desc   = 'Microsoft DevBlogs(The Old New Thing) MCP 서버 — stdio / 원격 두 가지' }
)
