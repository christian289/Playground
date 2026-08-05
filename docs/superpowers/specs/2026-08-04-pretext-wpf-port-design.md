# Pretext WPF 포팅 설계서

- 날짜: 2026-08-04
- 프로젝트 폴더: `PretextWpf`
- 원본 저장소: `https://github.com/chenglou/pretext`
- 기준 커밋: `ac49b09b7d83ede19581fa94a8b892b07d309baf`
- 원본 패키지 버전: `0.0.8` + 기준 커밋의 미출시 변경
- 대상 플랫폼: Windows, WPF, .NET 10
- 상태: 설계 승인 완료, 사용자 문서 검토 대기

## 1. 목표

Pretext의 TypeScript 텍스트 분석·측정·줄바꿈 엔진을 관용적인 C# API로 포팅하고, 원본의 9개 공개 데모를 하나의 WPF 갤러리 앱으로 재현한다.

포팅의 핵심은 원본의 두 단계 구조를 보존하는 것이다.

1. `Prepare`: 텍스트를 한 번 분석하고 WPF 네이티브 텍스트 API로 측정하여 폭과 무관한 불변 데이터를 만든다.
2. `Layout`: 컨테이너 폭이 바뀔 때 준비된 숫자 배열만 순회하여 줄 수·높이·줄 범위를 계산한다.

정확도 기준은 브라우저가 아니라 실제 WPF 텍스트 렌더링이다. 브라우저와 WPF의 shaping, font fallback, 줄바꿈 정책 차이를 억지로 숨기지 않는다.

## 2. 확정된 범위

### 2.1 포함

- 원본 기본 엔트리포인트의 기능 전체
  - 준비와 빠른 높이 계산
  - segment 포함 준비
  - 전체 줄 구체화
  - 줄 범위 순회
  - 줄 통계와 자연 폭
  - 한 줄씩 진행하는 streaming API
  - 범위의 실제 문자열 구체화
  - locale/culture와 캐시 제어
- 원본 `rich-inline` 엔트리포인트의 기능 전체
  - 서로 다른 스타일의 inline item
  - item 경계 공백 collapse
  - atomic item
  - caller-owned extra width
  - 범위 순회·통계·구체화
- 텍스트 동작
  - `white-space: normal`에 대응하는 공백 collapse
  - `pre-wrap`
  - 일반 줄바꿈과 `keep-all`
  - emergency grapheme break
  - CJK/Hangul과 kinsoku 계열 구두점
  - ZWSP, soft hyphen, 강제 줄바꿈
  - tab size 8
  - 숫자·URL·기호·구두점 glue 정책
  - letter spacing
  - bidi segment metadata
- 원본 9개 데모
  - Accordion
  - Bubbles
  - Dynamic Layout
  - Variable Typographic ASCII
  - Editorial Engine
  - Justification Comparison
  - Rich Text
  - Markdown Chat
  - Masonry
- 원본 다국어 corpus와 핵심 회귀 사례를 C# 정확도 테스트 데이터로 이식
- prepare/layout 성능과 allocation을 측정하는 벤치마크
- 원본 MIT 라이선스와 기준 커밋 표기

### 2.2 대응 방식

브라우저 전용 accuracy/probe/corpus/status 페이지와 Bun 스크립트는 그대로 복제하지 않는다. 같은 목적을 다음 네이티브 산출물로 대체한다.

- accuracy/probe/corpus: xUnit 정확도 sweep과 실패 진단 출력
- benchmark 페이지: BenchmarkDotNet 프로젝트와 갤러리 내 성능 수치
- status dashboard: 테스트 결과와 벤치마크 결과
- 정적 사이트 빌드: WPF 앱 빌드·배포

WebView2, JavaScript 런타임, DOM, Canvas, SVG 렌더러는 포함하지 않는다.

## 3. 솔루션 구조

```text
PretextWpf/
├─ PretextWpf.slnx
├─ global.json
├─ LICENSE-PRETEXT
├─ README.md
├─ src/
│  ├─ Pretext.Wpf/
│  └─ Pretext.Wpf.Demo/
├─ tests/
│  └─ Pretext.Wpf.Tests/
└─ benchmarks/
   └─ Pretext.Wpf.Benchmarks/
```

