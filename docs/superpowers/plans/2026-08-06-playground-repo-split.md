# Playground 저장소 분할 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `christian289/Playground` 모노레포를 `christian289-playground` Organization 아래 15개 독립 저장소(filter-repo 분할 13 + 이관 2)로 재편하고, 원본은 아카이브로 보존한다.

**Architecture:** 매니페스트 하나(`tools/repo-split/manifest.ps1`)가 저장소 13개의 소스 저장소·ref·경로·설명을 선언하고, 분할·검증·푸시 스크립트가 모두 이를 읽는다. 각 저장소는 scratchpad의 독립 bare 저장소로 만들어지며, blob 단위 검증을 전부 통과하기 전에는 어떤 것도 푸시하지 않는다. 소스 저장소는 읽기만 하고 Playground만 마지막 단계에서 아카이브한다.

**Tech Stack:** PowerShell 7 (pwsh), Git 2.40+, `git-filter-repo` (pip), `gh` CLI 2.87

## Global Constraints

- 셸은 **PowerShell 7**. Bash 문법 금지 (`$env:VAR`, `Test-Path`, `-ErrorAction Stop` 사용).
- **분할이 읽는 ref는 건드리지 않는다.** 분할은 아래 ref들만 fetch 소스로 읽으며, Task 8 전까지 이 ref들에 커밋·리베이스·삭제를 하지 않는다.
  - `C:\Users\chris\personal\Playground`의 `main`, `feature/serverdev`, `claude/multi-process-tabbed-browser-BIML2`, `add-old-new-thing-mcp-server`
  - `christian289/dotnet-with-claudecode`의 `main` — **이 저장소는 끝까지 수정 금지.** `samples/PolyLab3DStudio/`를 복제 추출만 하고 원본에서 지우지 않는다
- 이 계획의 산출물(`tools/repo-split/`, 문서)은 현재 워크트리의 **`main-2` 브랜치에 커밋한다.** `main-2`는 분할 소스가 아니므로 검증에 영향을 주지 않는다. Task 8에서 `main-2`를 `origin/main`으로 푸시하면서 비로소 `main`이 갱신된다.
- 작업 루트: `$env:TEMP\repo-split` — 모든 중간 산출물은 여기에만 생성.
- Organization: `christian289-playground` (이미 생성됨, Free 플랜).
- `gh` 활성 계정은 **`christian289`** (scope: `admin:org, gist, repo, workflow`). 확인 명령: `gh auth status`.
- 새 저장소 13개는 전부 **public**.
- 커밋 메시지는 한글, 본문 끝에 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- **Task 5의 검증 표가 전부 PASS 되기 전에는 어떤 저장소도 푸시하지 않는다.**
- 설계서: `docs/superpowers/specs/2026-08-06-playground-repo-split-design.md`

## File Structure

`tools/repo-split/` (Playground 저장소, `main-2` 브랜치에 커밋). 어느 분할 글로브에도 매칭되지 않으므로 아카이브된 Playground에만 남는다 — 이 마이그레이션이 어떻게 수행됐는지의 기록이다.

| 파일 | 책임 |
|---|---|
| `manifest.ps1` | 저장소 13개의 이름·소스 저장소·ref·경로·글로브·설명 선언. 유일한 진실 공급원 |
| `Initialize-Sources.ps1` | 로컬에 없는 소스 저장소를 bare 복제 |
| `Split-Project.ps1` | 매니페스트 1개 항목을 bare 저장소로 분할 |
| `Verify-Split.ps1` | 분할 결과를 원본과 blob 단위 대조, 표 출력 |
| `Add-Bootstrap.ps1` | `bootstrap/<repo>/` 내용을 분할 저장소에 얹고 커밋 |
| `Push-Repos.ps1` | 조직에 저장소 생성 + 전체 브랜치 푸시 |
| `bootstrap/_shared/gitignore-love2d` | LÖVE 프로젝트용 .gitignore |
| `bootstrap/<repo>/…` | 저장소별로 얹을 파일 (README.md, .gitignore, CLAUDE.md) |

---

### Task 1: 갈래 B — 저장소 이관 2개

이관을 먼저 하는 이유는 API 호출 두 번으로 **조직 저장소 생성 권한을 위험 없이 검증**하기 위해서다. 여기서 막히면 13개를 다 만들어 놓고 푸시 단계에서 실패하는 상황을 피할 수 있다.

**Files:**
- 없음 (API 작업만)

**Interfaces:**
- Consumes: 없음
- Produces: `christian289-playground/wonderland`, `christian289-playground/MewUiBadApple` — 이후 Task 8의 README 색인에서 참조

- [ ] **Step 1: 사전 상태 확인 — 이관 전 위치와 활성 계정**

```powershell
gh auth status
gh repo view christian289/wonderland --json nameWithOwner,visibility
gh repo view christian289/MewUiBadApple --json nameWithOwner,visibility
```

Expected: 활성 계정 `christian289`, scope에 `admin:org` 포함, 두 저장소 모두 `christian289/…` 소유, `PUBLIC`.

- [ ] **Step 2: wonderland 이관**

```powershell
gh api -X POST repos/christian289/wonderland/transfer -f new_owner=christian289-playground
```

Expected: 202 Accepted. 응답 JSON의 `full_name`은 아직 옛 이름일 수 있다(비동기 처리).

- [ ] **Step 3: 이관 결과 확인**

```powershell
gh repo view christian289-playground/wonderland --json nameWithOwner,visibility,defaultBranchRef
```

Expected: `{"nameWithOwner":"christian289-playground/wonderland", ...}`.
실패(404)하면 몇 초 후 재시도. 그래도 실패하면 **여기서 멈추고 권한을 점검한다** — 이후 단계가 전부 같은 권한에 의존한다.

- [ ] **Step 4: MewUiBadApple 이관 및 확인**

```powershell
gh api -X POST repos/christian289/MewUiBadApple/transfer -f new_owner=christian289-playground
gh repo view christian289-playground/MewUiBadApple --json nameWithOwner,visibility
```

Expected: `christian289-playground/MewUiBadApple`, `PUBLIC`.

- [ ] **Step 5: 리다이렉트 동작 확인**

```powershell
gh repo view christian289/wonderland --json nameWithOwner
```

Expected: `christian289-playground/wonderland` — 옛 경로가 새 위치로 리다이렉트된다. 기존 클론의 `git fetch`가 계속 동작함을 뜻한다.

커밋할 파일이 없으므로 이 태스크는 커밋하지 않는다.

---

### Task 2: 도구 설치와 매니페스트

**Files:**
- Create: `tools/repo-split/manifest.ps1`

**Interfaces:**
- Consumes: 없음
- Produces: 점 소싱(`. .\manifest.ps1`) 시 다음 변수 — `$WorkRoot` (string), `$Org` (string), `$SourceRepos` (hashtable: 키 이름 → 로컬 경로), `$Projects` (hashtable 배열; 키: `Repo` string, `Source` string = `$SourceRepos`의 키, `Refs` hashtable 배열 with `From`/`To`, `Paths` string 배열, `Globs` string 배열, `Desc` string)

- [ ] **Step 1: git-filter-repo 설치**

```powershell
pip install git-filter-repo
```

- [ ] **Step 2: 설치 검증**

```powershell
git filter-repo --version
```

Expected: 버전 문자열 출력 (예: `2.47.0`).

`git: 'filter-repo' is not a git command` 가 나오면 pip Scripts 디렉터리가 PATH에 없는 것이다. 다음으로 위치를 찾아 PATH에 추가한다:

```powershell
$scripts = Join-Path (Split-Path (Get-Command python).Source) 'Scripts'
$env:PATH = "$scripts;$env:PATH"
git filter-repo --version
```

