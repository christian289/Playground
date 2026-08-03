# ServerDev(《서버실 개발자:우리는 음지에서 일하고 고액연봉을 지향한다.》) 배포 패키징 (LÖVE 표준 fuse 방식)
# 사용법: 프로젝트 루트에서  powershell -ExecutionPolicy Bypass -File tools\package.ps1
# 출력:  dist\ServerDev\  — 폴더째 복사하면 LÖVE 미설치 PC에서도 실행 가능

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$loveDir = "C:\Program Files\LOVE"
$distDir = Join-Path $projectRoot "dist\ServerDev"
$loveFile = Join-Path $projectRoot "dist\ServerDev.love"

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

# 1.5) 룩 아이콘을 exe 리소스로 주입 — 파일 탐색기 아이콘은 PE 리소스라 setIcon과 별개다.
#      반드시 fuse "이전"의 love.exe 사본에 주입한다 (fuse 후 PE를 고치면 뒤에 붙인 zip이 깨짐).
$fuseBase = Join-Path $loveDir "love.exe"
$iconDir = Join-Path $projectRoot "dist\icon"
New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
try {
    # 룩 픽셀아트(art.rookIconData)를 단일 소스로 크기별 PNG 생성
    & (Join-Path $loveDir "lovec.exe") (Join-Path $projectRoot "tools\genicon") | Out-Null

    # ICO 합성 — PNG 압축 엔트리는 ICO 규격상 256px에만 허용되므로
    # 16/32/48은 고전 32bpp DIB(BMP) 엔트리로 변환해 넣는다 (작은 크기를 PNG로 넣으면
    # 탐색기/셸이 디코드하지 못해 기본 아이콘으로 표시된다).
    Add-Type -AssemblyName System.Drawing
    function ConvertTo-IcoDib([System.Drawing.Bitmap]$bmp) {
        $s = $bmp.Width
        $m = New-Object IO.MemoryStream
        $w = New-Object IO.BinaryWriter($m)
        $andStride = [int]([math]::Ceiling($s / 32.0) * 4)
        $w.Write([uint32]40); $w.Write([int32]$s); $w.Write([int32]($s * 2))
        $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]0)
        $w.Write([uint32]($s * $s * 4 + $andStride * $s))
        $w.Write([int32]0); $w.Write([int32]0); $w.Write([uint32]0); $w.Write([uint32]0)
        for ($y = $s - 1; $y -ge 0; $y--) {
            for ($x = 0; $x -lt $s; $x++) {
                $c = $bmp.GetPixel($x, $y)
                $w.Write([byte]$c.B); $w.Write([byte]$c.G); $w.Write([byte]$c.R); $w.Write([byte]$c.A)
            }
        }
        $w.Write((New-Object byte[] ($andStride * $s)))
        , $m.ToArray()
    }
    $sizes = 16, 32, 48, 256
    $entries = foreach ($s in $sizes) {
        $png = Join-Path $iconDir "rook-$s.png"
        if ($s -ge 256) { , [IO.File]::ReadAllBytes($png) }
        else {
            $bmp = New-Object System.Drawing.Bitmap($png)
            try { ConvertTo-IcoDib $bmp } finally { $bmp.Dispose() }
        }
    }
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter($ms)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$entries[$i].Length); $bw.Write([uint32]$offset)
        $offset += $entries[$i].Length
    }
    foreach ($b in $entries) { $bw.Write($b) }
    $icoPath = Join-Path $iconDir "rook.ico"
    [IO.File]::WriteAllBytes($icoPath, $ms.ToArray())

    # rcedit(electron 배포 표준 도구) 확보 — 최초 1회 다운로드 후 tools\bin에 캐시(git 제외)
    $rcedit = Join-Path $projectRoot "tools\bin\rcedit-x64.exe"
    if (-not (Test-Path $rcedit)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $rcedit) | Out-Null
        Invoke-WebRequest "https://github.com/electron/rcedit/releases/latest/download/rcedit-x64.exe" -OutFile $rcedit
    }
    $lovePatched = Join-Path $iconDir "love-icon.exe"
    Copy-Item (Join-Path $loveDir "love.exe") $lovePatched -Force
    & $rcedit $lovePatched --set-icon $icoPath
    if ($LASTEXITCODE -ne 0) { throw "rcedit 실패 (exit $LASTEXITCODE)" }
    $fuseBase = $lovePatched
} catch {
    Write-Warning "아이콘 주입 건너뜀(기본 LÖVE 아이콘 사용): $_"
}

# 2) love.exe와 결합(fuse) → ServerDev.exe
#    주의: dist 폴더를 통째로 지우고 재생성하면 Windows의 지연 삭제(delete-pending) 때문에
#    직후 복사가 조용히 실패할 수 있다 — 폴더는 유지하고 파일 단위로 제자리 갱신한다.
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$exePath = Join-Path $distDir "ServerDev.exe"
if (Test-Path $exePath) { Remove-Item $exePath -Force }
cmd /c copy /b "`"$fuseBase`"+`"$loveFile`"" "`"$exePath`"" | Out-Null
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

# 5) 중간 산물 .love 제거 — dist에 남겨두면 실행 파일로 오인해 더블클릭하는 함정이 된다
#    (.love 단독 실행은 data/가 exe 옆에 있는 이 배포 구조에서 성립하지 않음 — main.lua도 안내 오류를 냄)
Remove-Item $loveFile -Force -ErrorAction SilentlyContinue

$size = [math]::Round((Get-ChildItem $distDir -Recurse | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "완료: $distDir (총 ${size}MB)"
Write-Host "실행: $exePath"
