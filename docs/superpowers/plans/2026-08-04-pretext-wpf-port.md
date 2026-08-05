# Pretext WPF 포팅 구현 계획

> **작업 에이전트용:** 이 계획을 실행할 때는 `subagent-driven-development` 스킬을 사용해 작업별로 구현·검토한다.

**목표:** `chenglou/pretext` 기준 커밋 `ac49b09b7d83ede19581fa94a8b892b07d309baf`의 텍스트 준비·줄바꿈·rich-inline 기능을 WPF/BCL 전용 C# 라이브러리로 포팅하고, 원본 9개 데모를 하나의 WPF-UI 갤러리 앱에서 오프라인 실행한다.

**아키텍처:** `Pretext.Wpf`는 `TextFormatter`, `TextLine`, `GlyphRun`, `StringInfo`, WPF/BCL만 사용하는 AnyCPU `net10.0-windows` 라이브러리다. `Prepare`가 정규화·Unicode 분석·WPF shaping/측정 결과를 불변 배열로 컴파일하고, 모든 `Layout*` API는 그 숫자 배열만 순회한다. `Pretext.Wpf.Demo`는 WPF-UI 셸, CommunityToolkit.Mvvm 상태, Markdig AST 변환, 재사용 drawing surface를 사용한다. 테스트·benchmark·데모 의존성은 핵심 DLL 밖에 둔다.

**기술 스택:** .NET 10, WPF, `System.Windows.Media.TextFormatting`, WPF-UI 4.3.0, CommunityToolkit.Mvvm 8.4.2, Markdig 1.3.2, xUnit v3 3.2.2, Microsoft.NET.Test.Sdk 18.8.1, BenchmarkDotNet 0.15.8.

**기준 문서:**
- 승인 설계: `docs/superpowers/specs/2026-08-04-pretext-wpf-port-design.md`
- 원본 저장소: <https://github.com/chenglou/pretext>
- 원본 라이선스: MIT
- Microsoft WPF `TextFormatter` 샘플 기준 커밋 `71759b6e713098672a99333c8df4358f162e48db`: <https://github.com/microsoft/WPF-Samples/tree/71759b6e713098672a99333c8df4358f162e48db/PerMonitorDPI/TextFormatting>

---

## 공통 실행 규칙

1. 각 작업에서 테스트 코드를 쓰기 전에 `.claude/test-inventory.md`의 해당 행을 `Planned`에서 `Active`로 바꾼다.
2. 테스트 이름은 `Method_Scenario_Expected` 형식, 분류는 Happy/Boundary/Error 중 하나다.
3. 기능 코드는 반드시 실패하는 테스트를 먼저 확인한 뒤 최소 구현으로 통과시킨다.
4. 개별 작업 중에는 해당 프로젝트/필터만 실행한다. 전체 build/test/format은 Task 21에서 한 번 실행한다.
5. `Pretext.Wpf`에는 `PackageReference`, 다른 프로젝트 참조, JavaScript 런타임, WebView2를 추가하지 않는다.
6. 원본 동작을 옮길 때는 기준 커밋의 `src/analysis.ts`, `src/measurement.ts`, `src/line-break.ts`, `src/line-text.ts`, `src/layout.ts`, `src/rich-inline.ts`, `src/bidi.ts`, `src/generated/bidi-data.ts`를 기준으로 한다. 최신 `main`의 후속 변경을 섞지 않는다.
7. ViewModel에는 `System.Windows*` 타입을 노출하지 않는다. WPF 타입은 View/control/composition root에만 둔다.
8. `OnRender` 안에서 Brush/Pen/Geometry를 생성하지 않는다. 생성자 또는 리소스 초기화에서 만들고 가능한 `Freezable`은 `Freeze()`한다.
9. 애니메이션은 `IDemoLifecycle.Activate/Deactivate`로 구독을 정확히 대칭 해제한다.
10. 각 작업 마지막에 그 Task의 `Files`에 열거된 실제 경로만 명시적으로 stage하고 해당 Step의 구체적 commit 명령을 실행한다. 예상하지 못한 사용자 변경은 포함하지 않는다.
11. 작업 디렉터리를 섞지 않는다. Task 0의 checkout 명령과 모든 `git add`/`git commit` 블록은 monorepo root에서, 모든 `dotnet`/formatter/앱 실행 블록은 `PretextWpf/`에서 실행한다. 각 명령의 현재 상대 경로는 이 규칙을 전제로 하며 두 종류 블록을 cwd 변경 없이 이어 붙이지 않는다.
12. 모든 custom drawing surface는 `OnDpiChanged`에서 `VisualTreeHelper.GetDpi(this).PixelsPerDip` 기반 effective style/measurement/glyph cache를 갱신한다. DPI를 ViewModel 상태로 보내거나 1.0으로 고정하지 않는다.

---

## 최종 파일 구조

```text
PretextWpf/
├── .gitignore
├── global.json
├── Directory.Build.props
├── PretextWpf.slnx
├── LICENSE-PRETEXT
├── LICENSE-WPF-SAMPLES
├── README.md
├── THIRD-PARTY-NOTICES.txt
├── upstream-manifest.json
├── src/
│   ├── Pretext.Wpf/
│   │   ├── Pretext.Wpf.csproj
│   │   ├── TextLayoutEngine.cs
│   │   ├── RichInlineLayoutEngine.cs
│   │   ├── Public/
│   │   │   ├── LayoutModels.cs
│   │   │   ├── PrepareOptions.cs
│   │   │   ├── PreparedText.cs
│   │   │   ├── PreparedRichInline.cs
│   │   │   ├── RichInlineModels.cs
│   │   │   └── TextStyle.cs
│   │   ├── Internal/
│   │   │   ├── Analysis/
│   │   │   │   ├── GraphemeMap.cs
│   │   │   │   ├── SegmentBreakKind.cs
│   │   │   │   ├── TextAnalysis.cs
│   │   │   │   ├── TextAnalyzer.cs
│   │   │   │   ├── UnicodeClassifier.cs
│   │   │   │   └── WordSegmenter.cs
│   │   │   ├── Bidi/
│   │   │   │   ├── BidiData.g.cs
│   │   │   │   └── BidiLevelResolver.cs
│   │   │   ├── Layout/
│   │   │   │   ├── LineTextMaterializer.cs
│   │   │   │   ├── LineWalker.cs
│   │   │   │   └── PreparedCore.cs
│   │   │   ├── Measurement/
│   │   │   │   ├── MeasuredChunk.cs
│   │   │   │   ├── MeasurementCache.cs
│   │   │   │   ├── PlainTextSource.cs
│   │   │   │   ├── PretextParagraphProperties.cs
│   │   │   │   ├── PretextRunProperties.cs
│   │   │   │   ├── SegmentMetrics.cs
│   │   │   │   ├── WpfBreakOpportunityExtractor.cs
│   │   │   │   └── WpfTextMeasurer.cs
│   │   │   └── RichInline/
│   │   │       ├── PreparedRichInlineCore.cs
│   │   │       └── RichInlineWalker.cs
│   │   └── Properties/AssemblyInfo.cs
│   └── Pretext.Wpf.Demo/
│       ├── Pretext.Wpf.Demo.csproj
│       ├── App.xaml
│       ├── App.xaml.cs
│       ├── MainWindow.xaml
│       ├── MainWindow.xaml.cs
│       ├── Controls/
│       │   ├── DynamicLayoutSurface.cs
│       │   ├── EditorialSurface.cs
│       │   ├── JustificationSurface.cs
│       │   ├── PretextTextSurface.cs
│       │   ├── RichInlineSurface.cs
│       │   ├── TextLineDrawingBuilder.cs
│       │   ├── VariableAsciiSurface.cs
│       │   ├── VirtualizingMasonryPanel.cs
│       │   └── VirtualizingPredictedStackPanel.cs
│       ├── Infrastructure/
│       │   ├── DemoErrorState.cs
│       │   ├── DemoExecutionGuard.cs
│       │   ├── DemoRegistry.cs
│       │   ├── IDemoLifecycle.cs
│       │   ├── SafeUriLauncher.cs
│       │   └── ViewModelBase.cs
│       ├── Models/
│       │   ├── ChatModels.cs
│       │   ├── DemoDescriptor.cs
│       │   ├── MasonryCard.cs
│       │   └── RichTextDocument.cs
│       ├── Resources/
│       │   ├── Colors.xaml
│       │   ├── Controls.xaml
│       │   ├── Icons.xaml
│       │   └── Typography.xaml
│       ├── Assets/
│       │   ├── Text/editorial.txt
│       │   ├── Text/markdown-chat.md
│       │   ├── Data/shower-thoughts.json
│       │   └── Data/verification-summary.json
│       ├── Services/
│       │   ├── JustificationLayoutService.cs
│       │   ├── MarkdownDocumentParser.cs
│       │   ├── MarkdownLayoutService.cs
│       │   └── MasonryLayoutService.cs
│       ├── ViewModels/
│       │   ├── MainWindowViewModel.cs
│       │   └── Demos/*.cs
│       ├── Views/
│       │   ├── StatusView.xaml(.cs)
│       │   └── Demos/*.xaml(.cs)
├── tests/
│   └── Pretext.Wpf.Tests/
│       ├── Pretext.Wpf.Tests.csproj
│       ├── Properties/AssemblyInfo.cs
│       ├── Architecture/*.cs
│       ├── Analysis/*.cs
│       ├── Bidi/*.cs
│       ├── PublicApi/*.cs
│       ├── Layout/*.cs
│       ├── Measurement/*.cs
│       ├── RichInline/*.cs
│       ├── Demo/*.cs
│       ├── Oracle/*.cs
│       ├── TestSupport/*.cs
│       └── TestData/*
└── benchmarks/
    └── Pretext.Wpf.Benchmarks/
        ├── Pretext.Wpf.Benchmarks.csproj
        ├── Program.cs
        ├── TextLayoutBenchmarks.cs
        └── VerificationSummaryWriter.cs
```

---

### Task 0: 원본 commit 고정과 provenance manifest 생성

**Files:**
- Create: `PretextWpf/.gitignore`
- Create: `PretextWpf/upstream-manifest.json`
- Temporary only: `PretextWpf/.upstream/pretext/`
- Temporary only: `PretextWpf/.upstream/wpf-samples/`

**Step 1: 임시/생성 산출물을 제외한다**

`PretextWpf/.gitignore`:

```gitignore
.upstream/
.vs/
artifacts/
TestResults/
**/bin/
**/obj/
BenchmarkDotNet.Artifacts/
```

**Step 2: 두 기준 commit을 sparse detached checkout으로 가져온다**

```powershell
git clone --filter=blob:none --no-checkout https://github.com/chenglou/pretext .\PretextWpf\.upstream\pretext
git -C .\PretextWpf\.upstream\pretext sparse-checkout init --cone
git -C .\PretextWpf\.upstream\pretext sparse-checkout set src pages corpora accuracy benchmarks
git -C .\PretextWpf\.upstream\pretext fetch origin ac49b09b7d83ede19581fa94a8b892b07d309baf
git -C .\PretextWpf\.upstream\pretext checkout --detach ac49b09b7d83ede19581fa94a8b892b07d309baf

git clone --filter=blob:none --no-checkout https://github.com/microsoft/WPF-Samples .\PretextWpf\.upstream\wpf-samples
git -C .\PretextWpf\.upstream\wpf-samples sparse-checkout init --cone
git -C .\PretextWpf\.upstream\wpf-samples sparse-checkout set PerMonitorDPI/TextFormatting
git -C .\PretextWpf\.upstream\wpf-samples fetch origin 71759b6e713098672a99333c8df4358f162e48db
git -C .\PretextWpf\.upstream\wpf-samples checkout --detach 71759b6e713098672a99333c8df4358f162e48db

$pretextActual = git -C .\PretextWpf\.upstream\pretext rev-parse HEAD
$samplesActual = git -C .\PretextWpf\.upstream\wpf-samples rev-parse HEAD
if ($pretextActual -ne "ac49b09b7d83ede19581fa94a8b892b07d309baf") { throw "Unexpected Pretext commit: $pretextActual" }
if ($samplesActual -ne "71759b6e713098672a99333c8df4358f162e48db") { throw "Unexpected WPF-Samples commit: $samplesActual" }
```

Expected: 두 `HEAD`가 정확히 기준 commit이고 working tree가 clean이다.

**Step 3: provenance manifest를 작성한다**

