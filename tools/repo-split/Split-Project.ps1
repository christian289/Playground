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
if ($LASTEXITCODE -ne 0) { throw "symbolic-ref 설정 실패: $Repo -> refs/heads/$($proj.Refs[0].To)" }

# 폴더는 루트로 승격, 글로브 파일은 경로 유지
$frArgs = @('--force')
foreach ($p in $proj.Paths) { $frArgs += @('--path', "$p/", '--path-rename', "${p}/:") }
foreach ($g in $proj.Globs) { $frArgs += @('--path-glob', $g) }

Write-Host "filter-repo $($frArgs -join ' ')" -ForegroundColor DarkGray
git -C $dest filter-repo @frArgs
if ($LASTEXITCODE -ne 0) { throw "filter-repo 실패: $Repo" }

# filter-repo가 ref를 재작성하므로, 그 이후에 HEAD가 여전히 기대한 기본 브랜치를
# 가리키는지 재확인한다 — 사전 설정만으로는 증명이 안 된다.
$expectedHead = "refs/heads/$($proj.Refs[0].To)"
$actualHead = git -C $dest symbolic-ref HEAD
if ($LASTEXITCODE -ne 0) { throw "symbolic-ref 확인 실패: $Repo" }
if ($actualHead -ne $expectedHead) { throw "$Repo : HEAD 불일치 — 기대 '$expectedHead', 실제 '$actualHead'" }

foreach ($r in $proj.Refs) {
    $n = git -C $dest rev-list --count $r.To
    if ($LASTEXITCODE -ne 0) { throw "$Repo : rev-list 실패 — ref '$($r.To)'" }
    Write-Host ("  {0,-26} {1,4} commits" -f $r.To, $n)
}
Write-Host "OK  $Repo -> $dest" -ForegroundColor Green
