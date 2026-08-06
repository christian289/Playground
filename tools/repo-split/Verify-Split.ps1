<#
.SYNOPSIS
분할 결과를 원본과 대조한다.

검사 A (필수): 트리 blob 동일성. 원본의 해당 경로 집합과 새 저장소의 트리가
               경로·모드·blob SHA까지 완전히 일치해야 한다.
검사 B (필수): 원본에서 해당 경로를 건드린 커밋이 전부 새 저장소에 존재해야 한다.
               (저자, 저자일시, 제목) 3튜플의 집합으로 비교한다. 원본 쪽은 `--full-history`
               로 커밋을 모아 git의 기본 히스토리 단순화가 커밋(특히 병합 커밋)을
               숨기지 못하게 한다 — 그러나 병합 커밋은 경로 필터링 후 퇴화되어
               filter-repo가 정당하게 가지치기할 수 있으므로, 누락된 병합 커밋은
               실패로 치지 않고 `MissMerge`로만 보고한다(검사 B'). 누락된 비병합
               커밋만 `Missing`으로 실패 처리한다.
검사 C (참고): 새 저장소에만 있는 커밋 수. 병합 커밋 단순화 방식의 차이로
               0이 아닐 수 있어 보고만 하고 실패로 처리하지 않는다.
검사 D (필수): 대상 저장소의 참조(브랜치·태그) 집합이 매니페스트의 Refs.To 집합과
               정확히 일치해야 한다. 매니페스트에 없는 브랜치나 태그가 하나라도
               있으면 실패 — Task 7의 `git push --all`이 그걸 그대로 공개 저장소에
               올려버린다.

검사 A가 권위 있는 검사다. 파일 한 바이트가 달라져도 blob SHA가 달라진다.

주의: 이 pwsh 환경은 $PSNativeCommandUseErrorActionPreference 가 False라
      $ErrorActionPreference='Stop' 만으로는 git의 실패(0이 아닌 종료 코드)를 잡지
      못한다. git을 호출하는 모든 헬퍼 함수는 $LASTEXITCODE 를 직접 확인해서 실패 시
      throw 해야 한다 — 그렇지 않으면 실패한 git 호출이 빈 컬렉션을 반환하고, 원본과
      대상이 둘 다 비어 있으면 "일치"로 오판(거짓 PASS)한다. 같은 이유로 Get-TreeMap도
      ls-tree가 돌려준 줄 수와 실제로 정규식에 매칭되어 파싱된 항목 수를 맞춰봐서,
      하나라도 파싱에 실패하면(둘 다 같은 방식으로 파싱하므로 양쪽에서 조용히
      사라져 "일치"로 오판할 수 있다) throw 한다.
#>
[CmdletBinding()]
param([string]$Repo)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\manifest.ps1"

function Get-TreeMap {
    param([string]$RepoPath, [string]$Ref)
    $map = @{}
    $lines = @(git -C $RepoPath -c core.quotePath=false ls-tree -r $Ref)
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-tree 실패 (repo=$RepoPath, ref=$Ref, exit=$LASTEXITCODE)"
    }
    $nonEmpty = @($lines | Where-Object { $_ -ne '' })
    $parsed = 0
    $badLine = $null
    foreach ($l in $nonEmpty) {
        if ($l -match '^(\d{6}) \w+ ([0-9a-f]{40})\t(.+)$') {
            $map[$Matches[3]] = "$($Matches[1]) $($Matches[2])"
            $parsed++
        } elseif (-not $badLine) {
            $badLine = $l
        }
    }
    if ($parsed -ne $nonEmpty.Count) {
        # 두 저장소를 똑같은 정규식으로 파싱하므로, 파싱 실패는 양쪽에서 조용히
        # 사라져 "일치"로 오판될 수 있다 — 침묵하지 말고 반드시 throw.
        throw "git ls-tree 출력 파싱 실패 (repo=$RepoPath, ref=$Ref): 파싱됨 $parsed / 전체 $($nonEmpty.Count) — 정규식과 맞지 않는 줄: '$badLine'"
    }
    return $map
}

