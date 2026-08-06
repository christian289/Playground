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

$failed = @()

foreach ($proj in $targets) {
    $full = "$Org/$($proj.Repo)"
    $bare = Join-Path $WorkRoot "$($proj.Repo).git"

    try {
        gh repo view $full --json name 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            gh repo create $full --public --description $proj.Desc --disable-wiki
            if ($LASTEXITCODE -ne 0) { throw "저장소 생성 실패: $full" }
        } else {
            Write-Host "이미 존재: $full" -ForegroundColor DarkGray
        }

        git -C $bare remote remove origin 2>$null | Out-Null

        $expectedUrl = "https://github.com/$full.git"
        git -C $bare remote add origin $expectedUrl
        if ($LASTEXITCODE -ne 0) { throw "remote add 실패: $full" }

        $actualUrl = git -C $bare remote get-url origin
        if ($LASTEXITCODE -ne 0 -or $actualUrl -ne $expectedUrl) {
            throw "origin remote URL 불일치: $full (기대: $expectedUrl, 실제: $actualUrl)"
        }

        git -C $bare push --all origin
        if ($LASTEXITCODE -ne 0) { throw "push 실패: $full" }

        $wantDefault = $proj.Refs[0].To
        gh repo edit $full --default-branch $wantDefault
        if ($LASTEXITCODE -ne 0) { throw "기본 브랜치 설정 실패: $full" }

        $actualDefault = gh repo view $full --json defaultBranchRef --jq '.defaultBranchRef.name'
        if ($LASTEXITCODE -ne 0 -or $actualDefault -ne $wantDefault) {
            throw "기본 브랜치 확인 실패: $full (기대: $wantDefault, 실제: '$actualDefault')"
        }

        Write-Host "OK  $full" -ForegroundColor Green
    } catch {
        Write-Host "FAIL $full - $_" -ForegroundColor Red
        $failed += $proj.Repo
    }
}

if ($failed.Count -gt 0) {
    Write-Host "실패한 저장소: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