### 3.1 `Pretext.Wpf`

`net10.0-windows` 재사용 라이브러리. 텍스트 분석, 네이티브 측정, 준비 데이터, 산술 줄바꿈, rich-inline을 소유한다.

이 프로젝트는 WPF와 BCL 외의 런타임 의존성을 가질 수 없다.

허용 API 예:

- `TextFormatter`, `TextLine`, `GlyphRun`, `GlyphTypeface`
- `FormattedText`, `Typeface`, `DrawingContext`
- `StringInfo`, `Rune`, `CultureInfo`
- BCL 컬렉션과 동시성 기본형

금지 의존성 예:

- WPF-UI
- SkiaSharp
- HarfBuzzSharp
- ICU 패키지
- DirectWrite 래퍼
- WebView2
- JavaScript 엔진

### 3.2 `Pretext.Wpf.Demo`

`net10.0-windows` WPF 실행 앱. WPF-UI `NavigationView` 기반 갤러리 셸과 9개 데모를 소유한다.

앱 계층에서는 구현 편의를 위해 다음 패키지를 사용할 수 있다.

- WPF-UI: 셸, 탐색, 일반 입력 컨트롤
- CommunityToolkit.Mvvm: 상태와 명령
- Markdig: Markdown Chat의 파싱

텍스트 측정·줄바꿈·rich-inline·bidi·사용자 지정 텍스트 렌더링은 앱 패키지로 대체하지 않고 `Pretext.Wpf`와 WPF 네이티브 렌더링 API를 사용한다.

### 3.3 `Pretext.Wpf.Tests`

엔진 불변식, WPF 정확도, 다국어 corpus, 아키텍처 경계를 검증한다. WPF 오라클 검증이 필요한 테스트는 명시적인 apartment 설정으로 실행한다.

### 3.4 `Pretext.Wpf.Benchmarks`

prepare cold path, layout hot path, rich range 순회, 줄 구체화, WPF 직접 재포맷을 비교한다. 머신별 절대 시간보다 회귀와 상대 차이를 기록한다.

## 4. 의존성 규칙

프로젝트 참조 방향은 다음과 같다.

```text
Pretext.Wpf.Demo ───────▶ Pretext.Wpf
Pretext.Wpf.Tests ──────▶ Pretext.Wpf
Pretext.Wpf.Benchmarks ─▶ Pretext.Wpf
```

`Pretext.Wpf`는 다른 프로젝트를 참조하지 않는다. 핵심 프로젝트의 MSBuild target이 모든 `PackageReference`와 `ProjectReference`를 거부하고, 빌드된 DLL의 assembly-reference 검증은 .NET/WPF framework assembly만 허용한다.

## 5. 공개 API

이름과 타입은 .NET 관례를 따르되 원본의 관찰 가능한 기능을 보존한다.

### 5.1 기본 엔진

```csharp
public static class TextLayoutEngine
{
    public static PreparedText Prepare(
        string text,
        TextStyle style,
        PrepareOptions options = default);

    public static PreparedTextWithSegments PrepareWithSegments(
        string text,
        TextStyle style,
        PrepareOptions options = default);

    public static LayoutResult Layout(
        PreparedText prepared,
        double maxWidth,
        double lineHeight);

    public static LayoutLinesResult LayoutWithLines(
        PreparedTextWithSegments prepared,
        double maxWidth,
        double lineHeight);

    public static int WalkLineRanges(
        PreparedTextWithSegments prepared,
        double maxWidth,
        LineRangeVisitor visitor);

    public static LineStats MeasureLineStats(
        PreparedTextWithSegments prepared,
        double maxWidth);

    public static double MeasureNaturalWidth(
        PreparedTextWithSegments prepared);

    public static LayoutLine? LayoutNextLine(
        PreparedTextWithSegments prepared,
        LayoutCursor start,
        double maxWidth);

    public static LayoutLineRange? LayoutNextLineRange(
        PreparedTextWithSegments prepared,
        LayoutCursor start,
        double maxWidth);

    public static LayoutLine MaterializeLineRange(
        PreparedTextWithSegments prepared,
        LayoutLineRange range);

    public static void ClearCaches();
}
```