JSON에는 두 entry의 `repository`, `commit`, `licensePath`, Pretext의 `packageVersion`, `capturedUtc`, `copiedFiles`를 둔다. 각 `copiedFiles` entry는 `sourceRepository`, repository-relative `sourcePath`, `sourceSha256`, 의도한 `destinationPath`, `copyMode`(`exact` 또는 `adapted`)를 가진다. Pretext engine/generated bidi/corpus/9개 demo source·asset/license와 실제 파생한 WPF sample source/license만 기록한다. hash는 해당 detached checkout의 byte를 기준으로 계산하며 Task 20에서 destination과 다시 대조한다.

**Step 4: provenance 파일만 커밋한다**

```powershell
git add PretextWpf/.gitignore PretextWpf/upstream-manifest.json
git commit -m "pretext-wpf: pin upstream source provenance"
```

임시 checkout은 commit하지 않으며 Task 20 audit가 끝날 때 둘 다 삭제한다.

---

### Task 1: 솔루션, 프로젝트, 의존성 경계 구성

**Files:**
- Create: `PretextWpf/global.json`
- Create: `PretextWpf/Directory.Build.props`
- Create: `PretextWpf/PretextWpf.slnx`
- Create: `PretextWpf/src/Pretext.Wpf/Pretext.Wpf.csproj`
- Create: `PretextWpf/src/Pretext.Wpf/Properties/AssemblyInfo.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Pretext.Wpf.Demo.csproj`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Properties/AssemblyInfo.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj`
- Create: `PretextWpf/benchmarks/Pretext.Wpf.Benchmarks/Pretext.Wpf.Benchmarks.csproj`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Architecture/CoreDependencyPolicy.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Architecture/CoreDependencyTests.cs`
- Create: `PretextWpf/.claude/test-inventory.md`

**Step 1: SDK와 공통 빌드 정책을 작성한다**

`global.json`은 설치 확인된 SDK를 고정한다.

```json
{
  "sdk": {
    "version": "10.0.301",
    "rollForward": "latestPatch",
    "allowPrerelease": false
  }
}
```

`Directory.Build.props`:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0-windows</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
    <PlatformTarget>AnyCPU</PlatformTarget>
    <Deterministic>true</Deterministic>
  </PropertyGroup>
</Project>
```

**Step 2: 핵심 프로젝트와 build-time 의존성 차단 규칙을 작성한다**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <UseWPF>true</UseWPF>
    <RootNamespace>Pretext.Wpf</RootNamespace>
    <AssemblyName>Pretext.Wpf</AssemblyName>
    <IsPackable>true</IsPackable>
  </PropertyGroup>

  <Target Name="RejectExternalCoreReferences" BeforeTargets="ResolveReferences">
    <Error Condition="'@(PackageReference)' != ''"
           Text="Pretext.Wpf must not contain PackageReference items." />
    <Error Condition="'@(ProjectReference)' != ''"
           Text="Pretext.Wpf must not contain ProjectReference items." />
  </Target>
</Project>
```

`AssemblyInfo.cs`에는 `[assembly: ThemeInfo(ResourceDictionaryLocation.None, ResourceDictionaryLocation.None)]`와 테스트용 `[assembly: InternalsVisibleTo("Pretext.Wpf.Tests")]`를 둔다.

**Step 3: 데모·테스트·benchmark 프로젝트를 작성한다**

- 데모: `Microsoft.NET.Sdk`, `OutputType=WinExe`, `UseWPF=true`, 핵심 `ProjectReference`, `WPF-UI 4.3.0`, `CommunityToolkit.Mvvm 8.4.2`, `Markdig 1.3.2`.
- 테스트: `UseWPF=true`, 핵심 `ProjectReference`, `Microsoft.NET.Test.Sdk 18.8.1`, `xunit.v3 3.2.2`.
- benchmark: `UseWPF=true`, 핵심 `ProjectReference`, `BenchmarkDotNet 0.15.8`, `OutputType=Exe`.
- 데모 외 프로젝트에는 WPF-UI/Markdig/MVVM 참조가 없어야 한다.

테스트 assembly에는 `[assembly: CollectionBehavior(DisableTestParallelization = true)]`를 두어 process-global analysis/measurement cache reset과 STA WPF oracle이 collection 간 경쟁하지 않게 한다.

**Step 4: `.slnx`를 작성한다**

```xml
<Solution>
  <Folder Name="/src/">
    <Project Path="src/Pretext.Wpf/Pretext.Wpf.csproj" />
    <Project Path="src/Pretext.Wpf.Demo/Pretext.Wpf.Demo.csproj" />
  </Folder>
  <Folder Name="/tests/">
    <Project Path="tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj" />
  </Folder>
  <Folder Name="/benchmarks/">
    <Project Path="benchmarks/Pretext.Wpf.Benchmarks/Pretext.Wpf.Benchmarks.csproj" />
  </Folder>
</Solution>
```

**Step 5: 테스트 inventory를 먼저 작성한다**

표 열은 `ID | 분류 | 테스트 | 보호 계약 | 상태`다. 이 계획의 테스트를 `ARCH-*`, `AN-*`, `BIDI-*`, `MEAS-*`, `LAY-*`, `RICH-*`, `ORACLE-*`, `APP-*`로 모두 등록하고 최초 상태는 `Planned`로 둔다. 자동 UI 테스트는 만들지 않으므로 `APP-*`는 수동 smoke 체크 행으로 분리한다.

**Step 6: 실패하는 architecture 정책 테스트를 작성한다**

`CoreDependencyPolicy`를 아직 만들지 않은 상태에서 다음 테스트가 컴파일 실패하는 것을 확인한다.

```csharp
[Fact]
[Trait("Category", "Error")]
public void IsAllowed_FrameworkAndWpfAssemblies_ExpectedPolicy()
{
    Assert.True(CoreDependencyPolicy.IsAllowed("System.Runtime"));
    Assert.True(CoreDependencyPolicy.IsAllowed("PresentationCore"));
    Assert.False(CoreDependencyPolicy.IsAllowed("Markdig"));
}
```

실행:

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter IsAllowed_FrameworkAndWpfAssemblies_ExpectedPolicy
```

Expected: `CS0103` 또는 `CS0246`로 실패.

**Step 7: 정책 helper와 DLL metadata 검사를 구현한다**

허용 이름은 `System`, `System.*`, `Microsoft.CSharp`, `Microsoft.Win32.*`, `WindowsBase`, `PresentationCore`, `PresentationFramework`, `System.Xaml`, `netstandard`, `mscorlib`로 제한한다. `Assembly core = Assembly.Load(new AssemblyName("Pretext.Wpf"));` 뒤 `core.GetReferencedAssemblies()`를 검사한다. `Microsoft.*` 전체 허용이나 알 수 없는 참조 fallback은 두지 않는다.

**Step 8: 프로젝트 복원과 architecture 테스트를 확인한다**

```powershell
dotnet restore .\PretextWpf.slnx
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~Architecture"
```

Expected: architecture 테스트 모두 통과.

**Step 9: 커밋한다**

```powershell
git add PretextWpf/global.json PretextWpf/Directory.Build.props PretextWpf/PretextWpf.slnx PretextWpf/src/Pretext.Wpf/Pretext.Wpf.csproj PretextWpf/src/Pretext.Wpf/Properties/AssemblyInfo.cs PretextWpf/src/Pretext.Wpf.Demo/Pretext.Wpf.Demo.csproj PretextWpf/tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj PretextWpf/tests/Pretext.Wpf.Tests/Properties/AssemblyInfo.cs PretextWpf/tests/Pretext.Wpf.Tests/Architecture PretextWpf/benchmarks/Pretext.Wpf.Benchmarks/Pretext.Wpf.Benchmarks.csproj PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: scaffold solution and dependency boundaries"
```

---

### Task 2: 공개 value/model 타입과 입력 불변식 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Public/TextStyle.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Public/PrepareOptions.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Public/LayoutModels.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Public/RichInlineModels.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Guard.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/PublicApi/PublicContractTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: inventory 행을 활성화하고 실패 테스트를 작성한다**

다음을 검증한다.

- `TextStyle`은 null font/culture, 0/NaN/Infinity font size, 0/NaN/Infinity DPI를 거부한다.
- neutral culture와 `InvariantCulture`는 유효하며 그대로 cache key와 WPF run properties에 전달된다.
- undefined `FlowDirection`, `TextFormattingMode`, `WhiteSpaceMode`, `WordBreakMode`, `RichInlineBreakMode` enum 값은 `ArgumentOutOfRangeException`.
- caller가 mutable `CultureInfo`를 전달해도 이후 변경이 style/cache key를 바꾸지 않도록 read-only clone을 저장한다.
- `PrepareOptions`는 NaN/Infinity letter spacing만 거부하고 finite 음수/0/양수를 허용한다.
- `LayoutCursor`, `LayoutResult`, `LineStats`, `LayoutLineRange`는 value type이다.
- rich item은 null text/style과 음수/NaN/Infinity extra width를 거부한다. letter spacing은 non-finite만 거부하고 finite 음수를 허용한다.

대표 실패 테스트:

```csharp
[Fact]
[Trait("Category", "Error")]
public void TextStyle_ZeroFontSize_ThrowsArgumentOutOfRangeException()
{
    Assert.Throws<ArgumentOutOfRangeException>(() => new TextStyle(
        new FontFamily("Segoe UI"),
        0,
        FontWeights.Normal,
        FontStyles.Normal,
        FontStretches.Normal,
        CultureInfo.GetCultureInfo("en-US"),
        FlowDirection.LeftToRight,
        1,
        TextFormattingMode.Ideal));
}
```

Expected: 타입 부재로 컴파일 실패.

**Step 2: 승인 설계의 공개 계약을 그대로 구현한다**

- `TextStyle`은 설계 문서 255–264행의 9개 속성을 가진 sealed record다. explicit constructor에서 검증한다.
- constructor는 `CultureInfo.ReadOnly((CultureInfo)culture.Clone())`을 저장하며 원본 culture 변경이 immutable contract를 깨지 않게 한다.
- `WhiteSpaceMode`, `WordBreakMode`, `PrepareOptions`는 설계 문서 266–281행과 같다.
- layout value model과 delegate는 설계 문서 210–230행과 같다. prepared handle 타입은 실제 core와 함께 Task 6에서 만든다.
- rich value/model과 delegate는 설계 문서 288–336행과 같다. `PreparedRichInline`은 실제 core와 함께 Task 9에서 만든다.

`TextStyle`, `PrepareOptions`, `RichInlineItem`은 generated primary constructor가 검증을 우회하지 않도록 explicit constructor와 get-only property를 사용한다. `default(PrepareOptions)`는 승인된 기본값과 동일해야 한다.

`Guard`의 숫자 검증은 한 곳으로 모은다.

```csharp
internal static double PositiveFinite(double value, string parameterName)
{
    if (!double.IsFinite(value) || value <= 0)
    {
        throw new ArgumentOutOfRangeException(parameterName, value, "Value must be finite and greater than zero.");
    }

    return value;
}
```

**Step 3: 공개 계약 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~PublicContractTests"
```

Expected: 모두 통과.

