# Code Defense 배포 패키징 (LÖVE 표준 fuse 방식)
# 사용법: 프로젝트 루트에서  powershell -ExecutionPolicy Bypass -File tools\package.ps1
# 출력:  dist\CodeDefense\  — 폴더째 복사하면 LÖVE 미설치 PC에서도 실행 가능

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$loveDir = "C:\Program Files\LOVE"
$distDir = Join-Path $projectRoot "dist\CodeDefense"
$loveFile = Join-Path $projectRoot "dist\CodeDefense.love"

if (-not (Test-Path (Join-Path $loveDir "love.exe"))) {
    throw "LÖVE 설치를 찾을 수 없습니다: $loveDir (winget install love)"
}

# 1) 게임 코드만 zip → .love  (data/는 제외 — io.open으로 읽으므로 exe 옆에 폴더로 동봉)
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot "dist") | Out-Null
if (Test-Path $loveFile) { Remove-Item $loveFile -Force }
$include = @("main.lua", "conf.lua", "src", "states", "lib", "assets") |
    ForEach-Object { Join-Path $projectRoot $_ }
Compress-Archive -Path $include -DestinationPath ($loveFile -replace "\.love$", ".zip") -Force
Move-Item ($loveFile -replace "\.love$", ".zip") $loveFile -Force

# 2) love.exe와 결합(fuse) → CodeDefense.exe
#    주의: dist 폴더를 통째로 지우고 재생성하면 Windows의 지연 삭제(delete-pending) 때문에
#    직후 복사가 조용히 실패할 수 있다 — 폴더는 유지하고 파일 단위로 제자리 갱신한다.
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$exePath = Join-Path $distDir "CodeDefense.exe"
if (Test-Path $exePath) { Remove-Item $exePath -Force }
cmd /c copy /b "`"$($loveDir)\love.exe`"+`"$loveFile`"" "`"$exePath`"" | Out-Null
if (-not (Test-Path $exePath)) { throw "fuse 실패: $exePath" }

# 3) 게임 데이터(data/)를 exe 옆에 동봉(미러링) — CSV/미로/커리큘럼을 고쳐 커스텀 스테이지 가능
robocopy (Join-Path $projectRoot "data") (Join-Path $distDir "data") /MIR /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8 -or -not (Test-Path (Join-Path $distDir "data\towers.csv"))) {
    throw "data 복사 실패: $distDir\data (robocopy exit $LASTEXITCODE)"
}
$global:LASTEXITCODE = 0  # robocopy는 성공도 0이 아닌 코드를 반환하므로 초기화

# 4) 실행에 필요한 DLL + 라이선스 동봉
Get-ChildItem $loveDir -Filter "*.dll" | Copy-Item -Destination $distDir
$license = Join-Path $loveDir "license.txt"
if (Test-Path $license) { Copy-Item $license (Join-Path $distDir "LOVE-license.txt") }

$size = [math]::Round((Get-ChildItem $distDir -Recurse | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "완료: $distDir (총 ${size}MB)"
Write-Host "실행: $exePath"