공개 타입 계약은 다음과 같다.

```csharp
public delegate void LineRangeVisitor(in LayoutLineRange line);

public readonly record struct LayoutCursor(int SegmentIndex, int GraphemeIndex);
public readonly record struct LayoutResult(int LineCount, double Height);
public readonly record struct LineStats(int LineCount, double MaxLineWidth);
public readonly record struct LayoutLineRange(
    double Width,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record LayoutLine(
    string Text,
    double Width,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record LayoutLinesResult(
    int LineCount,
    double Height,
    IReadOnlyList<LayoutLine> Lines);

public class PreparedText
{
    internal PreparedText() { }
}

public sealed class PreparedTextWithSegments : PreparedText
{
    internal PreparedTextWithSegments() { }

    public ReadOnlyMemory<string> Segments { get; }
    public ReadOnlyMemory<sbyte>? SegmentLevels { get; }
}
```

- `PreparedText`는 내부 배열을 외부에 노출하지 않는 불변 핸들이다.
- `PreparedTextWithSegments`는 렌더링에 필요한 읽기 전용 segment와 bidi metadata만 노출한다.
- cursor는 raw UTF-16 offset이 아니라 segment/grapheme 좌표다.
- `LayoutResult`, `LineStats`, cursor, range는 값 타입이다.
- `Layout`은 문자열이나 per-line 객체를 만들지 않는다.

### 5.2 스타일과 옵션

```csharp
public sealed record TextStyle(
    FontFamily FontFamily,
    double FontSize,
    FontWeight FontWeight,
    FontStyle FontStyle,
    FontStretch FontStretch,
    CultureInfo Culture,
    FlowDirection FlowDirection,
    double PixelsPerDip,
    TextFormattingMode FormattingMode);

public enum WhiteSpaceMode
{
    Normal,
    PreWrap,
}

public enum WordBreakMode
{
    Normal,
    KeepAll,
}

public readonly record struct PrepareOptions(
    WhiteSpaceMode WhiteSpace = WhiteSpaceMode.Normal,
    WordBreakMode WordBreak = WordBreakMode.Normal,
    double LetterSpacing = 0);
```

캐시 키에는 `TextStyle`과 `PrepareOptions.LetterSpacing`의 측정 관련 값을 모두 포함한다. DPI, culture, flow direction, formatting mode가 다른 측정값을 재사용하지 않는다.

### 5.3 Rich inline

```csharp
public enum RichInlineBreakMode
{
    Normal,
    Never,
}

public sealed record RichInlineItem(
    string Text,
    TextStyle Style,
    RichInlineBreakMode BreakMode = RichInlineBreakMode.Normal,
    double ExtraWidth = 0,
    double LetterSpacing = 0);

public readonly record struct RichInlineCursor(
    int ItemIndex,
    int SegmentIndex,
    int GraphemeIndex);

public readonly record struct RichInlineFragmentRange(
    int ItemIndex,
    double GapBefore,
    double OccupiedWidth,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record RichInlineLineRange(
    IReadOnlyList<RichInlineFragmentRange> Fragments,
    double Width,
    RichInlineCursor End);

public sealed record RichInlineFragment(
    int ItemIndex,
    string Text,
    double GapBefore,
    double OccupiedWidth,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record RichInlineLine(
    IReadOnlyList<RichInlineFragment> Fragments,
    double Width,
    RichInlineCursor End);

public readonly record struct RichInlineStats(
    int LineCount,
    double MaxLineWidth);

public delegate void RichInlineLineRangeVisitor(RichInlineLineRange line);

public sealed class PreparedRichInline
{
    internal PreparedRichInline() { }
}

public static class RichInlineLayoutEngine
{
    public static PreparedRichInline Prepare(
        IReadOnlyList<RichInlineItem> items);

    public static RichInlineLineRange? LayoutNextLineRange(
        PreparedRichInline prepared,
        double maxWidth,
        RichInlineCursor? start = null);

    public static int WalkLineRanges(
        PreparedRichInline prepared,
        double maxWidth,
        RichInlineLineRangeVisitor visitor);

    public static RichInlineLine MaterializeLineRange(
        PreparedRichInline prepared,
        RichInlineLineRange range);

    public static RichInlineStats MeasureLineStats(
        PreparedRichInline prepared,
        double maxWidth);
}
```