**Step 4: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Public PretextWpf/src/Pretext.Wpf/Internal/Guard.cs PretextWpf/tests/Pretext.Wpf.Tests/PublicApi PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: define public text layout contracts"
```

---

### Task 3: 공백, grapheme, word/script 분석 포팅

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Analysis/SegmentBreakKind.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Analysis/TextAnalysis.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Analysis/GraphemeMap.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Analysis/UnicodeClassifier.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Analysis/WordSegmenter.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Analysis/TextAnalyzer.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Analysis/TextAnalyzerTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: 원본 invariant를 테스트로 먼저 옮긴다**

다음 fixture를 각각 Happy/Boundary 행으로 inventory에 활성화한다.

```text
"  hello\t\n world  " normal   -> "hello world"
" a  b\r\nc "        pre-wrap -> 입력 space와 hard break 보존
"ภาษาไทย"          normal   -> grapheme emergency 후보 존재
"你好，world 42"    normal   -> CJK/구두점/Latin/숫자 kind 보존
"foo\u200Bbar"      normal   -> zero-width-break
"extra\u00ADordinary" normal -> soft-hyphen
"a\tb"             pre-wrap -> tab
"한글 ABC 123"      keep-all -> Hangul 내부 일반 break 금지
```

대표 테스트:

```csharp
[Theory]
[InlineData("  hello\t\n world  ", "hello world")]
[InlineData("a   b", "a b")]
[Trait("Category", "Happy")]
public void Analyze_NormalWhitespace_CollapsesLikeCss(string input, string expected)
{
    TextAnalysis result = TextAnalyzer.Analyze(
        input,
        CultureInfo.GetCultureInfo("en-US"),
        WhiteSpaceMode.Normal,
        WordBreakMode.Normal);
    Assert.Equal(expected, result.Normalized);
}
```

Expected: 분석 타입 부재로 실패.

**Step 2: grapheme 경계를 구현한다**

`StringInfo.GetTextElementEnumerator`로 UTF-16 시작 offset을 한 번만 만든다. `GraphemeMap`은 `int[] Starts`, `int Count`, `GetTextElement(int)`와 prefix slice만 제공한다. surrogate pair, combining mark, ZWJ emoji를 char 단위로 자르지 않는다.

**Step 3: Unicode 분류를 구현한다**

`Rune.GetUnicodeCategory`와 원본 정규식 의미를 다음 predicate로 옮긴다.

- `IsCjk`: Han, Hiragana, Katakana 및 CJK punctuation 범위.
- `IsHangul`: Jamo/Compatibility Jamo/Syllables.
- `IsOpeningPunctuation`, `IsClosingPunctuation`, `IsDashOrConnector`.
- `IsWordLike`: Letter, DecimalDigitNumber, LetterNumber, OtherNumber, Mark, ConnectorPunctuation.
- `IsEmojiCandidate`: Extended pictographic가 필요한 범위와 regional indicator/keycap/variation selector.
- whitespace 특수 kind: space, preserved-space, tab, hard-break, zero-width-break, soft-hyphen.

범위 상수는 named tuple 배열로 두고 모든 lookup은 binary search 또는 작은 고정 범위 비교로 한다. regex와 LINQ는 hot analysis loop에서 사용하지 않는다.

**Step 4: deterministic base segmenter와 native-dictionary marker를 구현한다**

`CultureInfo`를 입력받아 다음 규칙으로 browser-independent base pieces를 만든다.

1. grapheme 단위로 순회한다.
2. 특수 whitespace/break 문자는 각각 독립 piece다.
3. Latin/Greek/Cyrillic/Arabic/Hebrew/Devanagari letter와 mark는 같은 script의 연속 run으로 합친다.
4. decimal, 내부 `.`/`,`/`:`/`/`/`@`/`#`/`%`는 원본 숫자·URL·symbol merge 규칙이 판단할 수 있도록 인접 run으로 보존한다.
5. Han/Hiragana/Katakana/Hangul grapheme는 개별 word-like piece로 내보내고 이후 keep-all merge가 결정한다.
6. Thai/Lao/Khmer/Myanmar의 연속 letter/mark는 grapheme emergency 후보를 유지한 `NativeWordBreakRun(start, length, culture)`으로 표시한다. 이 run의 preferred word boundary는 추측하지 않고 Task 5의 WPF extractor가 채운다.
7. emoji ZWJ sequence는 `StringInfo`가 만든 하나의 grapheme로 유지한다.

**Step 5: `analysis.ts`의 후처리 순서를 그대로 포팅한다**

기준 파일의 함수 순서를 유지한다.

```text
normalizeWhitespaceNormal / normalizeWhitespacePreWrap
buildBaseSegmentation
mergeDecimalRuns
mergeUrlAndSymbolRuns
mergeArabicMarks
mergePunctuation
applyCjkKinsoku
mergeKeepAllTextSegments
buildMergedSegmentation
```

C# `TextAnalysis`는 normalized string과 병렬 배열 `string[] Texts`, `bool[] IsWordLike`, `SegmentBreakKind[] Kinds`, `int[] Starts`, 그리고 `NativeWordBreakRun[]`을 보관한다. 배열 길이와 native run 범위 불일치가 생성될 수 없도록 factory 하나에서만 생성한다.

**Step 6: 불변 분석 cache와 초기화를 구현한다**

`ConcurrentDictionary<AnalysisKey, Lazy<TextAnalysis>>`를 사용하고 key에는 원문, culture name, whitespace mode, word-break mode를 모두 포함한다. cache에 넣기 전에 만든 병렬 배열은 이후 변경하지 않는다. `TextAnalyzer.ClearCache()`는 새 dictionary를 `Interlocked.Exchange`해 기존 reader를 방해하지 않고 다음 prepare부터 새 cache를 쓰게 한다.

**Step 7: 분석 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~Analysis"
```

Expected: 모든 공백/Unicode 분석 테스트 통과.

**Step 8: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/Analysis PretextWpf/tests/Pretext.Wpf.Tests/Analysis PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port whitespace and unicode analysis"
```

---

### Task 4: bidi metadata와 원본 생성 데이터 포팅

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Bidi/BidiData.g.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Bidi/BidiLevelResolver.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Bidi/BidiLevelResolverTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: bidi 실패 테스트를 작성한다**

fixture:

- 순수 Latin + LTR -> `null` levels 최적화.
- 순수 Latin + RTL -> non-null이고 base level 1.
- `hello שלום`을 LTR/RTL 각각 계산 -> strong run과 neutral base가 flow에 맞음.
- `مرحبا 123` -> Arabic와 Arabic-context number level.
- `abc (שלום) 42` -> neutral bracket와 number resolution.
- astral emoji 앞뒤 mixed RTL -> UTF-16 offset 정렬 유지.

```csharp
[Fact]
[Trait("Category", "Boundary")]
public void ComputeSegmentLevels_MixedHebrew_ReturnsOddLevelForHebrewSegment()
{
    const string text = "hello שלום";
    sbyte[]? levels = BidiLevelResolver.ComputeSegmentLevels(text, [0, 5, 6], FlowDirection.LeftToRight);
    Assert.NotNull(levels);
    Assert.True((levels[2] & 1) == 1);
}
```

Expected: resolver 부재로 실패.

**Step 2: `src/generated/bidi-data.ts`를 C# readonly table로 기계적으로 옮긴다**

- `latin1BidiTypes` -> 256개 `BidiType` 배열.
- `nonLatin1BidiRanges` -> `readonly record struct BidiRange(int Start, int End, BidiType Type)` 배열.
- 원본 enum 문자열을 내부 `enum BidiType : byte`로 매핑한다.
- 파일 상단에 기준 저장소/커밋/원본 파일 경로와 generated 파일임을 기록한다.
- 범위를 축약하거나 현재 런타임의 culture별 결과로 대체하지 않는다.

**Step 3: `bidi.ts` 계산 단계와 explicit paragraph base level을 옮긴다**

`classifyCodePoint`, UTF-16 code unit 정렬, W1–W7, N1–N2, I1–I2 순서를 유지한다. resolver는 `FlowDirection`을 받아 LTR=0, RTL=1 base embedding level을 사용한다. LTR에서 bidi 문자가 없을 때만 `null` 최적화를 허용하며, explicit RTL은 순수 Latin/숫자/neutral text도 level 배열을 반환한다. segment level은 각 segment UTF-16 start offset의 resolved level이다. prepare는 `TextStyle.FlowDirection`을 반드시 전달하고 bidi 관련 cache key에도 flow direction을 포함한다.

**Step 4: bidi 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~Bidi"
```

Expected: 모두 통과.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/Bidi PretextWpf/tests/Pretext.Wpf.Tests/Bidi PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port bidi metadata resolver"
```

---

### Task 5: WPF 네이티브 shaping·측정 계층 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/PretextRunProperties.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/PretextParagraphProperties.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/PlainTextSource.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/SegmentMetrics.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/MeasuredChunk.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/MeasurementCache.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/WpfTextMeasurer.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Measurement/WpfBreakOpportunityExtractor.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Measurement/WpfTextMeasurerTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Measurement/FormattedTextOracle.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Measurement/WpfBreakOpportunityExtractorTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/TestSupport/TestStyles.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/TestSupport/StaTest.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: WPF 오라클과 실패 테스트를 먼저 작성한다**

`FormattedText`는 테스트 oracle로만 사용한다. 같은 `TextStyle`을 주고 `WidthIncludingTrailingWhitespace`를 비교한다.

```csharp
[Theory]
[InlineData("Hello, world")]
[InlineData("한글과 English")]
[InlineData("👩‍💻 café")]
[Trait("Category", "Happy")]
public void MeasureNaturalWidth_MixedText_MatchesFormattedText(string text)
{
    TextStyle style = TestStyles.Ideal;
    double actual = WpfTextMeasurer.MeasureNaturalWidth(text, style);
    double expected = FormattedTextOracle.MeasureNaturalWidth(text, style);
    Assert.InRange(Math.Abs(actual - expected), 0, 0.01);
}
```

DPI 1.0/1.25/1.5, Ideal/Display, LTR/RTL, neutral/invariant culture, font fallback fixture도 추가한다. 모든 WPF 호출은 `StaTest.Run` 내부에서 실행하고 그 안에서 `Thread.CurrentThread.GetApartmentState() == ApartmentState.STA`를 먼저 assert한다. `StaTest`는 dedicated `Thread`, `SetApartmentState(STA)`, `ExceptionDispatchInfo` 재throw를 사용하며 외부 STA test package를 추가하지 않는다. Expected: 측정 타입 부재로 실패.

**Step 2: `TextRunProperties`와 `TextParagraphProperties` adapter를 구현한다**

Microsoft WPF sample의 abstract member 목록을 그대로 따르되 다음 값을 사용한다.

- `Typeface = new Typeface(FontFamily, FontStyle, FontWeight, FontStretch)`
- em size/hinting size = `FontSize`
- foreground = 생성자에서 만든 frozen black brush
- culture/flow direction/formatting mode/pixelsPerDip = `TextStyle`
- wrapping = `NoWrap`, alignment = `Left`, line height = 0, indent = 0
- `DefaultIncrementalTab` = 측정된 U+0020 advance × 8
- decorations/effects/number substitution/typography = null

**Step 3: `PlainTextSource`를 구현한다**

`GetTextRun`은 유효 범위에 `TextCharacters`, 끝에서 `TextEndOfParagraph(1)`을 반환한다. `GetPrecedingText`는 입력 text의 정확한 UTF-16 범위와 style culture를 반환한다. effect index는 identity다. null field나 미구현 예외를 남기지 않는다.

**Step 4: full-context 측정을 구현한다**

1. caller thread에서 `TextFormatter.Create(style.FormattingMode)`를 생성하고 같은 호출 안에서 dispose한다.
2. `formatter.FormatMinMaxParagraphWidth(source, 0, paragraphProperties).MaxWidth`로 natural width를 얻는다.
3. hard break가 없는 단일 분석 chunk를 `MaxWidth + FontSize * 2`로 `FormatLine`한다.
4. `TextLine.GetTextBounds(start, length)`의 모든 rectangle 폭을 합산해 segment width를 구한다.
5. `GetIndexedGlyphRuns()`와 grapheme UTF-16 경계를 함께 사용해 full-context grapheme advance를 만든다. glyph cluster가 여러 grapheme를 묶으면 해당 cluster 폭을 prefix `GetTextBounds` 차이로 분배하고 마지막 grapheme에 반올림 잔차를 보정한다.
6. terminal letter spacing은 측정 폭과 분리해 layout 배열에 저장한다.
7. tab 값은 고정 glyph 폭이 아니라 style의 U+0020 advance × 8인 **tab interval**로 저장한다. line walker가 현재 line x에서 다음 interval stop까지의 advance를 계산한다.
8. soft hyphen paint 폭은 같은 style의 `-` full-context 측정값으로 저장한다.

`TextLine`, `TextFormatter`, `GlyphRun`은 method 밖에 보관하지 않는다.

**Step 5: dictionary-script preferred break를 WPF에서 추출한다**

`TextAnalysis.NativeWordBreakRuns` 각각에 `TextWrapping.WrapWithOverflow` paragraph properties를 사용한다. run의 cumulative grapheme width마다 `FormatLine`을 호출해 반환된 UTF-16 line end를 수집·deduplicate하고, run 끝을 제외한 interior legal word boundary를 preferred break로 기록한다. `WrapWithOverflow`를 써서 overlong word의 강제 grapheme break를 preferred boundary로 오인하지 않는다. 이 비교적 비싼 sweep는 Thai/Lao/Khmer/Myanmar marker에만 수행하고 full measurement cache에 함께 저장한다. grapheme emergency advances는 별도로 항상 남긴다.

여러 Thai/Lao/Khmer 문장에 대해 extractor 결과와 test-only direct `WrapWithOverflow` width sweep의 line endings가 같은지 STA 테스트로 고정한다.

**Step 6: full-context 측정 캐시를 구현한다**

`ConcurrentDictionary<MeasurementKey, Lazy<MeasuredChunk>>`를 사용한다. key는 font family source, weight/style/stretch, size, culture name, flow direction, pixels-per-DIP, formatting mode, normalized chunk text, whitespace/word-break mode, letter spacing을 모두 포함한다. `MeasuredChunk`는 그 chunk의 segment start/length, full-context `SegmentMetrics[]`, native preferred break offsets를 함께 보관한다. Arabic joining·ligature·kerning 결과가 주변 text에 의존하므로 segment text 단독 cache는 금지한다. mutable WPF 객체 자체를 key로 사용하지 않고, 배열은 생성 후 변경하지 않는다.

