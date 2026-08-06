# MewUIPixelAnimation

터미널 UI 라이브러리 [MewUI](https://www.nuget.org/packages/Aprillz.MewUI)로
80×60 픽셀 그리드(Label 4,800개)를 그려 스틱맨 걷기 애니메이션을 재생하는 데모.
프레임률과 렌더 시간을 화면에 함께 표시해 MewUI의 대량 위젯 갱신 성능을 눈으로 확인한다.

## 요구 사항

- .NET 10 SDK
- Windows 터미널 (24비트 컬러 지원 권장)

## 실행

```
dotnet run --project MewUIPixelAnimation.csproj
```

## 구성

| 파일 | 역할 |
|---|---|
| `Program.cs` | 애니메이션 루프, 성능 측정 |
| `PixelGrid.cs` | 80×60 Label 그리드 |
| `StickmanFrames.cs` | 스틱맨 스프라이트 프레임 데이터 |

`PublishAot` + `TrimMode=full`로 설정되어 있어 `dotnet publish`로 단일 네이티브 실행 파일을 만들 수 있다.