`RichInlineBreakMode.Never` item은 chip처럼 원자적으로 유지한다. 컨테이너보다 item이 넓을 때도 한 번은 진행해야 하며 무한 반복하지 않는다.

## 6. 준비 파이프라인

### 6.1 정규화와 분석

1. 공백 모드에 따라 입력을 정규화한다.
2. Unicode grapheme 경계를 만든다.
3. 단어와 script 경계를 분석한다.
4. CJK, Hangul, 구두점, URL, 숫자, symbol run, Arabic mark 정책을 적용한다.
5. hard break, preserved space, tab, ZWSP, soft hyphen을 명시적 segment kind로 만든다.
6. `keep-all`과 emergency break 후보를 계산한다.
7. rich API용 bidi segment level을 계산한다.

Unicode 정책 데이터는 원본의 생성 결과와 .NET Unicode API를 사용하며, 런타임에 브라우저나 외부 Unicode 패키지를 호출하지 않는다.

### 6.2 네이티브 측정

WPF 네이티브 shaping 결과가 기준이다.

- prepare-time formatter는 caller thread 안에서만 사용한다.
- `TextFormatter`/`TextLine`과 indexed glyph 정보를 사용해 full-context advance를 얻는다.
- 필요한 경우 WPF `FormattedText` 또는 glyph 정보를 사용해 segment prefix/grapheme fit advance를 만든다.
- tab, terminal letter spacing, soft-hyphen paint advance를 별도로 저장한다.
- font fallback은 WPF가 선택한 실제 glyph 결과를 따른다.
- visual tree, `TextBlock.ActualWidth`, `Measure`/`Arrange`, Dispatcher round-trip은 사용하지 않는다.

준비 완료 후 formatter와 `TextLine`은 보관하지 않는다. 숫자·kind·cursor·읽기 전용 문자열 정보만 남겨 prepared 객체를 다른 스레드에서도 안전하게 읽을 수 있게 한다.

### 6.3 캐시

분석·측정 캐시는 process-wide로 공유하되 key에 전체 스타일과 DPI를 포함한다. prepared 객체는 캐시의 가변 내부 상태를 노출하지 않는다. `ClearCaches()`는 분석·측정·line materialization 캐시를 비운다.

## 7. 산술 레이아웃

`Layout`은 준비된 segment의 폭, line-end advance, breakable grapheme advance, break policy만 사용한다.

고정 규칙:

- trailing collapsible whitespace는 line fit을 강제하지 않는다.
- preserved whitespace는 보이는 폭을 가진다.
- soft hyphen이 선택된 break일 때만 보이는 하이픈 폭을 더한다.
- overlong run은 선호 break를 먼저 사용하고 마지막에 grapheme emergency break를 사용한다.
- zero-width width에서도 cursor가 반드시 전진한다.
- hard break chunk는 다음 호출의 시작 cursor를 정확히 정규화한다.
- `Layout`, `LayoutWithLines`, range walker, streaming API는 같은 break 결정을 공유한다.

줄 문자열 생성은 명시적인 materialization API에서만 수행한다. 범위 통계 경로는 문자열을 만들지 않는다.

## 8. 갤러리 셸

- WPF-UI `NavigationView`에서 9개 데모를 선택한다.
- 기본 창은 Windows 데스크톱에서 사용하기 적합한 크기로 열리고, 최소 크기 이하에서는 스크롤 또는 축약 레이아웃을 사용한다.
- 페이지별 ViewModel 상태를 유지한다.
- animated page는 `IDemoLifecycle`을 구현한다.
  - `Activate`: render subscription과 timer 시작
  - `Deactivate`: subscription과 timer 해제
- 페이지를 떠난 뒤 `CompositionTarget.Rendering` 구독이 남아 있지 않아야 한다.
- 셸의 Fluent 스타일이 데모 내부의 고유 디자인을 덮어쓰지 않는다.

## 9. 데모별 설계

### 9.1 Accordion