**Step 7: 측정 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~Measurement"
```

Expected: STA, 폭 tolerance, native word boundary, cache-key 분리 테스트 통과.

**Step 8: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/Measurement PretextWpf/tests/Pretext.Wpf.Tests/Measurement PretextWpf/tests/Pretext.Wpf.Tests/TestSupport PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: add native WPF text measurement"
```

---

### Task 6: prepared text 컴파일 파이프라인 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Layout/PreparedCore.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Layout/PrepareTests.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Public/PreparedText.cs`
- Create: `PretextWpf/src/Pretext.Wpf/TextLayoutEngine.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: 실패 테스트를 작성한다**

검증 항목:

- null text/style -> `ArgumentNullException`.
- empty text -> segment 0개, natural width 0.
- `Prepare`와 `PrepareWithSegments`의 내부 숫자 배열 동등성.
- `PrepareWithSegments`의 public segment와 bidi level 길이 정합성.
- 같은 prepared handle을 여러 reader thread에서 읽어도 값이 동일함.
- style cache key에서 DPI/culture/flow/formatting mode 분리.
- Thai/Lao/Khmer/Myanmar native dictionary marker가 generic grapheme 후보보다 앞선 preferred break로 materialize됨.

Expected: `TextLayoutEngine.Prepare*` 미구현으로 실패.

**Step 2: `PreparedCore` 배열 계약을 구현한다**

다음 병렬 배열을 보관한다.

```text
Segments
Kinds
Widths
LineEndFitAdvances
LineEndPaintAdvances
BreakableFitAdvances

PreferredBreakIndexes
SpacingGraphemeCounts
Chunks(start, end, consumedEnd)
LetterSpacing
DiscretionaryHyphenWidth
TabStopAdvance
NaturalWidth
SegmentLevels
```

hard break가 여러 개인 text의 `NaturalWidth`는 chunk 폭의 합이 아니라 가장 넓은 visual line의 폭이다. empty chunk와 마지막 hard break는 0폭 line을 보존하되 natural width를 늘리지 않는다.

constructor에서 길이와 index 범위를 검증하고, 모든 입력 배열을 clone한 뒤 더 이상 변경하지 않는다. public memory는 clone된 배열만 가리킨다.

**Step 3: `Prepare` 순서를 구현한다**

```text
Guard input
TextAnalyzer.Analyze(text, style.Culture, options.WhiteSpace, options.WordBreak)
hard-break 단위 chunk 생성
chunk별 WpfTextMeasurer full-context 측정
word-like overlong run의 grapheme fit advances 생성
line-end fit/paint advance 계산
native dictionary marker를 우선하고 generic word/grapheme fallback을 뒤에 둔 preferred break 후보 계산
bidi level 계산(segments 공개 경로만)
PreparedCore 고정
```

원본 `measurement.ts`의 Safari/Canvas engine profile 분기는 WPF에 필요 없으므로 하나의 `Wpf` profile로 정리한다. 다만 `lineFitEpsilon`은 `TextFormattingMode.Display`에서 `0.5 / PixelsPerDip`, Ideal에서 `1e-7`로 준비 데이터에 고정한다.

**Step 4: 공개 handle을 연결한다**

- `Prepare`는 segment를 public 노출하지 않는 `PreparedText`.
- `PrepareWithSegments`는 같은 compile path를 호출하고 `Segments`, optional `SegmentLevels`를 노출.
- `PreparedTextWithSegments`를 `PreparedText`로 전달해도 core identity가 유지된다.

**Step 5: prepare 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~PrepareTests"
```

Expected: 모두 통과.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/Layout/PreparedCore.cs PretextWpf/src/Pretext.Wpf/Public/PreparedText.cs PretextWpf/src/Pretext.Wpf/TextLayoutEngine.cs PretextWpf/tests/Pretext.Wpf.Tests/Layout/PrepareTests.cs PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: compile immutable prepared text"
```

---

### Task 7: 산술 line walker와 streaming cursor 포팅

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Layout/LineWalker.cs`
- Modify: `PretextWpf/src/Pretext.Wpf/TextLayoutEngine.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Layout/LineWalkerTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: line-break invariant 테스트를 작성한다**

원본 `src/layout.test.ts`에서 다음 그룹을 C# fixture로 옮긴다.

- empty, one line, exact fit, epsilon fit.
- collapsible trailing space와 preserved space.
- hard break, 연속 hard break, 마지막 hard break.
- overlong Latin/Thai/emoji run의 grapheme progress.
- tab stop은 line x=0, 1/7/8 space 뒤, wrapped line start, Ideal/Display에서 검증.
- terminal letter spacing 제외.
- CJK opening/closing punctuation과 `KeepAll`.
- zero width와 음수가 아닌 극소 width.
- cursor가 chunk 경계를 넘는 streaming continuation.
- null prepared, NaN/Infinity/negative maxWidth, negative/out-of-range cursor component는 deterministic argument exception; width 0은 유효.

대표 테스트:

```csharp
[Fact]
[Trait("Category", "Boundary")]
public void Step_ZeroWidthOverlongWord_AlwaysAdvancesCursor()
{
    PreparedTextWithSegments prepared = TestPrepare("extraordinary");
    LayoutLineRange? line = TextLayoutEngine.LayoutNextLineRange(prepared, default, 0);
    Assert.NotNull(line);
    Assert.NotEqual(line.Value.Start, line.Value.End);
}
```

Expected: layout API 미구현으로 실패.

**Step 2: `line-break.ts` helper를 같은 책임으로 옮긴다**

함수 매핑:

```text
consumesAtLineStart              -> ConsumesAtLineStart
breaksAfter                      -> BreaksAfter
normalizePreparedLineStart       -> NormalizeLineStart
findBestBreakableFit             -> FindBestBreakableFit
stepPreparedChunkLineGeometry    -> StepChunk
normalizeLineStartChunkIndexFromHint -> NormalizeChunkIndexFromHint
stepPreparedLineGeometry         -> Step
walkPreparedLineRanges           -> Walk
measurePreparedLineStats         -> MeasureStats
```

`LayoutCursor`는 public readonly 값이므로 내부에서 `MutableLayoutCursor` stack struct를 사용하고 반환 시 public cursor로 변환한다.

**Step 3: break 선택 순서를 정확히 구현한다**

1. line start에서 space/ZWSP/soft-hyphen 소비.
2. segment 전체 fit 시 누적.
3. hard break면 현재 line 종료; 빈 line도 한 번 반환.
4. overflow면 마지막 legal break를 우선.
5. breakable run이면 preferred break binary search.
6. 없으면 grapheme emergency break.
7. line이 비었으면 최소 한 grapheme/segment를 소비.
8. soft hyphen에서 끊겼을 때만 hyphen paint 폭을 더함.
9. collapsible trailing space는 fit 강제에서 제외하되 paint/continuation cursor는 원본과 동일.
10. terminal letter spacing은 마지막 painted grapheme 뒤에서 뺌.
11. tab은 `remainder = lineAdvance % TabStopInterval`, `advance = remainder가 epsilon 안에서 0이면 interval, 아니면 interval - remainder`로 다음 8-space stop까지 이동한다. wrap 뒤 새 line에서는 line advance 0부터 다시 계산한다.

layout loop 안에서 LINQ, iterator, string slice, collection 생성, WPF API 호출을 금지한다.
이 Task에서 `TextLayoutEngine.LayoutNextLineRange`를 `LineWalker.Step`에 연결해 representative streaming test와 public cursor progress 계약을 함께 완성한다.

**Step 4: walker 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~LineWalkerTests"
```

Expected: 모든 cursor와 width invariant 통과.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/Layout/LineWalker.cs PretextWpf/src/Pretext.Wpf/TextLayoutEngine.cs PretextWpf/tests/Pretext.Wpf.Tests/Layout/LineWalkerTests.cs PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port arithmetic line walker"
```

---

### Task 8: 전체 기본 API와 line materialization 완성

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/Layout/LineTextMaterializer.cs`
- Modify: `PretextWpf/src/Pretext.Wpf/TextLayoutEngine.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Layout/TextLayoutEngineTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Layout/AllocationTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: API 동등성과 실패 테스트를 작성한다**

동일한 `(prepared, width)`에서 다음 break cursor sequence가 같아야 한다.

- `Layout`
- `LayoutWithLines`
- `WalkLineRanges`
- 반복 `LayoutNextLineRange`
- 반복 `LayoutNextLine`

`MaterializeLineRange`는 leading consumed space를 제외하고, range 일부 grapheme, soft hyphen 표시를 정확히 복원해야 한다.
- null visitor와 NaN/Infinity/negative lineHeight는 deterministic exception; lineHeight 0은 유효.

**Step 2: line text materializer를 구현한다**

원본 `line-text.ts`를 포팅한다. prepared별 grapheme cache는 `ConditionalWeakTable<PreparedTextWithSegments, ConcurrentDictionary<int, string[]>>`에 두고 `ClearCaches`가 table 인스턴스를 교체한다. range-only 경로는 이 cache에 접근하지 않는다.

**Step 3: 기본 API를 모두 연결한다**

- `Layout`: line count와 `lineCount * lineHeight`; list/string 생성 없음.
- `LayoutWithLines`: 정확한 `LayoutLine` list.
- `WalkLineRanges`: delegate null 검사 후 range 전달.
- `MeasureLineStats`: count/max width만 계산.
- `MeasureNaturalWidth`: prepared 값 반환.
- `LayoutNextLineRange`: range만 반환.
- `LayoutNextLine`: range를 materialize.
- `MaterializeLineRange`: cursor bounds와 start/end 순서를 검증한 뒤 line 생성.
- `ClearCaches`: `Interlocked.Exchange`로 analysis, measurement, materialization cache 인스턴스를 교체.

`maxWidth`와 `lineHeight`는 finite이고 0 이상이어야 한다. 0 lineHeight는 line count를 유지하고 height만 0으로 만든다.

**Step 4: allocation 테스트를 구현한다**

1,000자 fixture를 prepare하고 100회 warm-up한다. 그 뒤 현재 thread의 allocated bytes를 전후 측정한다.

```csharp
long before = GC.GetAllocatedBytesForCurrentThread();
for (int i = 0; i < 1_000; i++)
{
    _ = TextLayoutEngine.Layout(prepared, 320, 24);
}
long allocated = GC.GetAllocatedBytesForCurrentThread() - before;
Assert.Equal(0, allocated);
```

별도 internal measurement counter를 `InternalsVisibleTo` 테스트에서 읽어 layout 전후가 같음을 확인한다. production 분기/conditional compilation은 추가하지 않는다.

**Step 5: layout와 allocation 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~TextLayoutEngineTests|FullyQualifiedName~AllocationTests"
```

