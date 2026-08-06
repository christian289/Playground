# PolyLab3DStudio

A beginner-friendly 3D learning studio sample built with WPF (`Viewport3D`),
implemented 1:1 from the Claude Design file `폴리랩 3D 스튜디오.dc.html`
(project `claude.ai/design/p/d395c492-f9fd-41a2-a608-c4e160048d7f`).
It follows this repository's WPF coding rules (CommunityToolkit.Mvvm +
GenericHost, UI-independent ViewModels, `net10.0-windows`).

## 빌드와 실행

```
dotnet build PolyLab3DStudio.slnx
dotnet run --project src/PolyLab3DStudio.WpfApp/PolyLab3DStudio.WpfApp.csproj
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

`christian289/dotnet-with-claudecode`의 `samples/PolyLab3DStudio/`에서 분리해 왔다. 그 저장소의 WPF 규칙을 따른다: **CommunityToolkit.Mvvm + GenericHost**, ViewModel은 UI에 의존하지 않는다(`System.Windows` 참조 금지), 타깃은 `net10.0-windows`. NuGet 버전은 `Directory.Packages.props`에서 중앙 관리한다. README가 참조하는 "this repository's WPF coding rules"가 이 항목이다.