- [ ] **Step 3: 매니페스트 작성**

Create `tools/repo-split/manifest.ps1`:

```powershell
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
```

- [ ] **Step 4: 외부 소스 복제 스크립트 작성**

`PolyLab3DStudio`의 소스인 `dotnet-with-claudecode`는 로컬에 없다. 검증이 기준값을
로컬에서 읽어야 하므로 bare 복제를 만들어 둔다.

Create `tools/repo-split/Initialize-Sources.ps1`:

```powershell
<#
.SYNOPSIS
로컬에 없는 소스 저장소를 bare 복제한다.

이미 있으면 fetch로 갱신만 한다. 소스 저장소는 읽기 전용이므로 절대 푸시하지 않는다.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\manifest.ps1"

foreach ($key in $SourceClones.Keys) {
    $path = $SourceRepos[$key]
    $url  = $SourceClones[$key]

    if (Test-Path $path) {
        # --bare 복제는 remote.origin.fetch 를 설정하지 않으므로 URL과 refspec을 직접 준다.
        Write-Host "갱신: $key" -ForegroundColor DarkGray
        git -C $path fetch --prune $url '+refs/heads/*:refs/heads/*'
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
        git clone --bare $url $path
    }
    if ($LASTEXITCODE -ne 0) { throw "소스 준비 실패: $key" }
    Write-Host ("OK  {0,-22} {1} branches" -f $key, (git -C $path for-each-ref --format='%(refname)' refs/heads).Count)
}

# Playground 는 로컬 원본이므로 복제하지 않고 존재만 확인한다.
if (-not (Test-Path $SourceRepos.Playground)) { throw "원본 저장소가 없습니다: $($SourceRepos.Playground)" }
Write-Host "OK  Playground             (로컬 원본)" -ForegroundColor Green
```

- [ ] **Step 5: 소스 준비 실행**

```powershell
.\tools\repo-split\Initialize-Sources.ps1
git -C "$env:TEMP\repo-split\_sources\dotnet-with-claudecode.git" ls-tree --name-only main -- samples/PolyLab3DStudio/
```

Expected: `OK  DotnetWithClaudeCode   2 branches`, `OK  Playground (로컬 원본)`, 그리고
`samples/PolyLab3DStudio/Directory.Packages.props`, `…/PolyLab3DStudio.slnx`, `…/README.md`, `…/src`.

- [ ] **Step 6: 매니페스트 로드 검증**

```powershell
. .\tools\repo-split\manifest.ps1
$Projects.Count
$Projects | ForEach-Object { "{0,-26} {1,-20} {2,-2} ref  {3,-2} path  {4,-2} glob" -f $_.Repo, $_.Source, $_.Refs.Count, $_.Paths.Count, $_.Globs.Count }
$bad = $Projects | Where-Object { -not $SourceRepos.ContainsKey($_.Source) }
if ($bad) { throw "알 수 없는 Source: $($bad.Repo -join ', ')" } else { 'Source 키 전부 유효' }
```

Expected: `13`. `love2d-serverdev`가 `Playground / 2 ref / 3 path / 1 glob`,
`PretextWpf`가 `Playground / 1 ref / 1 path / 1 glob`,
`PolyLab3DStudio`가 `DotnetWithClaudeCode / 1 ref / 1 path / 1 glob`,
나머지 10개가 `Playground / 1 ref / 1 path / 0 glob`. 마지막 줄 `Source 키 전부 유효`.

- [ ] **Step 7: 커밋**

```powershell
git add tools/repo-split/manifest.ps1 tools/repo-split/Initialize-Sources.ps1
git commit -m @'
tools: 저장소 분할 매니페스트와 소스 준비 스크립트 추가

13개 분할 대상의 소스 저장소·ref·경로·글로브·설명을 한 곳에 선언한다.
분할·검증·부트스트랩·푸시 스크립트가 모두 이 파일을 점 소싱한다.
PolyLab3DStudio는 dotnet-with-claudecode에서 나오므로 소스 저장소가 둘이다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### Task 3: 검증 스크립트

검증이 이 작업의 테스트다. 분할기보다 **먼저** 작성해서, 아직 아무것도 분할하지 않은 상태에서 제대로 실패하는지 확인한다.

**Files:**
- Create: `tools/repo-split/Verify-Split.ps1`

**Interfaces:**
- Consumes: `manifest.ps1`의 `$SourceRepos`, `$WorkRoot`, `$Projects`
- Produces: `Verify-Split.ps1` — `-Repo <name>`으로 하나만, 생략 시 전체 검증. 표를 출력하고 실패가 하나라도 있으면 종료 코드 1

- [ ] **Step 1: 검증 스크립트 작성**

Create `tools/repo-split/Verify-Split.ps1`:

```powershell
<#
.SYNOPSIS
분할 결과를 원본과 대조한다.

검사 A (필수): 트리 blob 동일성. 원본의 해당 경로 집합과 새 저장소의 트리가
               경로·모드·blob SHA까지 완전히 일치해야 한다.
검사 B (필수): 원본에서 해당 경로를 건드린 커밋이 전부 새 저장소에 존재해야 한다.
               (저자, 저자일시, 제목) 3튜플의 집합으로 비교한다.
검사 C (참고): 새 저장소에만 있는 커밋 수. 병합 커밋 단순화 방식의 차이로
               0이 아닐 수 있어 보고만 하고 실패로 처리하지 않는다.

검사 A가 권위 있는 검사다. 파일 한 바이트가 달라져도 blob SHA가 달라진다.
#>
[CmdletBinding()]
param([string]$Repo)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\manifest.ps1"

function Get-TreeMap {
    param([string]$RepoPath, [string]$Ref)
    $map = @{}
    $lines = git -C $RepoPath -c core.quotePath=false ls-tree -r $Ref
    foreach ($l in $lines) {
        if ($l -match '^(\d{6}) \w+ ([0-9a-f]{40})\t(.+)$') {
            $map[$Matches[3]] = "$($Matches[1]) $($Matches[2])"
        }
    }
    return $map
}

function Get-CommitSet {
    param([string]$RepoPath, [string]$Ref, [string[]]$Pathspec)
    $fmt = '%an%x1f%ad%x1f%s'
    if ($Pathspec) {
        return @(git -C $RepoPath -c core.quotePath=false log --format=$fmt --date=iso-strict $Ref -- @Pathspec)
    }
    return @(git -C $RepoPath -c core.quotePath=false log --format=$fmt --date=iso-strict $Ref)
}

$targets = if ($Repo) { $Projects | Where-Object { $_.Repo -eq $Repo } } else { $Projects }
if (-not $targets) { throw "매니페스트에 '$Repo' 가 없습니다." }

