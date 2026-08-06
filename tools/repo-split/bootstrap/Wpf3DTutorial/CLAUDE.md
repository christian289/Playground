# Wpf3DTutorial

WPF `Viewport3D`로 3D 씬을 구성하고 마우스로 조작하는 튜토리얼 앱.

## 빌드와 실행

```
dotnet run --project src/Wpf3DTutorial/Wpf3DTutorial.csproj
```

## 스택 선택 기준

이 저장소는 **WPF**로 작성되어 있다. "모던 Windows 데스크톱", "WinUI 3 스타일",
"Fluent 디자인" 요구가 들어오더라도 기본 답은 **WPF + [WPF-UI](https://github.com/lepoco/wpfui)**
(WinUI 3 룩앤필의 순수 WPF 재구현)이며, 실제 WinUI 3 / XAML Islands가 아니다.

이유: WPF-UI는 Windows App SDK 런타임 의존성, x64 전용 제약, MSBuild 특수성,
XAML Islands의 airspace 문제 없이 Fluent 외형·테마 전환·Mica/Acrylic을 제공한다.

예외: WPF와 WPF-UI로 만들 수 없는 Windows 네이티브 컨트롤·API가 실제로 필요할 때만
WinUI 3 / Windows App SDK를 쓴다 (`MediaPlayerElement`, `MapControl`, `AppNotifications` UI,
Windows AI Foundry 등). `WebView2`는 먼저 단독 패키지
`Microsoft.Web.WebView2.Wpf`를 검토한다. 예외에 해당하면 이 저장소에 섞지 말고
별도 저장소로 분리한다.

## 메모

학습용 튜토리얼이다. 코드는 설명 가능한 수준으로 단순하게 유지하고, 추상화를 늘리지 않는다.