Expected: 모두 통과, warmed `Layout` allocation 0 byte.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/Layout/LineTextMaterializer.cs PretextWpf/src/Pretext.Wpf/TextLayoutEngine.cs PretextWpf/tests/Pretext.Wpf.Tests/Layout PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: complete public layout APIs"
```

---

### Task 9: rich-inline 준비·range·materialization 포팅

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf/Internal/RichInline/PreparedRichInlineCore.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Public/PreparedRichInline.cs`
- Create: `PretextWpf/src/Pretext.Wpf/Internal/RichInline/RichInlineWalker.cs`
- Create: `PretextWpf/src/Pretext.Wpf/RichInlineLayoutEngine.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/RichInline/RichInlineLayoutEngineTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/RichInline/RichInlineAllocationTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: 원본 rich-inline invariant의 실패 테스트를 작성한다**

- item 경계의 leading/trailing space 한 번 collapse.
- 빈 item을 건너뛰되 source item index 보존.
- style별 측정과 item별 letter spacing.
- `Never` chip 원자성.
- container보다 넓은 chip도 한 번 배치 후 전진.
- `ExtraWidth`가 fit/occupied width에 포함.
- range fragment owner/start/end 정확성.
- materialization 전에는 fragment string 미생성.
- repeated cursor가 전체 문서를 정확히 한 번 소비.
- null item list/element, null prepared/visitor, NaN/Infinity/negative width, negative/out-of-range cursor component, reversed fragment range, 다른 prepared에서 나온 line range를 각각 deterministic exception으로 거부.

Expected: rich engine 미구현으로 실패.

**Step 2: `rich-inline.ts` 준비 로직을 포팅한다**

각 item은 `TextLayoutEngine.PrepareWithSegments`를 사용하되 item boundary 공백을 먼저 collapse한다. prepared item에는 source index, core, break mode, extra width, 앞 boundary gap만 저장한다. 입력 list와 item은 방어 복사한다.

**Step 3: rich line walker를 구현한다**

- normal item은 기본 `LineWalker.Step`의 partial range를 재사용.
- `Never`는 natural width + extra width 전체를 하나의 fragment로 취급.
- line에 다른 fragment가 있고 atomic item이 fit하지 않으면 다음 line으로 미룸.
- line이 비었으면 폭을 초과해도 atomic item을 소비.
- `GapBefore`는 line start에서는 0, 앞 fragment가 있을 때만 한 번 부과.
- `OccupiedWidth = text range width + item extra width`; 원본처럼 normal item이 여러 line fragment로 나뉘면 각 fragment가 `ExtraWidth`를 부담하고, item 전체가 한 line에 들어가면 한 번만 부담한다.

**Step 4: 공개 rich API와 guard matrix를 연결한다**

설계 문서 343–365행의 다섯 API를 그대로 구현한다. nullable start의 기본값은 `(0,0,0)`이다. visitor/list/materialization 경로를 분리한다. null은 `ArgumentNullException`, non-finite/negative width와 cursor bounds는 `ArgumentOutOfRangeException`, reversed/foreign range는 `ArgumentException`으로 통일한다. engine이 만든 `RichInlineLineRange`는 internal owner token을 가지며 `MaterializeLineRange`가 prepared core identity를 확인한다. malformed cursor에서도 walker는 같은 cursor를 되돌려 무진행 상태를 만들지 않는다.

**Step 5: rich allocation과 기능 테스트를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~RichInline"
```

Expected: 모든 rich 테스트 통과; stats/range 경로는 line text allocation 없음.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf/Internal/RichInline PretextWpf/src/Pretext.Wpf/Public/PreparedRichInline.cs PretextWpf/src/Pretext.Wpf/RichInlineLayoutEngine.cs PretextWpf/tests/Pretext.Wpf.Tests/RichInline PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port rich inline layout"
```

---

### Task 10: WPF oracle, 다국어 corpus, benchmark 구성

**Files:**
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Oracle/WpfLayoutOracle.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Oracle/WpfOracleTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/TestData/layout-corpus.json`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/TestData/upstream-regressions.json`
- Create: `PretextWpf/benchmarks/Pretext.Wpf.Benchmarks/Program.cs`
- Create: `PretextWpf/benchmarks/Pretext.Wpf.Benchmarks/TextLayoutBenchmarks.cs`
- Create: `PretextWpf/benchmarks/Pretext.Wpf.Benchmarks/VerificationSummaryWriter.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: corpus를 고정한다**

`src/test-data.ts`와 `src/layout.test.ts`의 재현 문자열을 기준 커밋에서 JSON으로 옮긴다. 최소 항목:

- Latin prose, long word, URL, decimal/symbol.
- 한글, 중국어, 일본어, Thai, Devanagari.
- Arabic, Hebrew, mixed bidi.
- combining marks, emoji ZWJ/family/flag/keycap.
- spaces, pre-wrap, hard break, ZWSP, soft hyphen, tab.

각 case는 `id`, `text`, 독립적으로 고정한 `normalizedText`, normalized UTF-16 offset 기준의 `expectedBreaks`, `culture`, `flowDirection`, `whiteSpace`, `wordBreak`, `letterSpacing`, `widths`를 가진다. 원본 문자열을 임의로 번역/축약하지 않는다. CSS 공백 정규화 정확성은 Task 3 테스트가 보호하며 oracle이 production normalizer를 재사용하지 않는다.

**Step 2: normalized 좌표계의 독립 WPF oracle을 구현한다**

oracle은 production normalizer와 `LineWalker`를 호출하지 않는다. corpus의 `normalizedText`를 `TextFormatter.FormatLine`으로 반복해 normalized UTF-16 line end, `Width`, `WidthIncludingTrailingWhitespace`를 수집한다. TextSource/paragraph properties는 테스트 전용 구현으로 중복 작성해 production bug가 공유되지 않게 한다. engine cursor도 internal segment start/grapheme map으로 같은 normalized UTF-16 offset에 변환한 뒤 비교한다. 모든 oracle 호출은 `StaTest.Run` 안에서 실행한다.

**Step 3: 비교 정책을 테스트로 고정한다**

각 corpus × DPI 1.0/1.25/1.5 × Ideal/Display에서:

- engine cursor가 normalized UTF-16 text range로 복원되고 corpus `expectedBreaks`와 비교 가능해야 한다.
- hard break/ZWSP/soft hyphen/space semantics는 exact.
- WPF와 같은 legal break를 선택한 line은 paint width 차이가 Ideal 0.05 DIP 이하, Display `0.5 / pixelsPerDip` 이하.
- WPF 기본 line-break 정책과 승인된 Pretext 정책(`KeepAll`, CJK kinsoku, browser-style collapsible trailing whitespace)이 의도적으로 다른 case는 JSON의 `policyOverride`로 명시하고 exact expected cursor를 assert한다.
- 예상하지 못한 차이를 tolerance 확대나 blanket skip으로 숨기지 않는다.

**Step 4: cold/warm·materialization 분리 benchmark와 summary writer를 작성한다**

BenchmarkDotNet class에 다음 benchmark를 분리한다.

```text
PrepareCold
PrepareWarm
Layout
LayoutWithLines
MaterializeLineRange
WalkRichRanges
WpfTextFormatterDirect
```

`GlobalSetup`에서 corpus/style/prepared/range를 만든다. `PrepareCold` 전용 `IterationSetup`은 timed region 밖에서 `ClearCaches()`를 호출하고, `PrepareWarm`은 미리 cache를 채운다. `Layout`에는 prepare/문자열 생성이 섞이지 않게 한다. `MemoryDiagnoser`와 full JSON exporter를 적용한다.

`VerificationSummaryWriter`는 `--write-status <trx> <benchmark-json> <output-json>` 모드에서 TRX의 total/passed/failed/skipped와 BenchmarkDotNet mean/allocation, machine/runtime/configuration, UTC timestamp, upstream commit을 읽어 `verification-summary.json`을 만든다. 입력 파일 부재나 failed test는 nonzero exit로 처리하며 숫자를 추정하지 않는다.

**Step 5: oracle 테스트와 benchmark smoke를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~Oracle"
dotnet run --project .\benchmarks\Pretext.Wpf.Benchmarks\Pretext.Wpf.Benchmarks.csproj -c Release -- --job short --filter "*TextLayoutBenchmarks.Layout*"
```

Expected: oracle test 통과; benchmark가 실제 결과 표를 출력하고 `Layout` allocated 0 B/op.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/tests/Pretext.Wpf.Tests/Oracle PretextWpf/tests/Pretext.Wpf.Tests/TestData PretextWpf/benchmarks PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: add oracle corpus and benchmarks"
```

---

### Task 11: WPF-UI 셸, 리소스, navigation lifecycle 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf.Demo/App.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/App.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/MainWindow.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/MainWindow.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Properties/AssemblyInfo.cs`
- Modify: `PretextWpf/src/Pretext.Wpf.Demo/Pretext.Wpf.Demo.csproj`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/ViewModelBase.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/IDemoLifecycle.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/DemoRegistry.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/DemoErrorState.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/DemoExecutionGuard.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Models/DemoDescriptor.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/MainWindowViewModel.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/StatusViewModel.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Resources/Colors.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Resources/Typography.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Resources/Controls.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Resources/Icons.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/StatusView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/StatusView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Assets/Data/verification-summary.json`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/DemoExecutionGuardTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/ViewModelBoundaryTests.cs`
- Modify: `PretextWpf/tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj`
- Modify: `PretextWpf/.claude/test-inventory.md`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/AccordionView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/AccordionView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/BubblesView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/BubblesView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/DynamicLayoutView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/DynamicLayoutView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/VariableAsciiView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/VariableAsciiView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/EditorialView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/EditorialView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/JustificationView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/JustificationView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/RichTextView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/RichTextView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MarkdownChatView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MarkdownChatView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MasonryView.xaml`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MasonryView.xaml.cs`

**Step 1: demo error contract의 실패 테스트를 작성한다**

테스트 프로젝트에 Demo `ProjectReference`를 추가하고 `DemoExecutionGuardTests`를 inventory에 활성화한다.

```csharp
[Fact]
[Trait("Category", "Error")]
public void Execute_ActionThrows_ReportsDemoPhaseAndRunsCleanup()
{
    DemoErrorState? reported = null;
    bool cleaned = false;

    DemoExecutionGuard.Execute(
        \"editorial-engine\",
        \"render\",
        () => throw new InvalidOperationException(\"boom\"),
        error => reported = error,
        () => cleaned = true);

    Assert.True(cleaned);
    Assert.Equal(\"editorial-engine\", reported?.DemoId);
    Assert.Equal(\"render\", reported?.Phase);
    Assert.IsType<InvalidOperationException>(reported?.Exception);
}
```

Expected: guard 타입 부재로 컴파일 실패.

**Step 2: 앱 composition root와 visible error boundary를 작성한다**

`App.xaml`에서 WPF-UI control/theme resources와 네 로컬 dictionary를 merge한다. `StartupUri` 대신 `App.OnStartup`에서 `MainWindowViewModel`, `DemoRegistry`, `MainWindow`를 직접 생성한다. GenericHost/DI package는 추가하지 않는다.

`DemoExecutionGuard`는 demo id/name, phase(`activate`, `deactivate`, `command`, `render`, `load`), original exception, UTC를 `DemoErrorState`에 보존한다. 실패 시 cleanup으로 timer/render subscription을 중지하고 `Debug.WriteLine(exception)` 후 ViewModel의 visible error state를 갱신한다. 예외를 빈 catch/fallback으로 버리지 않는다. `Controls.xaml`의 error presenter가 이 상태를 demo 안에 표시한다. lifecycle callbacks, animation ticks, commands는 이 guard를 공통 사용한다. Demo assembly는 테스트에 internals를 공개한다.
`ViewModelBoundaryTests`는 `.ViewModels` namespace의 fields/properties/constructor·method parameter와 generic arguments를 reflection으로 순회해 `System.Windows*`, `Wpf.Ui*`, `Pretext.Wpf.Prepared*`, `TextStyle`, `RichInlineItem` 노출을 실패시킨다. Demo model/service를 참조하면 그 공개 상태 타입도 재귀 검사해 WPF/core prepared handle이 ViewModel 경계를 우회하지 못하게 한다.

**Step 3: navigation과 status state를 작성한다**

`MainWindowViewModel`은 CommunityToolkit source generator로 다음 BCL-only 상태를 가진다.

- `IReadOnlyList<DemoDescriptor> Demos`
- `string SelectedDemoId`
- `string WindowTitle`
- `StatusViewModel VerificationStatus`

`DemoDescriptor`는 `Id`, `Title`, `Subtitle`, `SymbolName` string만 갖는다. 실제 View factory는 `DemoRegistry`의 app-side dictionary가 가진다.

Demo `.csproj`는 `<None Update="Assets\**\*" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />`를 설정한다. Status/parser/dataset loader는 `AppContext.BaseDirectory/Assets/...`만 읽어 `dotnet run`, bin 직접 실행, publish에서 같은 offline 경로를 사용한다.
`StatusViewModel`은 local `verification-summary.json`만 읽어 test counts, benchmark mean/allocation, machine/runtime/configuration, recorded UTC, upstream commit을 표시한다. file이 아직 없거나 schema가 invalid면 숫자를 만들지 않고 명시적 “recorded result 없음” 상태를 표시한다. `NavigationView.FooterMenuItems`의 Status는 9개 demo 수에 포함하지 않는다.

**Step 4: WPF-UI shell을 작성한다**

`FluentWindow` + `NavigationView`를 사용한다. demo 메뉴 순서는 Accordion, Bubbles, Dynamic Layout, Variable Typographic ASCII, Editorial Engine, Justification Comparison, Rich Text, Markdown Chat, Masonry다. 창 기본 크기 1380×900, 최소 960×640, 가운데 시작이다. title bar를 확장하고 content는 navigation pane과 분리한다.

**Step 5: lifecycle 전환을 구현한다**

`MainWindow`는 선택 변경 시:

1. 현재 content가 `IDemoLifecycle`이면 guard phase `deactivate`로 `Deactivate`.
2. registry에서 페이지를 lazy 생성하거나 cache에서 가져옴.
3. content presenter에 지정.
4. 새 content가 lifecycle이면 guard phase `activate`로 `Activate`.