$rows = @()
foreach ($proj in $targets) {
    $dest = Join-Path $WorkRoot "$($proj.Repo).git"
    $srcRepo = $SourceRepos[$proj.Source]
    if (-not $srcRepo) { throw "$($proj.Repo): 알 수 없는 Source '$($proj.Source)'" }
    if (-not (Test-Path $srcRepo)) { throw "$($proj.Repo): 소스 저장소 없음 — Initialize-Sources.ps1 를 먼저 실행하세요: $srcRepo" }

    foreach ($r in $proj.Refs) {
        $label = if ($proj.Refs.Count -gt 1) { "$($proj.Repo) [$($r.To)]" } else { $proj.Repo }

        if (-not (Test-Path $dest)) {
            $rows += [pscustomobject]@{ Repo=$label; Files='-'; Tree='MISSING'; Commits='-'; Missing='-'; Extra='-'; Verdict='FAIL' }
            continue
        }

        # --- 기대값: 원본에서 이 프로젝트에 속하는 경로만 추려 접두사 제거 ---
        $srcAll   = Get-TreeMap $srcRepo $r.From
        $expected = @{}
        foreach ($p in $proj.Paths) {
            foreach ($k in $srcAll.Keys) {
                if ($k.StartsWith("$p/")) { $expected[$k.Substring($p.Length + 1)] = $srcAll[$k] }
            }
        }
        foreach ($g in $proj.Globs) {
            foreach ($k in $srcAll.Keys) {
                if ($k -like $g) { $expected[$k] = $srcAll[$k] }   # 글로브 파일은 경로 유지
            }
        }

        # --- 실제값 ---
        $actual = Get-TreeMap $dest $r.To

        $missingFiles = @($expected.Keys | Where-Object { -not $actual.ContainsKey($_) })
        $extraFiles   = @($actual.Keys   | Where-Object { -not $expected.ContainsKey($_) })
        $diffFiles    = @($expected.Keys | Where-Object { $actual.ContainsKey($_) -and $actual[$_] -ne $expected[$_] })
        $treeOk       = ($missingFiles.Count + $extraFiles.Count + $diffFiles.Count) -eq 0

        # --- 커밋 ---
        $srcCommits = Get-CommitSet $srcRepo $r.From @($proj.Paths + $proj.Globs)
        $dstCommits = Get-CommitSet $dest $r.To $null
        $dstLookup  = @{}; foreach ($c in $dstCommits) { $dstLookup[$c] = $true }
        $srcLookup  = @{}; foreach ($c in $srcCommits) { $srcLookup[$c] = $true }
        $missingCommits = @($srcCommits | Where-Object { -not $dstLookup.ContainsKey($_) })
        $extraCommits   = @($dstCommits | Where-Object { -not $srcLookup.ContainsKey($_) })

        $verdict = if ($treeOk -and $missingCommits.Count -eq 0) { 'PASS' } else { 'FAIL' }

        $rows += [pscustomobject]@{
            Repo    = $label
            Files   = "$($actual.Count)/$($expected.Count)"
            Tree    = if ($treeOk) { 'OK' } else { "-$($missingFiles.Count) +$($extraFiles.Count) ~$($diffFiles.Count)" }
            Commits = "$($dstCommits.Count)/$($srcCommits.Count)"
            Missing = $missingCommits.Count
            Extra   = $extraCommits.Count
            Verdict = $verdict
        }

        if (-not $treeOk) {
            Write-Warning "[$label] 파일 불일치 — 누락 $($missingFiles.Count) / 초과 $($extraFiles.Count) / 내용다름 $($diffFiles.Count)"
            $missingFiles | Select-Object -First 10 | ForEach-Object { Write-Warning "  누락: $_" }
            $extraFiles   | Select-Object -First 10 | ForEach-Object { Write-Warning "  초과: $_" }
            $diffFiles    | Select-Object -First 10 | ForEach-Object { Write-Warning "  다름: $_" }
        }
        if ($missingCommits.Count -gt 0) {
            Write-Warning "[$label] 커밋 누락 $($missingCommits.Count)건"
            $missingCommits | Select-Object -First 5 | ForEach-Object { Write-Warning "  $($_ -replace [char]31, ' | ')" }
        }
    }
}

$rows | Format-Table -AutoSize
$failed = @($rows | Where-Object { $_.Verdict -eq 'FAIL' })
if ($failed.Count -gt 0) {
    Write-Host "`n$($failed.Count)건 FAIL — 푸시하지 말 것." -ForegroundColor Red
    exit 1
}
Write-Host "`n전부 PASS ($($rows.Count)건)." -ForegroundColor Green
```

- [ ] **Step 2: 아무것도 분할하지 않은 상태에서 실행 — 제대로 실패하는지 확인**

```powershell
.\tools\repo-split\Verify-Split.ps1
```

Expected: 14행 전부 `Tree=MISSING`, `Verdict=FAIL`, 종료 코드 1.
(13개 저장소 중 `love2d-serverdev`가 ref 2개라 14행이다.)

검증기가 아무것도 없는 상태를 PASS로 보고하면 검증기 자체가 고장난 것이다. 여기서 반드시 FAIL이 나와야 한다.

- [ ] **Step 3: 커밋**

```powershell
git add tools/repo-split/Verify-Split.ps1
git commit -m @'
tools: 분할 결과 검증 스크립트 추가

원본과 blob SHA 단위로 트리를 대조하고, 원본에서 해당 경로를 건드린
커밋이 전부 새 저장소에 있는지 확인한다. 하나라도 실패하면 종료 코드 1.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### Task 4: 분할 스크립트 + 최소 사례 통과

**Files:**
- Create: `tools/repo-split/Split-Project.ps1`

**Interfaces:**
- Consumes: `manifest.ps1`의 `$SourceRepos`, `$WorkRoot`, `$Projects`; `Initialize-Sources.ps1`이 준비한 소스 저장소
- Produces: `Split-Project.ps1 -Repo <name>` → `$WorkRoot\<name>.git` 에 bare 저장소 생성. 기존 디렉터리가 있으면 삭제 후 재생성(멱등)

- [ ] **Step 1: 분할 스크립트 작성**

Create `tools/repo-split/Split-Project.ps1`:

```powershell
<#
.SYNOPSIS
매니페스트 1개 항목을 독립 bare 저장소로 분할한다.

소스 저장소는 fetch 소스로만 읽는다. 대상 디렉터리가 이미 있으면 지우고 다시 만들므로
몇 번을 돌려도 같은 결과가 나온다.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Repo)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\manifest.ps1"

$proj = $Projects | Where-Object { $_.Repo -eq $Repo }
if (-not $proj) { throw "매니페스트에 '$Repo' 가 없습니다." }

$srcRepo = $SourceRepos[$proj.Source]
if (-not $srcRepo) { throw "$Repo : 알 수 없는 Source '$($proj.Source)'" }
if (-not (Test-Path $srcRepo)) { throw "$Repo : 소스 저장소 없음 — Initialize-Sources.ps1 를 먼저 실행하세요: $srcRepo" }

$dest = Join-Path $WorkRoot "$Repo.git"
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

git init --bare --initial-branch=main $dest | Out-Null
if ($LASTEXITCODE -ne 0) { throw "git init 실패: $dest" }

# 필요한 ref만 정확히 가져온다. 태그는 두 소스 모두 쓰지 않으므로 --no-tags.
foreach ($r in $proj.Refs) {
    git -C $dest fetch --no-tags $srcRepo "$($r.From):refs/heads/$($r.To)"
    if ($LASTEXITCODE -ne 0) { throw "fetch 실패: $($r.From) -> $($r.To)" }
}

# 첫 ref가 기본 브랜치
git -C $dest symbolic-ref HEAD "refs/heads/$($proj.Refs[0].To)"

# 폴더는 루트로 승격, 글로브 파일은 경로 유지
$frArgs = @('--force')
foreach ($p in $proj.Paths) { $frArgs += @('--path', "$p/", '--path-rename', "${p}/:") }
foreach ($g in $proj.Globs) { $frArgs += @('--path-glob', $g) }

Write-Host "filter-repo $($frArgs -join ' ')" -ForegroundColor DarkGray
git -C $dest filter-repo @frArgs
if ($LASTEXITCODE -ne 0) { throw "filter-repo 실패: $Repo" }

foreach ($r in $proj.Refs) {
    $n = git -C $dest rev-list --count $r.To
    Write-Host ("  {0,-26} {1,4} commits" -f $r.To, $n)
}
Write-Host "OK  $Repo -> $dest" -ForegroundColor Green
```

- [ ] **Step 2: 가장 단순한 사례로 실행 — Wpf3DTutorial (1커밋, 1경로, 글로브 없음)**

