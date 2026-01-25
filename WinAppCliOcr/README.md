# Windows OCR

Windows 내장 OCR 엔진을 사용하는 간단한 WPF OCR 애플리케이션입니다.

## 기능

- **이미지 입력**: 파일 선택, 드래그 앤 드롭, 클립보드 붙여넣기 (Ctrl+V)
- **다국어 OCR**: Windows에 설치된 모든 언어 지원
- **결과 복사**: 인식된 텍스트 원클릭 복사
- **단일 파일 배포**: .NET 런타임 포함, 별도 설치 불필요
- **자동 업데이트**: Velopack 기반 업데이트 지원

## 요구 사항

- Windows 10/11 (버전 1809 이상)
- OCR 언어팩 (설정 > 시간 및 언어 > 언어에서 추가)

## 설치

### 옵션 1: Setup 설치 프로그램 (권장)
`WinAppCliOcr-win-Setup.exe` 다운로드 후 실행
- 원클릭 설치
- 시작 메뉴 바로가기 자동 생성
- 자동 업데이트 지원
- 설치 경로: `%LocalAppData%\WinAppCliOcr`

### 옵션 2: 포터블
`WinAppCliOcr-win-Portable.zip` 압축 해제 후 `WinAppCliOcr.exe` 실행

## 소스에서 빌드

### 필수 도구
- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- [Velopack CLI](https://velopack.io/): `dotnet tool install -g vpk`
- [winapp CLI](https://github.com/microsoft/winappCli) (선택, 디버그 ID용)

### 빌드 명령어

```powershell
# 저장소 클론
git clone https://github.com/user/WinAppCliOcr.git
cd WinAppCliOcr

# 디버그 빌드
dotnet build -c Debug

# 릴리스 배포 (SingleFile, SelfContained)
dotnet publish -c Release -o publish

# Velopack 설치 프로그램 생성
vpk pack --packId WinAppCliOcr --packVersion 1.0.0 --packDir publish --mainExe WinAppCliOcr.exe --outputDir releases

# 또는 빌드 스크립트 사용
.\build.ps1 -Package -Version "1.0.0"
```

### 출력 파일
| 파일 | 설명 | 크기 |
|------|------|------|
| `WinAppCliOcr-win-Setup.exe` | 원클릭 설치 프로그램 | ~74 MB |
| `WinAppCliOcr-win-Portable.zip` | 포터블 버전 | ~72 MB |
| `WinAppCliOcr-{ver}-full.nupkg` | 업데이트용 패키지 | ~72 MB |

## 사용법

1. **이미지 로드**:
   - "Select Image" 버튼으로 파일 선택
   - 이미지 파일을 창에 드래그 앤 드롭
   - Ctrl+V로 클립보드에서 붙여넣기

2. **언어 선택**: 드롭다운에서 OCR 언어 선택

3. **인식**: "Recognize Text" 버튼 클릭

4. **복사**: "Copy" 버튼으로 결과 복사

## 지원 이미지 형식

PNG, JPG/JPEG, BMP, GIF

## 기술 스택

- .NET 10, WPF
- Windows.Media.Ocr (Windows 내장 OCR API)
- [Velopack](https://velopack.io/) (설치 및 업데이트)
- [winapp CLI](https://github.com/microsoft/winappCli) (개발 워크플로우)

## 라이선스

MIT License