window close에서도 마지막 page를 deactivate한다. page state는 registry cache로 유지한다.

**Step 6: 9개 page route frame과 Status를 연결한다**

각 View는 해당 원본 demo의 제목·intro와 후속 task가 채울 명시적 content grid를 가진 `UserControl`로 만든다. 임시 기능, `TODO`, “Coming soon”, no-op command는 넣지 않는다. 이 route frame은 Tasks 13–19에서 최종 content로 모두 교체하며, 중간 상태를 deliverable로 취급하지 않는다. Status route는 test/benchmark recorded 결과만 표시한다.

**Step 7: guard 테스트와 셸 navigation을 확인한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~DemoExecutionGuardTests|FullyQualifiedName~ViewModelBoundaryTests"
dotnet run --project .\src\Pretext.Wpf.Demo\Pretext.Wpf.Demo.csproj
```

Expected: guard 테스트 통과. 창이 열리고 9개 demo와 Status가 모두 선택 가능하며 lifecycle 전환 exception 없음. 실행 프로세스를 종료한다.

**Step 8: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo PretextWpf/tests/Pretext.Wpf.Tests/Demo PretextWpf/tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: build fluent gallery shell and error boundary"
```

---

### Task 12: 공용 text/rich drawing surface 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/TextLineDrawingBuilder.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/PretextTextSurface.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/RichInlineSurface.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Models/RichTextDocument.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/TextLineDrawingBuilderTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: painted geometry와 unconstrained measure의 실패 테스트를 작성한다**

STA에서 다음을 검증한다.

- positive/negative letter spacing line의 painted advance가 engine `LayoutLine.Width`와 허용 tolerance 안에서 같음.
- mixed Hebrew/Arabic–Latin, explicit RTL, ligature, combining mark가 logical text를 빠짐없이 한 번 paint.
- rich item boundary를 가로지르는 bidi visual run 순서와 item hit bounds.
- soft-hyphen break line은 보이는 hyphen을 포함.
- `RichTextDocument`와 span model은 text, style key, atomic flag, extra width, letter spacing, action URI string만 가진 BCL-only immutable descriptor이며 WPF/core prepared type을 노출하지 않음.
- `Measure(new Size(double.PositiveInfinity, double.PositiveInfinity))` 뒤 plain/rich surface의 `DesiredSize`가 finite.

Expected: drawing builder와 controls 부재로 실패.

**Step 2: full-line WPF glyph drawing builder를 구현한다**

`TextLineDrawingBuilder`는 line 전체 logical text와 style spans를 하나의 custom `TextSource`로 `TextFormatter`에 전달한다. rich `GapBefore`와 item chrome은 각각 engine이 준 정확한 DIP 폭의 synthetic fixed-width `TextEmbeddedObject` run으로 넣어 WPF가 line 전체 bidi ordering과 shaping context를 계산하면서 x advance도 바꾸지 않게 한다. 인접한 동일 `TextStyle` text run은 item 경계를 넘어 coalesce하되 spacer/chrome과 실제 style 변화에서는 끊는다. `TextLine.GetIndexedGlyphRuns()`와 `GetTextBounds()`로 visual runs, item bounds, baseline을 얻는다.

nonzero letter spacing은 materialized grapheme/cluster map에 따라 새 `GlyphRun`의 `AdvanceWidths`에 분배한다. cluster 내부 combining mark는 중복 spacing하지 않고 grapheme 사이에만 spacing을 추가하며 terminal spacing은 제거한다. spacing과 synthetic box로 이동한 x delta를 raw `GetTextBounds()`에도 적용해 hit rectangle과 painted glyph가 일치하게 한다. soft hyphen materializer가 넣은 `-`는 일반 glyph로 paint한다. builder는 `SegmentLevels`와 `FlowDirection`을 visual-run diagnostic에 사용하고, WPF visual order와 logical range coverage가 불일치하면 visible demo error를 보고한다.
결과는 frozen `DrawingGroup`, finite size, item/link/chip hit rectangles를 가진 immutable drawing record다. layout/text/style/DPI가 바뀔 때만 다시 만들며 `OnRender`에서는 `DrawDrawing`만 호출한다.

**Step 3: `PretextTextSurface`를 구현한다**

Dependency properties:

```text
Text, TextStyle, PrepareOptions, LineHeight, Foreground, AvailableLineWidth, DemoId
```

- text/style/options 변경 시에만 `PrepareWithSegments`.
- width 변경 시 기존 prepared로 `LayoutWithLines`와 drawing cache만 갱신.
- `AvailableLineWidth` 기본값은 `double.NaN`(unset)이고 finite 0 이상이면 우선 사용한다. 음수/Infinity는 visible input error.
- WPF measure constraint가 finite면 그 폭을 사용.
- constraint가 infinity면 prepared natural width를 사용해 finite desired size를 반환.
- arrange의 finite width가 달라지면 그 폭으로 re-layout.
- `MeasureOverride`는 engine height를 사용하고 child/`TextBlock.ActualHeight`를 읽지 않음.
- brush와 drawing은 frozen cache; render 중 생성 금지.
- empty input은 zero height.
- build/render 실패는 `DemoExecutionGuard`의 `render` phase로 보고.
- `OnDpiChanged`에서 bound `TextStyle`을 변경하지 않고 새 PixelsPerDip의 effective style로 re-prepare/rebuild.

**Step 4: `RichInlineSurface`를 구현한다**

`RichInlineSurface`는 BCL-only `RichTextDocument` descriptor를 view-side style catalog로 `RichInlineItem`에 변환해 한 번 prepare하고 width별 rich line range를 cache한다. unconstrained measure는 `LayoutNextLineRange(prepared, double.MaxValue)`의 finite line width를 natural width로 사용한다. 각 rich line은 fragment를 따로 `FormattedText`로 그리지 않고 Step 2 builder에 전체 logical line/style spans를 전달한다. item ownership, `GapBefore`, `OccupiedWidth`, chip chrome, bidi ordering, per-item letter spacing을 보존한다. link hit boxes와 keyboard selection은 cached item bounds를 사용하고 command에는 URI string만 전달한다.

**Step 5: 테스트와 host smoke를 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~TextLineDrawingBuilderTests"
```

Accordion route frame에서 Latin/한글/pre-wrap/RTL/letter-spacing sample을 `StackPanel`, auto-sized `Grid`, `ScrollViewer`에 각각 연결해 finite desired size, resize 줄바꿈, painted width를 확인한 뒤 sample wiring만 제거한다.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/Controls/TextLineDrawingBuilder.cs PretextWpf/src/Pretext.Wpf.Demo/Controls/PretextTextSurface.cs PretextWpf/src/Pretext.Wpf.Demo/Controls/RichInlineSurface.cs PretextWpf/src/Pretext.Wpf.Demo/Models/RichTextDocument.cs PretextWpf/tests/Pretext.Wpf.Tests/Demo/TextLineDrawingBuilderTests.cs PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: add bidi-aware glyph drawing surfaces"
```

---

### Task 13: Accordion과 Bubbles 데모 구현

**Files:**
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/AccordionViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/AccordionView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/AccordionView.xaml.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/BubblesViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/BubblesView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/BubblesView.xaml.cs`

**Step 1: 원본 text와 상태를 옮긴다**

`pages/demos/accordion.html/.ts`, `bubbles.html/.ts`, `bubbles-shared.ts`의 제목, 설명, 네 section, bubble messages를 기준 커밋에서 옮긴다. 콘텐츠를 임의 lorem ipsum으로 바꾸지 않는다.

**Step 2: Accordion을 구현한다**

- ViewModel은 section text/id, selected id, expanded state와 Bubbles requested width만 보유한다.
- prepared handle, line count, predicted height는 View-side `AccordionView`/`PretextTextSurface` cache가 소유하고 결과 숫자만 item의 BCL state에 반영한다.
- command는 하나의 selected item만 열거나 다시 닫음.
- content height는 cached `TextLayoutEngine.Layout` 결과에서 계산.
- animation은 `DoubleAnimation`의 `To=predicted height`; `ActualHeight`는 목표 계산에 사용하지 않음.
- header는 Button이라 Space/Enter/focus visual이 기본 지원됨.
- 원본의 light paper/card, magenta measurement label, 넓은 여백을 재현.

**Step 3: Bubbles를 구현한다**

- 기준 WPF measure와 Pretext prepare/layout은 View-side comparison cache가 소유하고 ViewModel에는 requested width와 표시용 pixel counts만 전달한다.
- slider 범위 220–760 DIP; bubble max width는 원본처럼 chat width의 80%.
- 기준 bubble은 `HorizontalAlignment=Left`, `Width=Auto`, 같은 finite `MaxWidth`의 WPF `TextBlock`/Border desired-size fit-content 동작을 사용한다. container 전체 폭을 강제로 쓰지 않는다.
- Pretext 폭은 같은 max content width에서 나온 target line count를 유지하는 최소 폭을 binary search한다.
- 기준 bubble의 WPF desired width가 max width에 실제 도달한 경우를 제외하면 container width와 같지 않음을 smoke에서 확인한다.
- 각 bubble의 기준 width와 tight width 차이 × 동일 height를 wasted pixels로 표시.
- 좌/우 비교와 chat 색상, radius, tail 성격을 원본에 맞춤.

**Step 4: 두 데모를 실제로 조작한다**

앱 실행 후 Accordion 네 section을 keyboard와 mouse로 열고 닫는다. Bubbles slider 양 끝/중간에서 line count가 좌우 같고 Pretext area가 증가하지 않는지 확인한다.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/AccordionViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/AccordionView.* PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/BubblesViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/BubblesView.*
git commit -m "pretext-wpf: port accordion and bubbles demos"
```

---

### Task 14: Dynamic Layout 데모 구현

**Files:**
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/DynamicLayoutViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/DynamicLayoutView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/DynamicLayoutView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/DynamicLayoutSurface.cs`
- Modify: `PretextWpf/src/Pretext.Wpf.Demo/Resources/Icons.xaml`

**Step 1: 원본 자산과 copy를 옮긴다**

`dynamic-layout.html/.ts/.text.ts`의 title/body/caption과 Claude/OpenAI SVG path를 가져온다. SVG는 external renderer 없이 `StreamGeometry` XAML path로 변환해 `Icons.xaml`에 넣고 freeze 가능한 리소스로 사용한다.

**Step 2: obstacle-aware streaming layout을 구현한다**

`DynamicLayoutSurface`는 title/body를 한 번 prepare한다. 현재 surface size와 obstacle rectangles를 기반으로 line별 `(x, y, width)` slot을 만든 뒤 `LayoutNextLine` cursor를 다음 slot으로 전달한다. title에서 body로 넘어갈 때 cursor/state를 분리한다. resize에서는 prepare하지 않고 slots와 layout만 다시 계산한다.

**Step 3: 렌더링과 interaction을 구현한다**

- `DrawingContext`로 paper, columns, title/body, rule, caption, logos를 그림.
- hit-test rectangle 안 logo click 시 ViewModel `LayoutVariant` toggle.
- variant에 따라 obstacle rect와 accent color가 변하고 즉시 `InvalidateVisual`.
- `OnRender` 안 allocation을 없애기 위해 size/variant 변경 때 `TextLineDrawingBuilder`의 frozen line drawings와 layout result를 갱신.

**Step 4: 실행 검증한다**

창을 최소/기본/최대 크기로 바꾸고 텍스트가 obstacle을 침범하지 않는지 확인한다. 두 logo를 각각 클릭하고 cursor 누락/중복 없이 본문이 연속되는지 확인한다.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/DynamicLayoutViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/DynamicLayoutView.* PretextWpf/src/Pretext.Wpf.Demo/Controls/DynamicLayoutSurface.cs PretextWpf/src/Pretext.Wpf.Demo/Resources/Icons.xaml
git commit -m "pretext-wpf: port dynamic layout demo"
```

---

### Task 15: Variable Typographic ASCII와 Editorial Engine 구현

