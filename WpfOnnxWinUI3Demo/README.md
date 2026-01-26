# WPF + WinUI 3 XAML Islands + ONNX Runtime Demo

WPF 애플리케이션에서 WinUI 3 컨트롤을 XAML Islands로 호스팅하고, ONNX Runtime으로 이미지 분류를 수행하는 데모 프로젝트입니다.

## 주요 기능

- **WinUI 3 XAML Islands**: WPF 내에서 WinUI 3 컨트롤 호스팅
- **ONNX Runtime DirectML**: GPU 가속 이미지 분류 (CPU 폴백 지원)
- **ResNet50 v2**: ImageNet 1000 클래스 분류

## 요구 사항

- Windows 10 버전 1903 이상 (Windows 11 권장)
- .NET 10.0 SDK
- **Visual Studio 2022** (MSBuild 필수 - dotnet CLI만으로는 빌드 불가)
- **x64 플랫폼 전용** (Any CPU 미지원)

## 프로젝트 구조

```
WpfOnnxWinUI3Demo/
├── src/
│   ├── WpfOnnxWinUI3Demo.Core/           # ONNX 추론 서비스
│   ├── WpfOnnxWinUI3Demo.ViewModels/     # MVVM ViewModel
│   └── WpfOnnxWinUI3Demo.WpfApp/         # WPF 호스트 애플리케이션
│       └── Controls/                      # WinUI 3 컨트롤 (C# 코드)
└── README.md
```

## 설정 방법

### 1. ONNX 모델 다운로드

ResNet50 v2 모델을 다운로드하여 `Assets/model/` 폴더에 저장합니다:

```
https://github.com/onnx/models/raw/main/validated/vision/classification/resnet/model/resnet50-v2-7.onnx
```

파일 크기: ~98 MB

### 2. (선택) ImageNet 레이블 다운로드

더 읽기 쉬운 클래스 이름을 위해 레이블 파일을 다운로드합니다:

```
https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt
```

`Assets/model/imagenet_labels.txt`로 저장합니다.

### 3. 빌드

**Visual Studio MSBuild 사용** (필수):

```powershell
# Developer Command Prompt for VS 2022에서 실행
cd WpfOnnxWinUI3Demo
msbuild WpfOnnxWinUI3Demo.sln -p:Configuration=Release -p:Platform=x64 -restore
```

또는 Visual Studio에서:
1. `WpfOnnxWinUI3Demo.sln` 열기
2. 플랫폼을 `x64`로 설정
3. `WpfOnnxWinUI3Demo.WpfApp`을 시작 프로젝트로 설정
4. F5로 실행

> ⚠️ **주의**: `dotnet build` 명령은 Windows App SDK의 PRI 생성 도구 문제로 인해 작동하지 않습니다.
> Visual Studio MSBuild를 사용해야 합니다.

### 4. 실행

```
src\WpfOnnxWinUI3Demo.WpfApp\bin\x64\Release\net10.0-windows10.0.22621.0\WpfOnnxWinUI3Demo.WpfApp.exe
```

## 사용 방법

1. **Select Image** 버튼 클릭하여 이미지 선택
2. **Classify** 버튼 클릭하여 분류 실행
3. Top 10 예측 결과와 추론 시간 확인

## 기술 스택

- **WPF**: 호스트 애플리케이션
- **WinUI 3**: Fluent Design UI 컨트롤
- **XAML Islands**: WPF-WinUI 3 통합
- **ONNX Runtime DirectML**: GPU 가속 추론
- **CommunityToolkit.Mvvm**: MVVM 패턴
- **SixLabors.ImageSharp**: 이미지 전처리

## 아키텍처 노트

### XAML Islands 구현

WPF에서 WinUI 3 컨트롤을 호스팅하기 위해 다음 구성요소를 사용합니다:

1. **DispatcherQueueController**: Win32 스레드용 디스패처 큐 생성
2. **WindowsXamlManager**: WinUI 3 XAML 호스팅 인프라 초기화
3. **DesktopWindowXamlSource**: WinUI 3 콘텐츠를 Win32 윈도우에 호스팅
4. **HwndHost**: WPF에서 Win32 윈도우를 호스팅하는 컨테이너

### WinUI 3 컨트롤 생성 방식

WPF XAML 파서와 WinUI XAML 파서 충돌을 피하기 위해 WinUI 3 컨트롤을 **순수 C# 코드로 생성**합니다.
XAML 파일을 사용하지 않고 프로그래밍 방식으로 UI를 구성합니다.

## 주의 사항

1. **x64 플랫폼 필수**: Any CPU로 빌드하면 실행되지 않습니다.
2. **Visual Studio MSBuild 필수**: dotnet CLI로는 빌드할 수 없습니다.
3. **Unpackaged 앱**: MSIX 패키징 없이 실행됩니다.
4. **DirectML 폴백**: DirectML이 지원되지 않는 환경에서는 자동으로 CPU 추론으로 전환됩니다.

## 참고 자료

- [WPF XAML Islands WinUI3 Sample](https://github.com/castorix/WPF_XAML_Islands_WinUI3)
- [WindowsAppSDK Discussion #3940](https://github.com/microsoft/WindowsAppSDK/discussions/3940)
- [ONNX Runtime WinUI Tutorial](https://learn.microsoft.com/windows/ai/models/get-started-onnx-winui)

## 라이선스

MIT License