function Get-CommitSet {
    param([string]$RepoPath, [string]$Ref, [string[]]$Pathspec, [switch]$FullHistory)
    # %p(부모 해시)를 추가로 받아 원본 쪽 병합 여부 판정에 쓴다. 단, 부모 해시는
    # 저장소마다 값이 다르므로(같은 커밋도 원본/분할 저장소에서 SHA가 다름)
    # 비교 키에는 절대 포함하지 않는다 — ConvertTo-CommitRecord 가 (저자, 일시, 제목)
    # 3튜플만 키로 뽑아내고 부모 필드는 IsMerge 판정에만 쓴다.
    $fmt = '%an%x1f%ad%x1f%s%x1f%p'
    if ($Pathspec) {
        if ($FullHistory) {
            $out = @(git -C $RepoPath -c core.quotePath=false log --full-history --format=$fmt --date=iso-strict $Ref -- @Pathspec)
        } else {
            $out = @(git -C $RepoPath -c core.quotePath=false log --format=$fmt --date=iso-strict $Ref -- @Pathspec)
        }
    } else {
        $out = @(git -C $RepoPath -c core.quotePath=false log --format=$fmt --date=iso-strict $Ref)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "git log 실패 (repo=$RepoPath, ref=$Ref, exit=$LASTEXITCODE)"
    }
    return $out
}

function ConvertTo-CommitRecord {
    # 원시 로그 줄("저자\x1f일시\x1f제목\x1f부모해시들")을 비교용 레코드로 바꾼다.
    # Key = (저자, 일시, 제목) 3튜플만으로 구성 — 저장소마다 값이 다른 부모 해시는
    # 절대 Key에 섞이지 않는다. IsMerge 는 부모 수가 2개 이상인지로만 판정한다.
    param([string]$Line)
    $sep = [char]0x1f
    $parts = $Line -split $sep
    $key = "$($parts[0])$sep$($parts[1])$sep$($parts[2])"
    $parentCount = 0
    if ($parts.Count -ge 4 -and $parts[3]) {
        $parentCount = @($parts[3] -split ' ' | Where-Object { $_ }).Count
    }
    return [pscustomobject]@{ Key = $key; IsMerge = ($parentCount -gt 1) }
}