- 네 개 section과 원본 설명·measurement label을 재현한다.
- engine이 계산한 line count와 height로 닫힘/열림 높이를 결정한다.
- `ActualHeight`를 읽어 목표 높이를 정하는 방식은 금지한다.
- 키보드 Space/Enter와 focus visual을 지원한다.

### 9.2 Bubbles

- WPF 기본 fit-content에 해당하는 기준 bubble과 Pretext shrink-wrap bubble을 나란히 표시한다.
- container width slider를 제공한다.
- 같은 line count를 유지하는 최소 폭을 탐색한다.
- 두 방식의 사용 면적과 wasted pixels를 실시간 표시한다.

### 9.3 Dynamic Layout

- 고정 높이 editorial spread와 원본 제목·본문을 재현한다.
- 장애물 영역에 따라 줄마다 다른 폭으로 title/body를 연속 배치한다.
- 창의 가로·세로 resize에 대응한다.
- 로고 클릭으로 장애물 구성이 바뀌고 즉시 재레이아웃된다.
- 텍스트와 장식은 WPF `DrawingContext` 기반 surface에서 그린다.

### 9.4 Variable Typographic ASCII

- 하나의 particle/attractor brightness field를 모든 패널이 공유한다.
- Georgia 계열의 세 weight와 italic 조합을 WPF 네이티브 측정 결과로 선택한다.
- monospace 비교 패널을 함께 표시한다.
- `CompositionTarget.Rendering`에서 프레임을 갱신하고 숨겨진 동안 중지한다.

### 9.5 Editorial Engine

- 움직이는 orb, pull quote, live reflow, multi-column flow를 재현한다.
- orb와 quote가 만드는 obstacle에 따라 줄 폭을 바꾼다.
- 많은 `TextBlock`/`Shape`를 만들지 않고 경량 drawing surface를 사용한다.
- resize와 animation 중에도 prepare를 불필요하게 반복하지 않는다.

### 9.6 Justification Comparison

- WPF 기본 justification/greedy, soft-hyphen greedy, Knuth–Plass 계열 배치를 병렬 표시한다.
- column width slider와 river visualizer toggle을 제공한다.
- 마지막 줄은 강제 justification하지 않는다.
- custom column은 요청 폭을 넘겨 그리지 않는다.

### 9.7 Rich Text

- 일반 text, link, code span, mention/chip을 rich-inline item으로 구성한다.
- 폭 slider를 조절해도 atomic chip은 분할되지 않는다.
- inline item별 style과 source item ownership을 보존한다.
- 링크는 WPF command를 통해 안전한 HTTP(S) URI만 연다.

### 9.8 Markdown Chat

- Markdig AST를 UI 표시 모델로 변환한다.
- paragraph inline content는 rich-inline engine을 사용한다.
- fenced code는 `PreWrap` 준비 데이터를 사용한다.
- message bubble height를 사전 계산해 recycling virtualization과 scroll anchoring에 사용한다.
- virtualization mask toggle로 materialized viewport를 시각화한다.
- 링크는 HTTP(S)만 허용한다.

### 9.9 Masonry

- 원본 shower-thought data를 로컬 JSON 리소스로 포함한다.
- 카드 높이를 엔진으로 미리 계산하고 열별 누적 높이가 가장 짧은 곳에 배치한다.
- viewport 밖 카드는 visual tree에 만들지 않는다.
- scroll 중 DOM식 재측정에 해당하는 WPF layout read를 하지 않는다.

## 10. 시각 디자인

갤러리 셸만 Fluent 계열로 통일한다. 각 데모 내부는 원본의 색상, 글꼴 계층, 여백, 카드 모양, 애니메이션 성격을 보존한다.

원본에서 Windows에 없는 Helvetica 계열은 Segoe UI로 매핑한다. Georgia와 고정폭 텍스트는 Windows 기본 글꼴을 우선한다. 외부 네트워크 글꼴을 내려받지 않는다.

모든 텍스트·JSON·로고는 로컬 리소스로 포함해 오프라인으로 실행한다.

## 11. 오류 처리

