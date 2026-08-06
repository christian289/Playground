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