**Files:**
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/VariableAsciiViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/VariableAsciiView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/VariableAsciiView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/VariableAsciiSurface.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/EditorialViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/EditorialView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/EditorialView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/EditorialSurface.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Assets/Text/editorial.txt`

**Step 1: 공통 lifecycle을 연결한다**

두 page는 `IDemoLifecycle`을 구현하고 surface의 `Start/Stop`만 호출한다. surface는 idempotent guard를 두고 `CompositionTarget.Rendering +=/-=`를 대칭 처리한다. ViewModel은 WPF event를 알지 못한다.

**Step 2: Variable ASCII field를 구현한다**

- 하나의 particle/attractor brightness grid를 매 frame 한 번 계산.
- 같은 brightness를 Source Field, Georgia 3 weights × normal/italic, Consolas single-weight의 세 panel에 공유.
- proportional panel의 character 선택과 font weight/style은 준비된 lookup table을 사용.
- glyph/brush cache는 frame 밖에서 생성.
- mouse 위치는 surface-local 좌표로 field attractor에 반영.

**Step 3: Editorial Engine을 구현한다**

- 원본 editorial copy를 local text resource로 포함.
- body는 한 번 prepare.
- animated orb 2개와 pull quote rectangle이 line slot obstacle을 구성.
- 각 frame은 obstacle 좌표, line slots, cursor ranges만 재계산; prepare 재호출 금지.
- 배경/gradient/orb geometry와 brushes는 freeze/cache.
- multi-column slot이 끝나면 다음 column으로 같은 cursor를 전달.
- rendering tick에서 range가 바뀐 line만 `TextLineDrawingBuilder` cache를 갱신하고 위치만 달라진 drawing은 translate 좌표만 바꾼다. `OnRender`는 cache draw만 수행한다.

**Step 4: lifecycle과 화면을 검증한다**

각 animated page에 진입해 3초간 움직임을 보고 다른 page로 이동한다. 디버그 counter로 rendering subscriber가 0이 되는지 확인하고 다시 진입해 1개만 등록되는지 확인한다. resize 중 text가 중복/누락되지 않는지 확인한다.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/VariableAsciiViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/VariableAsciiView.* PretextWpf/src/Pretext.Wpf.Demo/Controls/VariableAsciiSurface.cs PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/EditorialViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/EditorialView.* PretextWpf/src/Pretext.Wpf.Demo/Controls/EditorialSurface.cs PretextWpf/src/Pretext.Wpf.Demo/Assets/Text/editorial.txt
git commit -m "pretext-wpf: port animated typography demos"
```

---

### Task 16: Justification Comparison 구현

**Files:**
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/JustificationViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/JustificationView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/JustificationView.xaml.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/JustificationSurface.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Services/JustificationLayoutService.cs`

**Step 1: 원본 paragraph와 상태를 옮긴다**

`justification-comparison.html/.ts`의 동일 paragraph, labels, initial width, river toggle을 사용한다. slider 범위는 원본과 같은 유효 column 범위로 고정한다.

**Step 2: 세 strategy를 구현한다**

- `Wpf`: TextFormatter 기본 wrapping + justified draw.
- `GreedyHyphen`: Pretext range walker와 soft-hyphen candidate를 사용.
- `KnuthPlass`: word box, space glue, soft-hyphen penalty로 dynamic programming 최소 demerit path를 계산.

마지막 line은 natural spacing, 다른 line은 남는 폭을 word gaps에만 분배한다. no-space line과 한 word line은 stretch하지 않는다.
`Wpf` line은 `TextLine.Draw`, 두 custom line은 `TextLineDrawingBuilder`가 만든 shaped word runs를 계산된 gap x에 배치한다. soft-hyphen 선택 지점에는 hyphen glyph를 paint한다. 세 strategy 모두 layout change 때 frozen drawing을 만들고 `OnRender`에서는 재측정/할당하지 않는다.

**Step 3: river detector를 구현한다**

각 line의 adjusted space center x를 수집하고 인접 3개 이상 line에서 threshold 안에 이어지는 cluster만 river로 표시한다. overlay geometry는 layout change 때만 재생성하고 freeze한다.

**Step 4: slider/toggle을 검증한다**

최소/중간/최대 폭에서 세 column이 control bounds를 넘지 않고 마지막 line이 stretch되지 않는지 확인한다. river toggle을 반복하고 off에서 overlay가 완전히 사라지는지 확인한다.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/JustificationViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/JustificationView.* PretextWpf/src/Pretext.Wpf.Demo/Controls/JustificationSurface.cs PretextWpf/src/Pretext.Wpf.Demo/Services/JustificationLayoutService.cs
git commit -m "pretext-wpf: port justification comparison demo"
```

---

### Task 17: Rich Text 데모와 안전한 링크 실행 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/SafeUriLauncher.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/RichTextViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/RichTextView.xaml`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/SafeUriLauncherTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/RichTextView.xaml.cs`

**Step 1: rich document를 원본 content로 구성한다**

`rich-note.html/.ts`에서 paragraph를 가져와 plain, emphasis, link, code, mention chip item으로 나눈다. 각 item은 Segoe UI/Consolas, weight, color, letter spacing, extra chrome를 명시한다. mention/chip은 `BreakMode.Never`다.

**Step 2: ViewModel과 slider를 구현한다**

- slider는 280–840 DIP.
- width 변경 시 prepared rich document를 재생성하지 않고 range layout만 다시 실행.
- line count, max line width, item/fragment count를 표시.
- 선택된 link URI는 string으로 command에 전달.

**Step 3: `SafeUriLauncher`를 구현한다**

먼저 `ValidateAbsoluteHttpUri_NonHttpSchemes_ThrowsArgumentException`, null/relative/file/javascript/mailto 거부, HTTP/HTTPS 정규화 통과 테스트를 작성해 실패를 확인한다. 테스트는 실제 process를 실행하지 않고 internal validation 함수만 호출한다.

```csharp
if (!Uri.TryCreate(value, UriKind.Absolute, out Uri? uri) ||
    (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
{
    throw new ArgumentException("Only absolute HTTP(S) URIs are allowed.", nameof(value));
}

Process.Start(new ProcessStartInfo(uri.AbsoluteUri) { UseShellExecute = true });
```

URI exception을 삼키지 않는다. invalid URI는 ViewModel error state에 표시한다.

**Step 4: 테스트와 interaction을 검증한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~SafeUriLauncherTests"
```

slider 전 범위에서 chip이 분할되지 않고 source item owner가 유지되는지 확인한다. link hit area에 keyboard focus를 두고 Enter를 눌러 HTTP(S)만 실행되는지 확인한다.

**Step 5: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/Infrastructure/SafeUriLauncher.cs PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/RichTextViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/RichTextView.* PretextWpf/tests/Pretext.Wpf.Tests/Demo/SafeUriLauncherTests.cs PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port rich text demo"
```

---

### Task 18: Markdown Chat 파싱·가상화 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Assets/Text/markdown-chat.md`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Models/ChatModels.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Services/MarkdownLayoutService.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Services/MarkdownDocumentParser.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/VirtualizingPredictedStackPanel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/MarkdownChatViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MarkdownChatView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MarkdownChatView.xaml.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/MarkdownDocumentParserTests.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/PredictedStackLayoutTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: 원본 markdown 대화를 local resource로 옮긴다**

`markdown-chat.html/.ts`의 message content와 fenced code를 UTF-8 resource로 저장한다. 앱 실행 중 네트워크를 호출하지 않는다.

**Step 2: Markdig AST adapter를 구현한다**

먼저 paragraph/emphasis/strong/code/link descriptor, fenced-code 공백·hard break 보존, inline/block HTML literalization, unsupported block text 보존, null 입력 오류 테스트를 작성해 parser 부재로 실패를 확인한다. 그 뒤 `MarkdownDocumentParser`는 Markdig AST를 다음 BCL model로 변환한다.

- paragraph -> BCL-only `RichTextSpan` descriptor list.
- emphasis/strong/code/link -> style/break descriptor.
- fenced code -> raw text + WPF-free `PreWrap` enum descriptor.
- unsupported block -> plain text를 잃지 않고 literal block.

HTML inline/block은 실행하지 않고 text로 표시한다. link destination은 `SafeUriLauncher` 검증 전까지 string으로 둔다.

**Step 3: message 높이와 prefix-sum 실패 테스트를 작성한 뒤 구현한다**

`MarkdownChatViewModel`은 WPF-free message/id/role/block state만 노출한다. View-side `MarkdownLayoutService`가 message id별 prepared paragraph/code를 소유하고, viewport width가 바뀌면 prepared handle을 재사용해 finite `PredictedHeight`만 다시 계산하여 BCL 숫자로 반영한다. `PredictedStackLayoutTests`는 높이/spacing prefix sums, y-offset의 first/last visible index binary search, empty/single/zero viewport, anchor id+intra-item offset 복원을 먼저 실패시킨다.

**Step 4: prediction-driven recycling panel을 구현한다**

`VirtualizingPredictedStackPanel : VirtualizingPanel, IScrollInfo`는 Step 3 prefix sums를 extent와 arrange의 유일한 y geometry로 사용한다.

- viewport y range와 cache page에 교차하는 index만 `ItemContainerGenerator`로 생성.
- 범위 밖 container는 generator/visual tree에서 recycle.
- child constraint와 arranged height는 해당 predicted height.
- actual desired height 차이는 debug에서 0.5 DIP 이하 assert.
- `ExtentHeight`는 모든 predicted height+spacing 합으로 고정되어 realization 순서에 따라 변하지 않음.
- offset clamp, line/page/wheel, Home/End, `MakeVisible` 구현.
- realized count는 visible range + 앞뒤 cache page보다 많아지지 않음.

host `ItemsControl`은 `VirtualizingPanel.IsVirtualizing=True`, `VirtualizationMode=Recycling`, `ScrollViewer.CanContentScroll=True`를 설정해 panel의 recycle 경로를 실제 사용한다.
message template은 role별 alignment/color를 구분하고 `RichInlineSurface`/`PretextTextSurface`를 사용한다.

**Step 5: mask와 scroll anchoring을 구현한다**

mask toggle은 viewport와 realized container bounds만 overlay로 표시하며 virtualization 자체를 끄지 않는다. width 변화 전 top visible message id와 predicted intra-item offset을 기록한다. 높이/prefix sum 재계산 뒤 id가 unrealized여도 새 prefix offset으로 정확히 복원한다.

**Step 6: 테스트와 긴 스크롤을 검증한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~MarkdownDocumentParserTests|FullyQualifiedName~PredictedStackLayoutTests"
```

위/중간/끝으로 스크롤하고 mask를 토글한다. realized container 수가 bound 안이고, extent가 realization 중 변하지 않고, fenced code 공백/줄바꿈이 보존되고, resize 뒤 anchor가 유지되는지 확인한다.

**Step 7: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/Assets/Text/markdown-chat.md PretextWpf/src/Pretext.Wpf.Demo/Models/ChatModels.cs PretextWpf/src/Pretext.Wpf.Demo/Services/MarkdownDocumentParser.cs PretextWpf/src/Pretext.Wpf.Demo/Services/MarkdownLayoutService.cs PretextWpf/src/Pretext.Wpf.Demo/Controls/VirtualizingPredictedStackPanel.cs PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/MarkdownChatViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MarkdownChatView.* PretextWpf/tests/Pretext.Wpf.Tests/Demo/MarkdownDocumentParserTests.cs PretextWpf/tests/Pretext.Wpf.Tests/Demo/PredictedStackLayoutTests.cs PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port virtualized markdown chat demo"
```

---

### Task 19: Masonry 예측 배치와 viewport 가상화 구현

**Files:**
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Assets/Data/shower-thoughts.json`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Models/MasonryCard.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Services/MasonryLayoutService.cs`
- Create: `PretextWpf/src/Pretext.Wpf.Demo/Controls/VirtualizingMasonryPanel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/MasonryViewModel.cs`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MasonryView.xaml`
- Create/Modify: `PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MasonryView.xaml.cs`
- Create: `PretextWpf/tests/Pretext.Wpf.Tests/Demo/MasonryLayoutServiceTests.cs`
- Modify: `PretextWpf/.claude/test-inventory.md`

**Step 1: 원본 dataset을 그대로 포함한다**

`pages/demos/masonry*.ts/html`이 사용하는 shower-thought data를 기준 커밋에서 JSON으로 추출한다. card text/id/order를 보존하고 Task 11의 `Assets\**\*` copy rule로 output/publish에 포함되는지 확인한다.

**Step 2: 높이 예측과 column assignment를 구현한다**

먼저 empty/single input, deterministic shortest-column tie, finite predicted bounds, no-overlap within each column, viewport range query, resize anchor 복원 테스트를 작성해 실패를 확인한다. `MasonryLayoutService`는 `(viewportWidth, columnCount, gap, card padding, typography)`로 card width를 계산한다. 각 card text를 한 번 prepare하고 `Layout` height + chrome을 더한다. input order대로 현재 누적 높이가 가장 짧은 column에 배치하고 immutable `MasonryPlacement(index, Rect-like BCL doubles)` list를 반환한다. `ActualHeight`, `DesiredSize`를 prediction input으로 읽지 않는다.

**Step 3: `VirtualizingMasonryPanel`을 구현한다**

`VirtualizingPanel, IScrollInfo`를 구현한다.

- placement list와 viewport y range+cache page의 교차 항목만 `ItemContainerGenerator`로 materialize.
- column별 y-sorted placement index에서 `Bottom >= viewportTop`인 첫 card를 binary search하고 `Top <= viewportBottom` 동안만 열거한다.
- 범위 밖 generated child는 `IRecyclingItemContainerGenerator.Recycle`과 visual child 제거로 재사용한다.
- measure는 predicted width/height constraint를 사용.
- arrange는 placement x/y에서 vertical offset을 뺀 좌표.
- extent height는 tallest column, viewport/offset은 `IScrollInfo` 계약대로 clamp.
- mouse wheel/page/home/end와 `MakeVisible` 구현.
- scroll 중 service 재계산이나 text 재측정 금지.

**Step 4: visual과 ViewModel을 연결한다**

원본의 paper background, 다양한 card tint/rotation 성격, metadata를 재현한다. card template 안 텍스트는 `PretextTextSurface`를 사용하고 predicted height와 실제 surface desired height 차이는 debug assertion으로 0.5 DIP 안인지 확인한다.
host `ItemsControl`도 `IsVirtualizing=True`, `VirtualizationMode=Recycling`, `CanContentScroll=True`를 명시한다.

**Step 5: 테스트와 긴 스크롤을 검증한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj --filter "FullyQualifiedName~MasonryLayoutServiceTests"
```