- `null` 입력은 `ArgumentNullException`이다.
- `NaN`, 음의 폭·글꼴 크기·행 높이, 유효하지 않은 DPI는 명시적인 범위 예외다.
- 빈 문자열은 `lineCount = 0`, `height = 0`이다.
- 매우 좁은 폭과 oversized atomic item에서도 한 grapheme 또는 한 item은 진행한다.
- 글꼴 미설치는 WPF font fallback을 사용한다.
- render loop와 command 예외는 삼키지 않는다. 데모명과 단계가 포함된 오류 상태를 표시하고 디버그 출력에 남긴다.
- 외부 URI는 절대 HTTP(S) URI만 허용한다.

## 12. 테스트 전략

테스트 이름은 `Method_Scenario_Expected` 형식을 사용하고 Happy/Boundary/Error 분류를 유지한다.

### 12.1 불변식 테스트

- 공백 collapse와 `PreWrap`
- empty input과 hard break chunk
- emergency grapheme progress
- ZWSP와 soft hyphen
- tab stop
- terminal letter spacing
- CJK kinsoku와 `KeepAll`
- 숫자·URL·기호 run
- RTL metadata
- streaming cursor continuity
- 모든 layout API의 break 동등성
- rich-inline item ownership과 atomic item

### 12.2 WPF 오라클 테스트

Latin, 한글, 중국어, 일본어, Thai, Arabic, Hebrew, emoji, 혼합 script 문장을 여러 폭에서 준비한다. 엔진의 break cursor·line count·paint width를 WPF `TextFormatter` 결과와 비교한다.

DPI는 최소 100%, 125%, 150% 조건을 포함한다. font fallback이 필요한 문자도 포함한다.

### 12.3 성능·allocation 테스트

- `Layout`은 준비 후 WPF 측정 서비스를 호출하지 않는다.
- warmed-up `Layout` 호출의 managed allocation은 0이다.
- range-only API는 line string을 만들지 않는다.
- benchmark는 prepare, layout, layout-with-lines, rich range, WPF 직접 포맷을 분리한다.

### 12.4 아키텍처 검증

- 핵심 프로젝트의 MSBuild target은 `PackageReference` 또는 `ProjectReference`가 하나라도 있으면 build를 실패시킨다.
- 테스트는 빌드된 `Pretext.Wpf.dll`의 assembly-reference metadata를 읽어 .NET/WPF framework 이외의 런타임 의존성이 없는지 검증한다.

## 13. 실행 검증

완료 전에 다음을 실제 실행한다.

1. 전체 솔루션 build
2. 전체 test suite
3. benchmark smoke 실행
4. WPF 앱 실행
5. 9개 페이지 모두 탐색
6. Accordion 열기/닫기
7. Bubbles, Justification, Rich Text slider 이동
8. Justification river toggle
9. Dynamic Layout 로고 클릭과 창 resize
10. Markdown Chat mask toggle과 긴 스크롤
11. Masonry 긴 스크롤
12. animated page 진입·이탈 후 render subscription 해제 확인
13. 대표 화면을 원본 라이브 데모와 시각 비교

## 14. 완료 기준

- `Pretext.Wpf` 핵심 프로젝트가 WPF/BCL만 사용한다.
- 승인된 공개 API가 구현되어 있다.
- 원본이 지원하는 텍스트 옵션과 break 기능이 WPF 기준으로 동작한다.
- hot layout 경로가 준비된 숫자 데이터만 사용하고 allocation-free다.
- 9개 데모가 단일 갤러리에서 오프라인 실행된다.
- 각 데모의 주요 인터랙션과 원본 디자인 성격이 보존된다.
- 정확도·회귀 테스트, 의존성 build rule, 빌드 산출물 assembly audit가 통과한다.
- benchmark smoke와 앱 smoke가 통과한다.
- 원본 MIT 고지와 기준 커밋이 포함된다.

## 15. 비목표

- 브라우저와 WPF의 픽셀 결과를 동일하게 강제하지 않는다.
- CSS 전체 inline formatting context를 구현하지 않는다.
- 자동 언어별 hyphenation 사전을 새로 만들지 않는다. 원본과 같이 soft hyphen 입력을 사용한다.
- 서버 측 또는 비-Windows 렌더링을 제공하지 않는다.
- 원본 Bun 개발 서버와 정적 웹사이트를 함께 유지하지 않는다.