function Get-RefSet {
    param([string]$RepoPath)
    $heads = @(git -C $RepoPath for-each-ref --format='%(refname:short)' refs/heads)
    if ($LASTEXITCODE -ne 0) {
        throw "git for-each-ref(refs/heads) 실패 (repo=$RepoPath, exit=$LASTEXITCODE)"
    }
    $tags = @(git -C $RepoPath for-each-ref --format='%(refname:short)' refs/tags)
    if ($LASTEXITCODE -ne 0) {
        throw "git for-each-ref(refs/tags) 실패 (repo=$RepoPath, exit=$LASTEXITCODE)"
    }
    return @{ Heads = $heads; Tags = $tags }
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
            $rows += [pscustomobject]@{ Repo=$label; Files='-'; Tree='MISSING'; Commits='-'; Missing='-'; MissMerge='-'; Extra='-'; Verdict='FAIL' }
            continue
        }

        try {
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

            if ($expected.Count -eq 0) {
                # Paths/Globs 설정 오류(오타, 잘못된 폴더명 등)로 기대값이 통째로 비면
                # 대상이 뭐든 "0 == 0"으로 거짓 PASS가 난다. 절대 통과시키지 않는다.
                $rows += [pscustomobject]@{ Repo=$label; Files='0/0'; Tree='EMPTY-EXPECTED'; Commits='-'; Missing='-'; MissMerge='-'; Extra='-'; Verdict='FAIL' }
                Write-Warning "[$label] 기대 파일 집합이 비었습니다 — Paths/Globs 설정을 확인하세요 (source=$srcRepo, ref=$($r.From))"
                continue
            }

            # --- 실제값 ---
            $actual = Get-TreeMap $dest $r.To

            $missingFiles = @($expected.Keys | Where-Object { -not $actual.ContainsKey($_) })
            $extraFiles   = @($actual.Keys   | Where-Object { -not $expected.ContainsKey($_) })
            $diffFiles    = @($expected.Keys | Where-Object { $actual.ContainsKey($_) -and $actual[$_] -ne $expected[$_] })
            $treeOk       = ($missingFiles.Count + $extraFiles.Count + $diffFiles.Count) -eq 0

            # --- 커밋 ---
            # 원본은 --full-history 로 모은다: 경로 필터와 함께 쓰는 기본 히스토리
            # 단순화는 병합 커밋(때로는 일반 커밋도)을 조용히 숨길 수 있다.
            $srcCommitsRaw = Get-CommitSet $srcRepo $r.From @($proj.Paths + $proj.Globs) -FullHistory
            $dstCommitsRaw = Get-CommitSet $dest $r.To $null
            $srcRecords = @($srcCommitsRaw | ForEach-Object { ConvertTo-CommitRecord $_ })
            $dstRecords = @($dstCommitsRaw | ForEach-Object { ConvertTo-CommitRecord $_ })

            $dstLookup = @{}; foreach ($rec in $dstRecords) { $dstLookup[$rec.Key] = $true }
            $srcLookup = @{}; foreach ($rec in $srcRecords) { $srcLookup[$rec.Key] = $true }

            $missingRecords = @($srcRecords | Where-Object { -not $dstLookup.ContainsKey($_.Key) })
            # 누락된 병합 커밋은 정보용일 뿐이다 — filter-repo는 경로 필터링 후
            # 퇴화된 병합을 정당하게 가지치기하므로 실패로 치지 않는다(검사 B').
            # 누락된 비병합 커밋만 진짜 손실이며 Missing/판정에 반영한다.
            $missingCommits      = @($missingRecords | Where-Object { -not $_.IsMerge })
            $missingMergeCommits = @($missingRecords | Where-Object { $_.IsMerge })
            $extraCommits        = @($dstRecords | Where-Object { -not $srcLookup.ContainsKey($_.Key) })

            $verdict = if ($treeOk -and $missingCommits.Count -eq 0) { 'PASS' } else { 'FAIL' }

            $rows += [pscustomobject]@{
                Repo      = $label
                Files     = "$($actual.Count)/$($expected.Count)"
                Tree      = if ($treeOk) { 'OK' } else { "-$($missingFiles.Count) +$($extraFiles.Count) ~$($diffFiles.Count)" }
                Commits   = "$($dstRecords.Count)/$($srcRecords.Count)"
                Missing   = $missingCommits.Count
                MissMerge = $missingMergeCommits.Count
                Extra     = $extraCommits.Count
                Verdict   = $verdict
            }

            if (-not $treeOk) {
                Write-Warning "[$label] 파일 불일치 — 누락 $($missingFiles.Count) / 초과 $($extraFiles.Count) / 내용다름 $($diffFiles.Count)"
                $missingFiles | Select-Object -First 10 | ForEach-Object { Write-Warning "  누락: $_" }
                $extraFiles   | Select-Object -First 10 | ForEach-Object { Write-Warning "  초과: $_" }
                $diffFiles    | Select-Object -First 10 | ForEach-Object { Write-Warning "  다름: $_" }
            }
            if ($missingCommits.Count -gt 0) {
                Write-Warning "[$label] 커밋 누락 $($missingCommits.Count)건(비병합)"
                $missingCommits | Select-Object -First 5 | ForEach-Object { Write-Warning "  $($_.Key -replace [char]31, ' | ')" }
            }
            if ($missingMergeCommits.Count -gt 0) {
                Write-Host "[$label] 병합 커밋 $($missingMergeCommits.Count)건은 대상에 없지만 정보용으로만 보고(퇴화 병합의 정당한 가지치기일 수 있음)" -ForegroundColor Yellow
            }
        }
        catch {
            # git 호출 실패(잘못된 ref, 손상된 저장소 등)를 침묵시키지 않는다.
            # 여기서 잡지 않으면 스크립트 전체가 죽어 나머지 13개 행을 못 보게 되므로,
            # 이 행만 FAIL 처리하고 다음 ref로 넘어간다.
            $rows += [pscustomobject]@{ Repo=$label; Files='-'; Tree='ERROR'; Commits='-'; Missing='-'; MissMerge='-'; Extra='-'; Verdict='FAIL' }
            Write-Warning "[$label] 검증 중 오류 — $($_.Exception.Message)"
            continue
        }
    }

    # --- 검사 D: 대상 저장소에 매니페스트에 없는 브랜치/태그가 없는지 (프로젝트당 1회) ---
    if (Test-Path $dest) {
        try {
            $refSet       = Get-RefSet $dest
            $expectedHeads = @($proj.Refs | ForEach-Object { $_.To })
            $extraHeads    = @($refSet.Heads | Where-Object { $expectedHeads -notcontains $_ })
            $extraTags     = @($refSet.Tags)
            $extraRefs     = @($extraHeads) + @($extraTags)

            if ($extraRefs.Count -gt 0) {
                $rows += [pscustomobject]@{
                    Repo      = "$($proj.Repo) [refs]"
                    Files     = '-'
                    Tree      = '-'
                    Commits   = '-'
                    Missing   = '-'
                    MissMerge = '-'
                    Extra     = ($extraRefs -join ', ')
                    Verdict   = 'FAIL'
                }
                Write-Warning "[$($proj.Repo)] 매니페스트에 없는 참조 발견 — $($extraRefs -join ', ') (`git push --all`로 그대로 공개될 수 있음)"
            }
        }
        catch {
            $rows += [pscustomobject]@{ Repo="$($proj.Repo) [refs]"; Files='-'; Tree='-'; Commits='-'; Missing='-'; MissMerge='-'; Extra='-'; Verdict='FAIL' }
            Write-Warning "[$($proj.Repo)] 참조 목록 확인 중 오류 — $($_.Exception.Message)"
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
