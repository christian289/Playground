# WpfOnnxWinUI3Demo - 테스트 가이드

## 프로젝트 개요

WPF + WinUI 3 XAML Islands + ONNX Runtime DirectML 데모

## 테스트 전 준비사항

### 1. ONNX 모델 다운로드 (필수)

```powershell
# ResNet50 v2 모델 다운로드 (~98MB)
Invoke-WebRequest -Uri "https://github.com/onnx/models/raw/main/validated/vision/classification/resnet/model/resnet50-v2-7.onnx" -OutFile "src\WpfOnnxWinUI3Demo.WpfApp\Assets\model\resnet50-v2-7.onnx"
```

### 2. (선택) ImageNet 레이블 다운로드

```powershell
# 클래스 이름 레이블
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt" -OutFile "src\WpfOnnxWinUI3Demo.WpfApp\Assets\model\imagenet_labels.txt"
```

## 빌드 방법

### ⚠️ 중요: Visual Studio MSBuild 필수

`dotnet build`는 Windows App SDK PRI 생성 도구 문제로 작동하지 않음.

```powershell
# Developer Command Prompt for VS 2022에서 실행
cd E:\Playground\Playground\WpfOnnxWinUI3Demo
msbuild WpfOnnxWinUI3Demo.sln -p:Configuration=Release -p:Platform=x64 -restore
```

또는 Visual Studio 2022에서 직접 빌드 (F5)

## 테스트 시나리오

### 1. 기본 기능 테스트

- [ ] 앱 실행 확인
- [ ] WinUI 3 컨트롤 렌더링 확인 (Fluent Design)
- [ ] "Select Image" 버튼으로 이미지 선택
- [ ] "Classify" 버튼으로 분류 실행
- [ ] Top 10 예측 결과 표시 확인
- [ ] 추론 시간 표시 확인

### 2. DirectML/CPU 폴백 테스트

- [ ] DirectML 지원 GPU에서 "DirectML" 표시 확인
- [ ] DirectML 미지원 환경에서 "CPU" 폴백 확인

### 3. 오류 처리 테스트

- [ ] 모델 파일 없을 때 경고 메시지 확인
- [ ] 잘못된 이미지 파일 선택 시 오류 처리 확인

## 알려진 이슈

1. **.NET 10 워크로드 문제**: `dotnet workload repair` 실행이 필요할 수 있음
2. **dotnet CLI 빌드 불가**: Windows App SDK의 MrtCore.PriGen.targets 문제
3. **x64 플랫폼 전용**: Any CPU 미지원

## 실행 파일 위치

```
src\WpfOnnxWinUI3Demo.WpfApp\bin\x64\Release\net10.0-windows10.0.22621.0\WpfOnnxWinUI3Demo.WpfApp.exe
```

## 추후 개선 사항

- [ ] WinUI 3 테마 리소스 적용 (현재 기본 스타일)
- [ ] 드래그 앤 드롭 이미지 선택 지원
- [ ] 배치 이미지 분류 기능
- [ ] 다른 ONNX 모델 지원 (MobileNet, EfficientNet 등)
