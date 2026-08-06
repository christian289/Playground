# PretextWpf

[pretext](https://github.com/chenglou/pretext)(TypeScript 텍스트 레이아웃 엔진)를
WPF로 포팅한 라이브러리와, 그 위에 올린 데모 앱.

## 빌드와 실행

```
dotnet build PretextWpf.slnx
dotnet test tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj
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

상류 pretext 이식본이다. 상류와의 차분 테스트가 있으므로 `src/Pretext.Wpf` 로직을 고칠 때는 `upstream-manifest.json`의 대응 관계를 먼저 확인한다. 라이브러리를 임의로 "개선"하지 말 것 — 상류 동작 재현이 목적이다.
