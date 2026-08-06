# WpfAutomationDemo

WPF 커스텀 컨트롤에 UI Automation을 붙이는 방법을 보여주는 데모.
별점 컨트롤(`RatingControl`)에 `AutomationPeer`를 구현해, 스크린 리더와
UI 자동화 테스트 도구가 값을 읽고 바꿀 수 있게 한다.

## 요구 사항

- .NET 10 SDK
- Windows

## 실행

```
dotnet run --project src/WpfAutomationDemo/WpfAutomationDemo.csproj
```

## 구성

| 파일 | 역할 |
|---|---|
| `Controls/RatingControl.cs` | 별점 컨트롤. `Value` 의존 속성 |
| `Controls/RatingControlAutomationPeer.cs` | `IRangeValueProvider` 노출 |
| `Themes/Generic.xaml` | 기본 스타일 |

`WpfApp1/`은 초기 스캐폴딩 잔재이며 `src/WpfAutomationDemo/`가 실제 데모다.

## 확인 방법

앱 실행 후 Windows SDK의 **Accessibility Insights** 또는 **Inspect.exe**로
별점 컨트롤을 선택하면 `RangeValue` 패턴이 노출되는 것을 볼 수 있다.
