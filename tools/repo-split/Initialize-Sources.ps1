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