처음/중간/끝에서 realized child 수, extent/offset, card overlap을 확인한다. 창 resize로 column 수가 바뀔 때 placement는 한 번 재계산되고 unrealized card도 immutable id+intra-card offset으로 top anchor가 유지돼야 한다.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/Assets/Data/shower-thoughts.json PretextWpf/src/Pretext.Wpf.Demo/Models/MasonryCard.cs PretextWpf/src/Pretext.Wpf.Demo/Services/MasonryLayoutService.cs PretextWpf/src/Pretext.Wpf.Demo/Controls/VirtualizingMasonryPanel.cs PretextWpf/src/Pretext.Wpf.Demo/ViewModels/Demos/MasonryViewModel.cs PretextWpf/src/Pretext.Wpf.Demo/Views/Demos/MasonryView.* PretextWpf/tests/Pretext.Wpf.Tests/Demo/MasonryLayoutServiceTests.cs PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: port virtualized masonry demo"
```

---

### Task 20: 원본 고지, API XML 문서, 테스트 inventory 동기화

**Files:**
- Create: `PretextWpf/LICENSE-PRETEXT`
- Create: `PretextWpf/LICENSE-WPF-SAMPLES`
- Create: `PretextWpf/README.md`
- Create: `PretextWpf/THIRD-PARTY-NOTICES.txt`
- Modify: `PretextWpf/upstream-manifest.json`
- Modify: public files under `PretextWpf/src/Pretext.Wpf/`
- Modify: `PretextWpf/src/Pretext.Wpf/Pretext.Wpf.csproj`
- Modify: `PretextWpf/.claude/test-inventory.md`
- Remove temporary: `PretextWpf/.upstream/pretext/`
- Remove temporary: `PretextWpf/.upstream/wpf-samples/`

**Step 1: exact MIT license와 provenance 고지를 작성한다**

각 detached checkout의 `LICENSE` byte를 각각 `LICENSE-PRETEXT`, `LICENSE-WPF-SAMPLES`로 복사하고 SHA-256이 manifest hash와 같은지 확인한다. `THIRD-PARTY-NOTICES.txt`에는 두 저장소 URL/기준 commit/license, Pretext package version 0.0.8, 포팅 범위(`src` engine + nine demos), Microsoft WPF sample에서 실제 참고/파생한 파일을 명시한다. 또한 실제 resolved nupkg의 license metadata/file을 HandMirror로 확인해 WPF-UI, CommunityToolkit.Mvvm, Markdig 런타임 의존성과 BenchmarkDotNet/xUnit/Test SDK 개발 전용 의존성을 id/version/SPDX 또는 license URL과 함께 구분해 기록하며 기억으로 license를 추정하지 않는다.

**Step 2: 사용 README를 작성한다**

`README.md`에 Windows 11/.NET 10 prerequisites, restore/build/test/benchmark/run 명령, `.slnx` 경로, public API 최소 예제, 9개 demo와 Status, offline asset 정책, WPF-native typography 차이, Pretext `0.0.8 + ac49b09 기준 미출시 변경` 범위와 두 기준 commit/license, benchmark 숫자가 recorded result라는 주의를 포함한다. 아직 실행하지 않은 결과나 성능 수치는 쓰지 않는다.

**Step 3: 공개 API XML 문서를 완성한다**

모든 public type/member에 summary, parameter, return, exception, allocation/materialization contract를 작성한다. `PreparedText`가 immutable/thread-safe reader handle이고 `Prepare` 자체는 caller-thread WPF measurement를 수행한다는 점을 명시한다. 사실상 구현과 다른 주석은 쓰지 않는다.

모든 public member 문서가 작성된 뒤에만 핵심 `.csproj`에 `<GenerateDocumentationFile>true</GenerateDocumentationFile>`를 추가한다. 따라서 앞 작업은 미완성 XML 문서의 CS1591을 숨기는 `NoWarn` 없이도 빌드되고, 최종 단계에서는 실제 XML 산출물을 생성한다.

**Step 4: provenance와 runtime assets를 audit한다**

`upstream-manifest.json.copiedFiles`의 각 원본 hash를 해당 detached checkout에서 다시 계산하고 대응 C#/asset/license destination 존재를 확인한다. 변환 산출물에는 현재 `destinationSha256`과 `verifiedUtc`를 기록하되 source/destination hash가 같다고 가정하지 않는다. exact-copy로 선언한 license/JSON/text asset만 byte hash equality를 요구한다. 데모 output에는 local text/JSON/status만 포함하고, 원본 TypeScript/HTML, Bun artifacts, browser JS bundle은 포함하지 않는다. core output에는 `Pretext.Wpf.dll/.pdb/.xml`과 framework runtime references 외 third-party DLL이 없어야 한다.

audit가 통과한 뒤 우리가 만든 임시 `.upstream/pretext`와 `.upstream/wpf-samples` checkout만 삭제한다. 사용자 파일이나 다른 checkout은 삭제하지 않는다.

**Step 5: inventory와 실제 테스트를 동기화한다**

테스트 파일의 `[Fact]/[Theory]` 이름을 inventory와 대조한다. 구현된 행은 `Passing`, 삭제/변경된 행은 이름과 보호 계약을 갱신한다. 테스트 없는 `Passing` 행과 inventory에 없는 테스트를 0개로 만든다.

**Step 6: 커밋한다**

```powershell
git add PretextWpf/LICENSE-PRETEXT PretextWpf/LICENSE-WPF-SAMPLES PretextWpf/README.md PretextWpf/THIRD-PARTY-NOTICES.txt PretextWpf/upstream-manifest.json PretextWpf/src/Pretext.Wpf PretextWpf/.claude/test-inventory.md
git commit -m "pretext-wpf: add attribution and public API docs"
```

---

### Task 21: 전체 검증, 앱 smoke, 시각 비교, 최종 품질 점검

**Files:**
- Modify: `PretextWpf/src/Pretext.Wpf.Demo/Assets/Data/verification-summary.json`
- Modify other files only if verification exposes a real defect.

**Step 1: formatter를 한 번 실행한다**

WPF XAML/C# formatter 규칙을 사용해 `PretextWpf`만 포맷한다. 생성된 `BidiData.g.cs`는 generated-file 규칙으로 불필요한 재정렬을 피한다.

**Step 2: clean build와 전체 테스트를 실행한다**

```powershell
dotnet clean .\PretextWpf.slnx -c Release
dotnet build .\PretextWpf.slnx -c Release
dotnet test .\PretextWpf.slnx -c Release --no-build --logger "trx;LogFileName=pretext-tests.trx" --results-directory .\artifacts\TestResults
```

Expected: warning 0, error 0, failed 0, skipped 0, passed=total.

**Step 3: architecture 산출물 audit를 다시 실행한다**

```powershell
dotnet test .\tests\Pretext.Wpf.Tests\Pretext.Wpf.Tests.csproj -c Release --no-build --filter "FullyQualifiedName~Architecture"
```

Expected: core PackageReference/ProjectReference 0, third-party assembly reference 0.

**Step 4: benchmark smoke와 recorded Status artifact를 생성한다**

```powershell
dotnet run --project .\benchmarks\Pretext.Wpf.Benchmarks\Pretext.Wpf.Benchmarks.csproj -c Release -- --job short
dotnet run --project .\benchmarks\Pretext.Wpf.Benchmarks\Pretext.Wpf.Benchmarks.csproj -c Release -- --write-status .\artifacts\TestResults\pretext-tests.trx .\BenchmarkDotNet.Artifacts\results\Pretext.Wpf.Benchmarks.TextLayoutBenchmarks-report-full.json .\src\Pretext.Wpf.Demo\Assets\Data\verification-summary.json
dotnet build .\src\Pretext.Wpf.Demo\Pretext.Wpf.Demo.csproj -c Release --no-restore
```

Expected: 7개 benchmark 완료, warmed `Layout` 0 B/op, status writer exit 0. JSON의 test counts/benchmark 수치는 실제 TRX/BDN 결과와 같고 timestamp/machine/configuration/commit이 채워진다. 환경별 시간 수치는 고정 threshold로 실패시키지 않는다.

**Step 5: 앱을 실행해 9개 주요 흐름을 확인한다**

```powershell
dotnet run --project .\src\Pretext.Wpf.Demo\Pretext.Wpf.Demo.csproj -c Release
```

체크리스트:

1. 9개 navigation item 모두 열림.
2. Accordion 네 section mouse/Space/Enter.
3. Bubbles width slider 양 끝과 중간.
4. Dynamic Layout 창 resize와 두 logo click.
5. Variable ASCII 진입/이탈/재진입.
6. Editorial resize/animation/이탈.
7. Justification slider와 river toggle.
8. Rich Text slider, chip atomicity, HTTP(S) link.
9. Markdown Chat mask, 긴 scroll, resize anchor.
10. Masonry 시작/중간/끝 scroll, resize column 재배치.
11. animated page 이탈 뒤 rendering subscriber 0.
12. unhandled exception, binding error, clipped focus visual 0.
13. Status에 이번 실행의 test counts, 7개 benchmark, machine/runtime, recorded UTC, upstream commit이 표시되고 “recorded result”로 구분됨.

**Step 6: 원본 라이브 demo와 대표 화면을 비교한다**

브라우저에서 <https://chenglou.me/pretext/>의 9개 demo를 열고 앱의 대응 화면과 나란히 본다. 기능·정보 계층·색상 성격·spacing·interaction이 보존됐는지 확인한다. WPF-UI shell 때문에 의도한 차이는 허용하지만 demo 고유 visual을 Fluent 기본 스타일로 덮은 차이는 수정한다.

**Step 7: 변경 코드 review를 수행한다**

검토 항목:

- 핵심 layout loop의 WPF 호출/할당/LINQ/문자열 생성.
- cache key 누락과 mutable array 노출.
- cursor 무진행/infinite loop.
- event/timer 구독 leak.
- ViewModel의 `System.Windows` 참조.
- `OnRender` resource allocation.
- swallowed exception/fake fallback.
- placeholder/TODO/no-op/mock runtime content.
- 누락된 asset/callsite/XML 문서/inventory 행.

발견된 문제는 같은 단계에서 수정하고 관련 좁은 test/smoke를 다시 실행한다.

**Step 8: recorded status와 최종 검증 수정사항을 커밋한다**

`verification-summary.json`은 항상 새 실제 결과로 바뀐다. 검증에서 수정한 파일이 있으면 예상하지 못한 사용자 변경을 제외하고 경로를 하나씩 명시해 함께 stage한다.

```powershell
git add PretextWpf/src/Pretext.Wpf.Demo/Assets/Data/verification-summary.json
git commit -m "pretext-wpf: record verified build status"
```

---

## 완료 증거

최종 보고에는 추정이 아니라 다음 실제 출력만 요약한다.

- Release build warning/error 수.
- 전체 test 통과/실패/skip 수.
- core assembly reference audit 결과.
- benchmark smoke의 각 benchmark 실행 여부와 `Layout` allocation.
- 앱 smoke에서 확인한 9개 페이지와 각 interaction.
- 원본 대비 의도적으로 달라진 WPF-native typography 항목.
- 남은 blocker가 있다면 정확한 입력/환경/재현 명령.
