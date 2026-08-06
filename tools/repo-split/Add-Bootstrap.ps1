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