```powershell
.\tools\repo-split\Split-Project.ps1 -Repo Wpf3DTutorial
```

Expected: `main  1 commits`, `OK  Wpf3DTutorial -> …\repo-split\Wpf3DTutorial.git`

- [ ] **Step 3: 검증 실행 — 통과하는지 확인**

```powershell
.\tools\repo-split\Verify-Split.ps1 -Repo Wpf3DTutorial
```

Expected:

```
Repo          Files Tree Commits Missing Extra Verdict
----          ----- ---- ------- ------- ----- -------
Wpf3DTutorial 6/6   OK   1/1     0       0     PASS
```

- [ ] **Step 4: 루트 승격이 실제로 됐는지 눈으로 확인**

```powershell
git -C "$env:TEMP\repo-split\Wpf3DTutorial.git" ls-tree -r --name-only main
```

Expected: `Wpf3DTutorial/` 접두사 없이 `Wpf3DTutorial.slnx`, `src/Wpf3DTutorial/App.xaml` 등이 나온다.

- [ ] **Step 5: 가장 복잡한 사례로 실행 — love2d-serverdev (2 ref, 3경로, 글로브 1개)**

```powershell
.\tools\repo-split\Split-Project.ps1 -Repo love2d-serverdev
.\tools\repo-split\Verify-Split.ps1 -Repo love2d-serverdev
```

Expected: `main 125 commits`, `legacy/codedefense-0.1 24 commits`, 두 행 모두 `PASS`.

- [ ] **Step 6: 개명 계보가 이어졌는지 확인**

```powershell
git -C "$env:TEMP\repo-split\love2d-serverdev.git" log --oneline --follow -- README.md | Measure-Object -Line
git -C "$env:TEMP\repo-split\love2d-serverdev.git" log --format='%ad %s' --date=short main | Select-Object -First 3
git -C "$env:TEMP\repo-split\love2d-serverdev.git" log --format='%ad %s' --date=short main | Select-Object -Last 3
```

Expected: 가장 오래된 커밋이 `2026-07-21 codedefense: 스캐폴딩과 부팅 화면` 계열, 가장 최근이 `2026-08-05 serverdev: 에디터 연습 모드…`. 즉 개명 두 번을 관통한 연속 히스토리다.

- [ ] **Step 7: 외부 소스 사례로 실행 — PolyLab3DStudio**

소스 저장소가 Playground가 아닌 유일한 항목이고, 승격할 경로가 2단계
(`samples/PolyLab3DStudio/`)라 접두사 제거가 제대로 되는지 확인이 필요하다.

```powershell
.\tools\repo-split\Split-Project.ps1 -Repo PolyLab3DStudio
.\tools\repo-split\Verify-Split.ps1 -Repo PolyLab3DStudio
git -C "$env:TEMP\repo-split\PolyLab3DStudio.git" ls-tree --name-only main
```

Expected: `main 12 commits`, `Files 106/106`(코드 104 + docs 2), `Verdict=PASS`.
마지막 명령의 출력은 `samples/` 없이 `Directory.Packages.props`, `PolyLab3DStudio.slnx`,
`README.md`, `docs`, `src` — 즉 폴더가 루트로 올라왔고 docs는 경로를 유지했다.

- [ ] **Step 8: 커밋**

```powershell
git add tools/repo-split/Split-Project.ps1
git commit -m @'
tools: 프로젝트 분할 스크립트 추가

빈 bare 저장소에 필요한 ref만 fetch한 뒤 filter-repo로 폴더를 루트로
승격시킨다. 소스 저장소는 fetch 소스로만 읽으며, 대상은 매번 재생성하므로 멱등하다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### Task 5: 전체 13개 분할 + 검증 (필수 정지점)

**Files:**
- 없음 (기존 스크립트 실행만)

**Interfaces:**
- Consumes: `Split-Project.ps1`, `Verify-Split.ps1`
- Produces: `$WorkRoot` 아래 bare 저장소 13개 — Task 6이 이를 수정한다

- [ ] **Step 1: 13개 전부 분할**

```powershell
. .\tools\repo-split\manifest.ps1
foreach ($p in $Projects) { .\tools\repo-split\Split-Project.ps1 -Repo $p.Repo }
```

Expected: 13개 전부 `OK`. 하나라도 예외가 나면 해당 저장소만 다시 돌린다.

- [ ] **Step 2: 전체 검증**

```powershell
.\tools\repo-split\Verify-Split.ps1
```

Expected: 14행 전부 `Verdict=PASS`, 마지막 줄 `전부 PASS (14건).`, 종료 코드 0.

기준값(검사 A의 `Files` 열 분모, 검사 B의 `Commits` 열 분모):

| Repo | Commits |
|---|---|
| love2d-serverdev [main] | 125 |
| love2d-serverdev [legacy/codedefense-0.1] | 24 |
| PretextWpf | 14 |
| PolyLab3DStudio | 12 |
| love2d-mario | 3 |
| love2d-tetris | 3 |
| MultiProcessTabbedBrowser | 3 |
| DotNetOAuth2Learning / WpfOnnxWinUI3Demo / WpfAutomationDemo / WinAppCliOcr / MewUIPixelAnimation / Wpf3DTutorial / OldNewThingMcpServer | 각 1 |

- [ ] **Step 3: docs 배분 확인**

```powershell
(git -C "$env:TEMP\repo-split\love2d-serverdev.git" ls-tree -r --name-only main -- docs).Count
(git -C "$env:TEMP\repo-split\PretextWpf.git" ls-tree -r --name-only main -- docs).Count
(git -C "$env:TEMP\repo-split\PolyLab3DStudio.git" ls-tree -r --name-only main -- docs).Count
```

Expected: `16`, `3`, `2`. 앞의 둘은 Playground docs 19개를 남김없이 나눠 가진 것이고,
`2`는 `dotnet-with-claudecode`에서 가져온 polylab 문서다. 나머지 10개 저장소에는 `docs/`가 없어야 한다.

- [ ] **Step 4: 나머지 10개에 docs가 섞이지 않았는지 확인**

```powershell
. .\tools\repo-split\manifest.ps1
foreach ($p in $Projects | Where-Object { $_.Globs.Count -eq 0 }) {
    $n = (git -C (Join-Path $WorkRoot "$($p.Repo).git") ls-tree -r --name-only $p.Refs[0].To -- docs).Count
    "{0,-26} docs: {1}" -f $p.Repo, $n
}
```

Expected: 10개 전부 `docs: 0`.

- [ ] **Step 5: 사용자에게 검증 표 제시하고 승인 대기**

Step 2의 표 전체와 Step 3~4의 결과를 사용자에게 보고한다.
**사용자가 명시적으로 승인하기 전에는 Task 6으로 넘어가지 않는다.**
이것이 이 계획의 유일한 필수 정지점이다.

커밋할 파일이 없으므로 이 태스크는 커밋하지 않는다.

---

### Task 6: 부트스트랩 파일과 커밋

각 분할 저장소 히스토리 **맨 위**에 커밋 1개를 얹는다. 기존 커밋은 손대지 않는다.

**Files:**
- Create: `tools/repo-split/Add-Bootstrap.ps1`
- Create: `tools/repo-split/bootstrap/_shared/gitignore-love2d`
- Create: `tools/repo-split/bootstrap/<repo>/…` (아래 Step 2~7에서 열거)

**Interfaces:**
- Consumes: `manifest.ps1`, Task 5의 bare 저장소들
- Produces: `Add-Bootstrap.ps1 -Repo <name>` → 해당 저장소 기본 브랜치에 부트스트랩 커밋 1개 추가

- [ ] **Step 1: 공용 .gitignore 두 개 준비**

.NET용은 원본 루트 것을 그대로 쓴다:

```powershell
New-Item -ItemType Directory -Force -Path .\tools\repo-split\bootstrap\_shared | Out-Null
git show main:.gitignore | Set-Content -Encoding utf8 .\tools\repo-split\bootstrap\_shared\gitignore-dotnet
```

Create `tools/repo-split/bootstrap/_shared/gitignore-love2d`:

```gitignore
# LÖVE 빌드 산출물
*.love
build/
dist/

# Lua
luac.out
*.luac

# 에디터
.vscode/*
!.vscode/settings.json
!.vscode/launch.json
!.vscode/extensions.json
.idea/

# OS
.DS_Store
Thumbs.db

# Claude Code 사용자별 설정 (프로젝트 공유 settings.json은 커밋한다)
.claude/settings.local.json
```

- [ ] **Step 2: .gitignore가 없는 저장소에 배치**

이미 `.gitignore`를 가진 저장소는 `PretextWpf`, `WinAppCliOcr` 둘뿐이므로 나머지 11개에 배치한다.

```powershell
$dotnet = @('DotNetOAuth2Learning','WpfOnnxWinUI3Demo','WpfAutomationDemo','MewUIPixelAnimation',
            'Wpf3DTutorial','OldNewThingMcpServer','MultiProcessTabbedBrowser','PolyLab3DStudio')
$love2d = @('love2d-serverdev','love2d-mario','love2d-tetris')
foreach ($r in $dotnet) {
    New-Item -ItemType Directory -Force -Path ".\tools\repo-split\bootstrap\$r" | Out-Null
    Copy-Item .\tools\repo-split\bootstrap\_shared\gitignore-dotnet ".\tools\repo-split\bootstrap\$r\.gitignore"
}
foreach ($r in $love2d) {
    New-Item -ItemType Directory -Force -Path ".\tools\repo-split\bootstrap\$r" | Out-Null
    Copy-Item .\tools\repo-split\bootstrap\_shared\gitignore-love2d ".\tools\repo-split\bootstrap\$r\.gitignore"
}
```

- [ ] **Step 3: README가 없는 5개 저장소의 README 작성**

Create `tools/repo-split/bootstrap/MewUIPixelAnimation/README.md`:

```markdown
# MewUIPixelAnimation

터미널 UI 라이브러리 [MewUI](https://www.nuget.org/packages/Aprillz.MewUI)로
80×60 픽셀 그리드(Label 4,800개)를 그려 스틱맨 걷기 애니메이션을 재생하는 데모.
프레임률과 렌더 시간을 화면에 함께 표시해 MewUI의 대량 위젯 갱신 성능을 눈으로 확인한다.

## 요구 사항

- .NET 10 SDK
- Windows 터미널 (24비트 컬러 지원 권장)

## 실행

```
dotnet run --project MewUIPixelAnimation.csproj
```

## 구성

| 파일 | 역할 |
|---|---|
| `Program.cs` | 애니메이션 루프, 성능 측정 |
| `PixelGrid.cs` | 80×60 Label 그리드 |
| `StickmanFrames.cs` | 스틱맨 스프라이트 프레임 데이터 |

`PublishAot` + `TrimMode=full`로 설정되어 있어 `dotnet publish`로 단일 네이티브 실행 파일을 만들 수 있다.
```

Create `tools/repo-split/bootstrap/Wpf3DTutorial/README.md`:

```markdown
# Wpf3DTutorial

WPF `Viewport3D`로 3D 씬을 구성하고 마우스로 조작하는 튜토리얼 앱.

## 조작

| 입력 | 동작 |
|---|---|
| 좌클릭 드래그 | 궤도 회전 |
| 우클릭 드래그 | 패닝 |
| 휠 | 확대/축소 |
| 「자동 회전」 토글 | 카메라 자동 회전 |

## 요구 사항

- .NET 10 SDK (`net10.0-windows`)
- Windows

## 실행

```
dotnet run --project src/Wpf3DTutorial/Wpf3DTutorial.csproj
```

## 다루는 내용

`PerspectiveCamera` 배치, `MeshGeometry3D` 구성, 조명 설정, 마우스 입력을 카메라
변환으로 옮기는 방법.
```

Create `tools/repo-split/bootstrap/WpfAutomationDemo/README.md`:

```markdown
# WpfAutomationDemo

WPF 커스텀 컨트롤에 UI Automation을 붙이는 방법을 보여주는 데모.
별점 컨트롤(`RatingControl`)에 `AutomationPeer`를 구현해, 스크린 리더와
UI 자동화 테스트 도구가 값을 읽고 바꿀 수 있게 한다.

## 요구 사항

- .NET 10 SDK
- Windows

## 실행

```
dotnet run --project src/WpfAutomationDemo/WpfAutomationDemo.csproj
```

## 구성

| 파일 | 역할 |
|---|---|
| `Controls/RatingControl.cs` | 별점 컨트롤. `Value` 의존 속성 |
| `Controls/RatingControlAutomationPeer.cs` | `IRangeValueProvider` 노출 |
| `Themes/Generic.xaml` | 기본 스타일 |

`WpfApp1/`은 초기 스캐폴딩 잔재이며 `src/WpfAutomationDemo/`가 실제 데모다.

## 확인 방법

앱 실행 후 Windows SDK의 **Accessibility Insights** 또는 **Inspect.exe**로
별점 컨트롤을 선택하면 `RangeValue` 패턴이 노출되는 것을 볼 수 있다.
```

Create `tools/repo-split/bootstrap/OldNewThingMcpServer/README.md`:

```markdown
# OldNewThingMcpServer

Microsoft DevBlogs(대표적으로 Raymond Chen의 *The Old New Thing*) 피드를
MCP 도구로 노출하는 서버. 같은 기능을 두 가지 호스팅 방식으로 구현했다.

| 프로젝트 | 방식 | 용도 |
|---|---|---|
| `MicrosoftDevBlogsMcpServer` | stdio | Claude Code 등 로컬 MCP 클라이언트 |
| `MicrosoftDevBlogsRemoteMcpServer` | HTTP | 원격 호스팅 |

> 저장소 이름은 `OldNewThingMcpServer`지만 내부 프로젝트명은
> `MicrosoftDevBlogsMcpServer`다. 대상 블로그가 The Old New Thing 하나에서
> DevBlogs 전반으로 넓어지면서 생긴 차이다.

## 요구 사항

- .NET 10 SDK

## 실행

```
dotnet run --project MicrosoftDevBlogsMcpServer/MicrosoftDevBlogsMcpServer.csproj
```

MCP 등록 정보는 `MicrosoftDevBlogsMcpServer/.mcp/server.json`에 있다.
각 프로젝트 폴더의 README에 도구 목록과 상세 사용법이 있다.
```

Create `tools/repo-split/bootstrap/PretextWpf/README.md`:

```markdown
# PretextWpf

[pretext](https://github.com/chenglou/pretext)(TypeScript 텍스트 레이아웃 엔진)를
WPF로 포팅한 라이브러리와, 그 위에 올린 데모 앱.

## 구성

| 프로젝트 | 역할 |
|---|---|
| `src/Pretext.Wpf` | 레이아웃 엔진 본체. 유니코드 분석·워드 세그먼트·bidi·측정·줄바꿈 |
| `src/Pretext.Wpf.Demo` | pretext.cool의 Pretext Playground를 WPF로 재현한 데모 |
| `tests/Pretext.Wpf.Tests` | 단위 테스트 + 상류 엔진과의 차분(parity) 테스트 |
| `benchmarks/Pretext.Wpf.Benchmarks` | 레이아웃 벤치마크 |
| `tools/parity` | 상류 엔진을 결정적 fake canvas 위에서 돌려 기대값 코퍼스를 생성 |

## 요구 사항

- .NET 10 SDK
- Windows (WPF 텍스트 측정 API에 의존)

## 빌드와 테스트

```
dotnet build PretextWpf.slnx
dotnet test tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj
```

## 출처와 라이선스

이식·참조한 상류 코드의 커밋 해시와 파일별 대응은 `upstream-manifest.json`에
기록되어 있다. 상류 라이선스 전문은 `LICENSE-PRETEXT`(chenglou/pretext)와
`LICENSE-WPF-SAMPLES`(microsoft/WPF-Samples)에 있다.

데모 앱이 재현한 Pretext Playground는 0xNyk의 커뮤니티 쇼케이스다.
원본 저장소가 비공개로 전환되어 배포된 번들을 캡처해 참조했으며,
경위는 `upstream-manifest.json`의 두 번째 소스 항목에 적혀 있다.
```

- [ ] **Step 4: PretextWpf 상류 라이선스 파일 확보**

`upstream-manifest.json`은 `LICENSE-PRETEXT`와 `LICENSE-WPF-SAMPLES`를 산출물로
선언하지만 두 파일이 저장소에 없다. 모노레포 안에 있을 때보다 독립 public 저장소가
되면 문제가 커지므로(타인의 MIT 코드를 고지 없이 배포) 여기서 채운다.

```powershell
$bs = '.\tools\repo-split\bootstrap\PretextWpf'
New-Item -ItemType Directory -Force -Path $bs | Out-Null
$c = 'ac49b09b7d83ede19581fa94a8b892b07d309baf'
Invoke-WebRequest "https://raw.githubusercontent.com/chenglou/pretext/$c/LICENSE" -OutFile "$bs\LICENSE-PRETEXT"
$w = '71759b6e713098672a99333c8df4358f162e48db'
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/WPF-Samples/$w/LICENSE" -OutFile "$bs\LICENSE-WPF-SAMPLES"
Get-Content "$bs\LICENSE-PRETEXT" -TotalCount 3
Get-Content "$bs\LICENSE-WPF-SAMPLES" -TotalCount 3
```

Expected: 두 파일 모두 MIT 라이선스 문구로 시작.

`upstream-manifest.json`에 기록된 sha256과 대조한다:

```powershell
(Get-FileHash "$bs\LICENSE-PRETEXT" -Algorithm SHA256).Hash.ToLower()
# 기대: 688be63d8f7b85a4135d2c291a78981bcaad7bf1db8d65a1a19c8fdd43f8ad84
(Get-FileHash "$bs\LICENSE-WPF-SAMPLES" -Algorithm SHA256).Hash.ToLower()
# 기대: d3757d7fb7dd73bb027391905f06d4cf3000f79e8652d861e466d02ac028fac2
```

해시가 다르면 상류가 파일을 바꾼 것이다. 그 경우 파일은 그대로 두되
**사용자에게 보고한다** — 매니페스트에 기록된 시점과 현재가 다르다는 뜻이다.
네트워크가 막혀 받지 못하면 이 저장소의 부트스트랩만 보류하고 나머지를 진행한 뒤 사용자에게 알린다.

- [ ] **Step 5: WPF 저장소 5개에 CLAUDE.md 작성**

`CLAUDE.md`가 없는 WPF 저장소는 `PretextWpf`, `Wpf3DTutorial`, `WpfAutomationDemo`,
`MultiProcessTabbedBrowser`, `PolyLab3DStudio` 다섯이다. 원본 루트 `CLAUDE.md`의
WPF/WinUI 3 판단 기준을 승계하되, 프로젝트별 빌드·실행 정보를 함께 담는다.

각 파일은 아래 틀에 `<빌드>`/`<메모>` 두 곳만 프로젝트별로 채운다.

```markdown
# <저장소 이름>

<한 줄 설명 — 해당 저장소 README 첫 문단과 동일하게>

## 빌드와 실행

<빌드>

## 스택 선택 기준

이 저장소는 **WPF**로 작성되어 있다. "모던 Windows 데스크톱", "WinUI 3 스타일",
"Fluent 디자인" 요구가 들어오더라도 기본 답은 **WPF + [WPF-UI](https://github.com/lepoco/wpfui)**
(WinUI 3 룩앤필의 순수 WPF 재구현)이며, 실제 WinUI 3 / XAML Islands가 아니다.

이유: WPF-UI는 Windows App SDK 런타임 의존성, x64 전용 제약, MSBuild 특수성,
XAML Islands의 airspace 문제 없이 Fluent 외형·테마 전환·Mica/Acrylic을 제공한다.

예외: WPF와 WPF-UI로 만들 수 없는 Windows 네이티브 컨트롤·API가 실제로 필요할 때만
WinUI 3 / Windows App SDK를 쓴다 (`MediaPlayerElement`, `MapControl`, `AppNotifications` UI,
Windows AI Foundry 등). `WebView2`는 먼저 단독 패키지
`Microsoft.Web.WebView2.Wpf`를 검토한다. 예외에 해당하면 이 저장소에 섞지 말고
별도 저장소로 분리한다.

## 메모

<메모>
```

프로젝트별로 채울 내용:

| 저장소 | `<빌드>` | `<메모>` |
|---|---|---|
| `PretextWpf` | ```dotnet build PretextWpf.slnx```<br>```dotnet test tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj``` | 상류 pretext 이식본이다. 상류와의 차분 테스트가 있으므로 `src/Pretext.Wpf` 로직을 고칠 때는 `upstream-manifest.json`의 대응 관계를 먼저 확인한다. 라이브러리를 임의로 "개선"하지 말 것 — 상류 동작 재현이 목적이다. |
| `Wpf3DTutorial` | ```dotnet run --project src/Wpf3DTutorial/Wpf3DTutorial.csproj``` | 학습용 튜토리얼이다. 코드는 설명 가능한 수준으로 단순하게 유지하고, 추상화를 늘리지 않는다. |
| `WpfAutomationDemo` | ```dotnet run --project src/WpfAutomationDemo/WpfAutomationDemo.csproj``` | `WpfApp1/`은 스캐폴딩 잔재다. 실제 데모는 `src/WpfAutomationDemo/`. 접근성 동작 확인은 Accessibility Insights 또는 Inspect.exe로 한다. |
| `MultiProcessTabbedBrowser` | ```dotnet build MultiProcessTabbedBrowser.sln``` | 탭마다 별도 프로세스를 띄우고 named pipe로 통신한다. `SharedLib/IpcMessage.cs`의 메시지 계약을 바꾸면 양쪽 프로세스를 함께 고쳐야 한다. |
| `PolyLab3DStudio` | ```dotnet build PolyLab3DStudio.slnx```<br>```dotnet run --project src/PolyLab3DStudio.WpfApp/PolyLab3DStudio.WpfApp.csproj``` | `christian289/dotnet-with-claudecode`의 `samples/PolyLab3DStudio/`에서 분리해 왔다. 그 저장소의 WPF 규칙을 따른다: **CommunityToolkit.Mvvm + GenericHost**, ViewModel은 UI에 의존하지 않는다(`System.Windows` 참조 금지), 타깃은 `net10.0-windows`. NuGet 버전은 `Directory.Packages.props`에서 중앙 관리한다. README가 참조하는 "this repository's WPF coding rules"가 이 항목이다. |

- [ ] **Step 6: 부트스트랩 적용 스크립트 작성**

Create `tools/repo-split/Add-Bootstrap.ps1`:

```powershell
<#
.SYNOPSIS
bootstrap/<repo>/ 의 파일을 분할 저장소 기본 브랜치에 커밋 1개로 얹는다.

bare 저장소는 워킹 트리가 없으므로 임시 클론에서 작업한 뒤 되민다.
기존 커밋은 손대지 않고 맨 위에 1개만 추가한다.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Repo)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\manifest.ps1"

$proj = $Projects | Where-Object { $_.Repo -eq $Repo }
if (-not $proj) { throw "매니페스트에 '$Repo' 가 없습니다." }

$src = Join-Path $PSScriptRoot "bootstrap\$Repo"
if (-not (Test-Path $src)) { Write-Host "건너뜀 (부트스트랩 파일 없음): $Repo"; return }

$bare   = Join-Path $WorkRoot "$Repo.git"
$branch = $proj.Refs[0].To
$tmp    = Join-Path $WorkRoot "_bootstrap\$Repo"

if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force -Path (Split-Path $tmp) | Out-Null

git clone --branch $branch $bare $tmp
if ($LASTEXITCODE -ne 0) { throw "clone 실패: $Repo" }

Copy-Item -Path (Join-Path $src '*') -Destination $tmp -Recurse -Force

git -C $tmp add -A
$staged = git -C $tmp diff --cached --name-only
if (-not $staged) { Write-Host "변경 없음: $Repo"; Remove-Item -Recurse -Force $tmp; return }

$msg = @"
chore: 저장소 부트스트랩

Playground 모노레포에서 분리하면서 저장소 단위로 필요한 파일을 추가한다.
$($staged -join "`n")

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
"@
git -C $tmp commit -m $msg
if ($LASTEXITCODE -ne 0) { throw "commit 실패: $Repo" }

git -C $tmp push origin $branch
if ($LASTEXITCODE -ne 0) { throw "push 실패: $Repo" }

Remove-Item -Recurse -Force $tmp
Write-Host "OK  $Repo ($($staged.Count) files)" -ForegroundColor Green
```

- [ ] **Step 7: 전체 적용 후 확인**

```powershell
. .\tools\repo-split\manifest.ps1
foreach ($p in $Projects) { .\tools\repo-split\Add-Bootstrap.ps1 -Repo $p.Repo }
```

Expected: `WinAppCliOcr`만 `건너뜀 (부트스트랩 파일 없음)`이고 나머지 12개가 `OK`.
파일 수는 `PretextWpf` 4개(README + 라이선스 2 + CLAUDE), `PolyLab3DStudio` 2개(.gitignore + CLAUDE),
`Wpf3DTutorial`·`WpfAutomationDemo` 3개(.gitignore + README + CLAUDE) 식으로 저장소마다 다르다.

확인:

```powershell
foreach ($p in $Projects) {
    $b = Join-Path $WorkRoot "$($p.Repo).git"
    $n = git -C $b rev-list --count $p.Refs[0].To
    $top = git -C $b log -1 --format='%s' $p.Refs[0].To
    "{0,-26} {1,4} commits | {2}" -f $p.Repo, $n, $top
}
```

Expected: 부트스트랩을 받은 저장소는 커밋 수가 기준값 +1이고 최상단 메시지가
`chore: 저장소 부트스트랩`. `WinAppCliOcr`만 기준값 그대로(1커밋).

- [ ] **Step 8: 부트스트랩 이후 재검증 — 원래 히스토리가 그대로인지 확인**

```powershell
.\tools\repo-split\Verify-Split.ps1
```

Expected: `Tree` 열은 부트스트랩으로 파일이 늘어 `+N`이 뜨고 `Verdict=FAIL`이 된다. **이것은 정상이다.**
확인할 것은 `Missing` 열이 **전부 0**이라는 점 — 원래 커밋이 하나도 사라지지 않았다는 뜻이다.
`Tree` 열의 `+N`이 Step 7에서 추가한 파일 수와 정확히 일치하는지, `-`(누락)과 `~`(내용다름)이
**0인지** 확인한다. 누락이나 내용 변경이 있으면 부트스트랩이 기존 파일을 덮어쓴 것이므로 중단한다.

- [ ] **Step 9: 커밋**

```powershell
git add tools/repo-split/Add-Bootstrap.ps1 tools/repo-split/bootstrap
git commit -m @'
tools: 저장소별 부트스트랩 파일과 적용 스크립트 추가

분리된 저장소에 .gitignore/README/CLAUDE.md를 커밋 1개로 얹는다.
PretextWpf에는 upstream-manifest.json이 선언만 하고 빠져 있던
상류 라이선스 전문 두 개를 함께 넣는다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### Task 7: 조직 저장소 생성과 푸시

**Files:**
- Create: `tools/repo-split/Push-Repos.ps1`

**Interfaces:**
- Consumes: `manifest.ps1`, Task 6까지 완료된 bare 저장소들
- Produces: `christian289-playground` 아래 public 저장소 13개

- [ ] **Step 1: 푸시 스크립트 작성**

Create `tools/repo-split/Push-Repos.ps1`:

```powershell
<#
.SYNOPSIS
조직에 저장소를 만들고 모든 브랜치를 푸시한다.

이미 있는 저장소는 생성을 건너뛰고 푸시만 한다(멱등).
#>
[CmdletBinding()]
param([string]$Repo)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\manifest.ps1"

$targets = if ($Repo) { $Projects | Where-Object { $_.Repo -eq $Repo } } else { $Projects }
if (-not $targets) { throw "매니페스트에 '$Repo' 가 없습니다." }

foreach ($proj in $targets) {
    $full = "$Org/$($proj.Repo)"
    $bare = Join-Path $WorkRoot "$($proj.Repo).git"

    gh repo view $full --json name 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        gh repo create $full --public --description $proj.Desc --disable-wiki
        if ($LASTEXITCODE -ne 0) { throw "저장소 생성 실패: $full" }
    } else {
        Write-Host "이미 존재: $full" -ForegroundColor DarkGray
    }

    git -C $bare remote remove origin 2>$null | Out-Null
    git -C $bare remote add origin "https://github.com/$full.git"
    git -C $bare push --all origin
    if ($LASTEXITCODE -ne 0) { throw "push 실패: $full" }

    gh repo edit $full --default-branch $proj.Refs[0].To
    Write-Host "OK  $full" -ForegroundColor Green
}
```

- [ ] **Step 2: 저장소 1개로 먼저 시험 — Wpf3DTutorial**

```powershell
.\tools\repo-split\Push-Repos.ps1 -Repo Wpf3DTutorial
gh repo view christian289-playground/Wpf3DTutorial --json nameWithOwner,visibility,defaultBranchRef,description
```

Expected: `christian289-playground/Wpf3DTutorial`, `PUBLIC`, 기본 브랜치 `main`, 설명이 매니페스트의 `Desc`와 일치.

- [ ] **Step 3: 나머지 12개 푸시**

```powershell
. .\tools\repo-split\manifest.ps1
foreach ($p in $Projects | Where-Object { $_.Repo -ne 'Wpf3DTutorial' }) {
    .\tools\repo-split\Push-Repos.ps1 -Repo $p.Repo
}
```

Expected: 12개 전부 `OK`.

- [ ] **Step 4: 조직 저장소 15개 확인**

```powershell
gh repo list christian289-playground --limit 50 --json nameWithOwner,visibility,defaultBranchRef |
    ConvertFrom-Json | Sort-Object nameWithOwner |
    Format-Table @{n='Repo';e={$_.nameWithOwner}}, visibility, @{n='Default';e={$_.defaultBranchRef.name}} -AutoSize
```

Expected: 15행 — 분할 13개 + `wonderland` + `MewUiBadApple`. 전부 `PUBLIC`.
`love2d-serverdev`의 기본 브랜치가 `main`인지 특히 확인한다.

- [ ] **Step 5: love2d-serverdev의 두 브랜치가 다 올라갔는지 확인**

```powershell
gh api repos/christian289-playground/love2d-serverdev/branches --jq '.[].name'
```

Expected: `main`, `legacy/codedefense-0.1` 두 개.

- [ ] **Step 6: 커밋**

```powershell
git add tools/repo-split/Push-Repos.ps1
git commit -m @'
tools: 조직 저장소 생성·푸시 스크립트 추가

이미 있는 저장소는 생성을 건너뛰고 푸시만 하므로 재실행해도 안전하다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
```

---

### Task 8: Playground 색인화와 아카이브

**Files:**
- Modify: `README.md` (전체 교체)

**Interfaces:**
- Consumes: Task 1·7에서 만들어진 조직 저장소 15개
- Produces: 아카이브된 `christian289/Playground`

- [ ] **Step 1: README를 색인으로 교체**

Replace `README.md` 전체 내용:

```markdown
# Playground (보관됨)

이 저장소는 2026-08-06에 프로젝트별 저장소로 분할되었고 읽기 전용으로 보관 중이다.
새 작업은 아래 저장소에서 진행한다.

**→ [github.com/christian289-playground](https://github.com/christian289-playground)**

## 분할된 저장소

| 저장소 | 내용 |
|---|---|
| [love2d-serverdev](https://github.com/christian289-playground/love2d-serverdev) | 서버실 개발자 — Lua 코딩 교육용 실시간 타워디펜스 (LÖVE) |
| [PretextWpf](https://github.com/christian289-playground/PretextWpf) | pretext 텍스트 레이아웃 엔진의 WPF 포팅과 Playground 데모 |
| [PolyLab3DStudio](https://github.com/christian289-playground/PolyLab3DStudio) | WPF Viewport3D 3D 학습 스튜디오 (`dotnet-with-claudecode`에서 분리) |
| [love2d-mario](https://github.com/christian289-playground/love2d-mario) | LÖVE 2D 플랫포머 — STI 타일맵 + anim8 |
| [love2d-tetris](https://github.com/christian289-playground/love2d-tetris) | LÖVE 2D 테트리스 |
| [MultiProcessTabbedBrowser](https://github.com/christian289-playground/MultiProcessTabbedBrowser) | named pipe IPC로 탭마다 프로세스를 분리한 WPF 브라우저 셸 |
| [DotNetOAuth2Learning](https://github.com/christian289-playground/DotNetOAuth2Learning) | .NET OAuth2 학습 자료 |
| [WpfOnnxWinUI3Demo](https://github.com/christian289-playground/WpfOnnxWinUI3Demo) | WPF + WinUI 3 XAML Islands + ONNX Runtime 데모 |
| [WpfAutomationDemo](https://github.com/christian289-playground/WpfAutomationDemo) | WPF UI Automation 커스텀 컨트롤 데모 |
| [WinAppCliOcr](https://github.com/christian289-playground/WinAppCliOcr) | winapp CLI로 만든 Windows OCR 앱 |
| [MewUIPixelAnimation](https://github.com/christian289-playground/MewUIPixelAnimation) | MewUI 픽셀 그리드 애니메이션 |
| [Wpf3DTutorial](https://github.com/christian289-playground/Wpf3DTutorial) | WPF Viewport3D 튜토리얼 |
| [OldNewThingMcpServer](https://github.com/christian289-playground/OldNewThingMcpServer) | Microsoft DevBlogs MCP 서버 |

## 함께 이관된 저장소

| 저장소 | 내용 |
|---|---|
| [wonderland](https://github.com/christian289-playground/wonderland) | — |
| [MewUiBadApple](https://github.com/christian289-playground/MewUiBadApple) | MewUI를 이용한 Bad Apple!! |

## 분할 기록

- 설계: `docs/superpowers/specs/2026-08-06-playground-repo-split-design.md`
- 계획: `docs/superpowers/plans/2026-08-06-playground-repo-split.md`
- 스크립트: `tools/repo-split/`

분할된 저장소의 커밋 해시는 히스토리 재작성으로 이 저장소와 다르다.
원본 해시가 필요하면 이 저장소를 참조한다.
이관된 두 저장소는 해시가 그대로이고 옛 URL에서 리다이렉트된다.

`PolyLab3DStudio`만은 이 저장소가 아니라
[christian289/dotnet-with-claudecode](https://github.com/christian289/dotnet-with-claudecode)의
`samples/PolyLab3DStudio/`에서 분리했다. 원본은 수정하지 않았으므로 그쪽에도 그대로 남아 있다.
```

- [ ] **Step 2: 커밋하고 origin/main으로 푸시**

작업 브랜치는 `main-2`이고 `origin/main`의 조상이 아니라 후손이므로 fast-forward 푸시가 된다.

```powershell
git add README.md
git commit -m @'
docs: README를 분할된 저장소 색인으로 교체

이 저장소는 아카이브되며 새 작업은 christian289-playground 조직에서 진행한다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
'@
git push origin main-2:main
```

Expected: fast-forward 성공. 실패하면 `git log --oneline origin/main..main-2`로 관계를 확인한다.

- [ ] **Step 3: 푸시 결과 확인**

```powershell
gh api repos/christian289/Playground --jq '.default_branch, .pushed_at'
gh api repos/christian289/Playground/contents/README.md --jq '.content' |
    ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) } |
    Select-Object -First 5
```

Expected: 새 README 첫 줄이 `# Playground (보관됨)`.

- [ ] **Step 4: 아카이브**

이것이 원본에 가하는 마지막 변경이다. GitHub 웹 UI 또는 API로 언제든 해제할 수 있다.

```powershell
gh api -X PATCH repos/christian289/Playground -F archived=true
gh repo view christian289/Playground --json isArchived,nameWithOwner
```

Expected: `{"isArchived":true,"nameWithOwner":"christian289/Playground"}`.

---

### Task 9: 로컬 작업 환경 안내

**Files:**
- 없음 (보고만)

**Interfaces:**
- Consumes: Task 8까지의 결과
- Produces: 사용자에게 전달할 안내

- [ ] **Step 1: 현재 로컬 상태 정리해서 보고**

```powershell
git worktree list
git -C C:\Users\chris\personal\Playground status --short
```

- [ ] **Step 2: 사용자에게 다음 내용을 보고한다 (실행하지 않는다)**

로컬 `C:\Users\chris\personal\Playground`와 그 워크트리들은 이제 아카이브된 저장소를 가리킨다.
아카이브된 저장소는 푸시를 거부하므로 이 폴더에서 작업을 이어갈 수 없다.

권장 정리 방법 (사용자가 직접 판단해 실행):

```powershell
# 1) 기존 폴더를 백업으로 보존
Rename-Item C:\Users\chris\personal\Playground C:\Users\chris\personal\Playground.bak

# 2) 필요한 저장소만 새로 클론
New-Item -ItemType Directory -Force C:\Users\chris\personal\playground | Out-Null
gh repo clone christian289-playground/love2d-serverdev C:\Users\chris\personal\playground\love2d-serverdev
gh repo clone christian289-playground/PretextWpf       C:\Users\chris\personal\playground\PretextWpf
```

`feature-serverdev-2` 워크트리는 디스크에 존재하지 않는 유령 등록이므로
`Playground.bak`을 지울 때 함께 사라진다.

`$env:TEMP\repo-split`의 중간 산출물은 푸시가 끝났으므로 지워도 된다.
문제가 없다고 확인될 때까지 두었다가 지우기를 권한다.

- [ ] **Step 3: 최종 결과 보고**

조직 저장소 15개 목록, 각 저장소의 커밋 수, 아카이브 상태를 표로 제시한다.

```powershell
gh repo list christian289-playground --limit 50 --json nameWithOwner,description,visibility |
    ConvertFrom-Json | Sort-Object nameWithOwner | Format-Table -AutoSize
```
