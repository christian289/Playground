# Pretext WPF 테스트 인벤토리

## 상태 표기

| 표기 | 뜻 |
|---|---|
| Passing (local) | `tools/parity/Parity` 오프라인 러너로 macOS에서 실제 실행해 통과 확인 |
| Windows-only | WPF 런타임(STA·TextFormatter·Typeface)이 필요해 이 개발 환경에서는 실행 불가. 컴파일만 확인 |
| Planned | 미작성 |

`Pretext.Wpf.Tests`는 `net10.0-windows` 대상이라 `Microsoft.WindowsDesktop.App` 런타임이 없는
macOS/Linux에서는 `dotnet test`가 아예 뜨지 않는다. WPF 타입을 만들지 않는 스위트는
`tools/parity/Parity` 러너로 어느 OS에서든 돌릴 수 있다(`tools/parity/README.md` 참고).
Windows에서는 `dotnet test`로 전부 실행된다.

## 코어 라이브러리

| ID | 분류 | 테스트 | 보호 계약 | 상태 |
|---|---|---|---|---|
| ARCH-001 | Error | `IsAllowed_FrameworkAndWpfAssemblies_ExpectedPolicy` | 허용 assembly allowlist 정책 | Windows-only |
| ARCH-002 | Error | `CoreAssembly_ReferencesOnlyFrameworkAndWpfAssemblies_Expected` | 핵심 DLL third-party 참조 금지 | Windows-only |
| API-001 | Error | `TextStyle_NullReferences_ThrowsArgumentNullException` | style null 검증 | Windows-only |
| API-002 | Error | `TextStyle_InvalidNumbers_ThrowsArgumentOutOfRangeException` | fontSize/pixelsPerDip 유한·양수 | Windows-only |
| API-003 | Error | `TextStyle_UndefinedEnums_ThrowsArgumentOutOfRangeException` | enum 정의값 검증 | Windows-only |
| API-004 | Boundary | `TextStyle_MutableCulture_StoresReadOnlyClone` | culture 불변 복제 | Windows-only |
| API-005 | Boundary | `TextStyle_NeutralAndInvariantCultures_PreservesCultureIdentity` | culture 정체성 보존 | Windows-only |
| API-006 | Error | `PrepareOptions_InvalidValues_ThrowsArgumentOutOfRangeException` | option 입력 검증 | Windows-only |
| API-007 | Happy | `LayoutModels_ValueContracts_AreValueTypes` | 공개 모델 값 타입 계약 | Windows-only |
| API-008 | Error | `RichInlineItem_InvalidValues_ThrowsArgumentOutOfRangeException` | rich item 입력 검증 | Windows-only |
| AN-001 | Happy | `Analyze_NormalWhitespace_CollapsesLikeCss` | CSS 공백 축약 | Passing (local) |
| AN-002 | Boundary | `Analyze_PreWrap_PreservesSpacesTabsAndHardBreaks` | pre-wrap 공백·탭·강제개행 | Passing (local) |
| AN-003 | Boundary | `Analyze_SpecialBreakCharacters_PreservesKinds` | ZWSP·soft hyphen 종류 보존 | Passing (local) |
| AN-004 | Boundary | `Analyze_CjkLatinAndNumbers_PreservesOrderedSegments` | CJK/라틴/숫자 분절 순서 | Passing (local) |
| AN-005 | Boundary | `Analyze_ThaiText_MarksNativeWordBreakRun` | 사전 줄바꿈 run 표시 | Passing (local) |
| AN-006 | Boundary | `Analyze_KeepAllHangul_DoesNotSplitHangulRun` | keep-all 한글 run 유지 | Passing (local) |
| AN-007 | Boundary | `GraphemeMap_CombiningAndZwjSequences_DoesNotSplitClusters` | grapheme cluster 불변식 | Passing (local) |
| AN-008 | Happy | `Analyze_RepeatedRequest_UsesImmutableCacheUntilClear` | 분석 cache 수명 | Passing (local) |
| BIDI-001 | Happy | `ComputeSegmentLevels_PureLatinLtr_ReturnsNullOptimization` | 순수 LTR 최적화 | Passing (local) |
| BIDI-002 | Boundary | `ComputeSegmentLevels_PureLatinRtl_ReturnsExplicitLevels` | RTL 문단 방향 | Passing (local) |
| BIDI-003 | Happy | `ComputeSegmentLevels_MixedHebrew_ReturnsOddLevelForHebrewSegment` | 혼합 bidi level | Passing (local) |
| BIDI-004 | Boundary | `ComputeSegmentLevels_ArabicNumbers_ResolvesArabicContext` | 아라비아 숫자 문맥 | Passing (local) |
| BIDI-005 | Boundary | `ComputeSegmentLevels_BracketsAndEmoji_PreservesUtf16Offsets` | bracket/astral offset | Passing (local) |
| BIDI-006 | Error | `ComputeSegmentLevels_InvalidOffsets_ThrowsArgumentOutOfRangeException` | bidi 입력 범위 검증 | Passing (local) |
| BIDI-007 | Boundary | `GeneratedData_CheckedInTables_PreserveSourceShape` | 생성 테이블 형상 | Passing (local) |
| MEAS-001 | Happy | `Measure_SegmentsOnSta_ReturnsFiniteAdvances` | WPF shaping 측정 | Windows-only |
| MEAS-002 | Boundary | `Measure_StyledBoundaries_PreservesWidths` | style 경계별 측정 | Windows-only |
| MEAS-003 | Happy | `Measure_RepeatedRequest_UsesCache` | 측정 cache 재사용 | Windows-only |
| MEAS-004 | Error | `Measure_NonStaThread_Throws` | STA 실행 계약 | Windows-only |
| LAY-001 | Happy | `Prepare_Text_CompilesImmutableSegments` | prepared 불변 handle | Passing (local) |
| LAY-002 | Boundary | `Layout_WrapCases_MatchesExpectedRanges` | 줄바꿈 핵심 경계 6종 | Passing (local) |
| LAY-003 | Boundary | `LayoutNextLineRange_Cursor_ContinuesStreaming` | streaming cursor 동치 | Passing (local) |
| LAY-004 | Error | `Layout_InvalidArguments_Throws` | layout guard matrix | Passing (local) |
| LAY-005 | Happy | `Layout_WarmedPreparedText_AllocatesZeroBytes` | hot-path 0 B/op | Passing (local) |
| RICH-001 | Error | `RichInline_InvalidArguments_Throws` | rich 엔진 guard matrix | Passing (local) |
| RICH-002 | Happy | `RichInline_StyledItems_MaterializesOwnedFragments` | fragment ownership/spacing | Passing (local) |
| RICH-003 | Boundary | `RichInline_ChipsAndBidi_PreservesAtomicRanges` | chip/bidi 원자성 | Passing (local) |
| RICH-004 | Happy | `RichInline_WarmedPrepared_AllocatesZeroBytes` | rich hot-path 할당 예산 | Passing (local) |
| REG-001 | Boundary | `Regression_PortedUpstreamCase_MatchesAnalyzerBehavior` | upstream 분석 동작 19건 고정 | Passing (local) |
| PAR-001 | Boundary | `Layout_UpstreamCorpus_MatchesUpstreamLineBreaking` | upstream 엔진과 줄바꿈 380건 일치 | Passing (local) |
| PAR-002 | Boundary | `RichInline_UpstreamCorpus_MatchesUpstreamFragments` | upstream rich fragment 28건 일치 | Passing (local) |
| ORACLE-001 | Happy | `Oracle_RepresentativeCorpus_MatchesWpfLayout` | 실제 WPF 측정 기반 불변식 | Windows-only |
| ORACLE-002 | Boundary | `Oracle_UnicodeCorpus_MatchesWpfLayout` | Unicode corpus 불변식 | Windows-only |

### upstream 차분(PAR-001/002) 메모

`tools/parity/generate.ts`가 upstream TypeScript 엔진을 upstream 자체의 결정적 fake canvas로
돌려 fixture를 만들고, PAR 테스트가 동일한 측정값으로 포팅 엔진을 돌려 줄 텍스트·폭을 1e-6까지
비교한다. 이 차분으로 잡아 고친 분석 계층 결함 넷:

1. kinsoku-start 문자(`，` `。` `ー` 등)가 앞 CJK 글자에 붙지 않아 줄 첫머리에 오던 문제
2. 통화·퍼센트 affix가 숫자에서 떨어지던 문제(`$42.99`, `₪158.50`)
3. 아라비아 소수점 `٫`(U+066B) 등이 숫자 joiner로 인식되지 않던 문제
4. `can't`, `doesn't` 축약형이 아포스트로피에서 쪼개지던 문제

LAY-002 (b)의 기대값도 이 차분으로 교정했다. 줄바꿈이 공백에서 일어나면 그 공백은 줄 범위에
포함되지만, 텍스트 끝의 공백은 포함되지 않는다(upstream 동작과 일치).

### 공백 없는 문자(Thai·Lao·Khmer·Myanmar)

사전 기반 줄바꿈이 필요한 문자들이다. upstream은 `Intl.Segmenter`를, 이 포트는 WPF에 내장된
줄바꿈 사전을 쓴다(`WpfTextMeasurer.GetNativeBreakOffsets`가 formatter를 탐침해 경계를 얻는다).
`System.Globalization`에는 대응 API가 없다. 엔진 쪽 분할 경로는 fixture에 담긴 ICU 경계로
어느 OS에서든 검증되지만, formatter 탐침 자체는 Windows에서만 실행된다.

## 데모 앱 (다음 마일스톤)

지금 `Pretext.Wpf.Demo`에는 엔진을 대화형으로 확인하는 창 하나(`MainWindow` +
`PretextTextSurface`)만 있다. 아래 9종 데모 갤러리와 그 테스트는 아직 없다.

| ID | 분류 | 테스트 | 보호 계약 | 상태 |
|---|---|---|---|---|
| APP-001 | Error | `DemoExecutionGuard_PhaseFailure_ReportsVisibleError` | 예외 경계와 cleanup | Planned |
| APP-002 | Error | `ViewModelBoundary_PublicSurface_HasNoWpfTypes` | ViewModel WPF 타입 금지 | Planned |
| APP-003 | Happy | `TextLineDrawingBuilder_MixedRuns_PreservesVisualOrder` | bidi glyph drawing | Planned |
| APP-004 | Boundary | `TextSurface_ResizeAndDpi_ReusesPreparedText` | width/DPI cache lifecycle | Planned |
| APP-005 | Happy | `Accordion_Toggle_ReusesPreparedMeasurements` | accordion cache/animation | Planned |
| APP-006 | Happy | `Bubbles_WidthChange_SelectsTightLayout` | bubble width 예측 | Planned |
| APP-007 | Happy | `DynamicLayout_Lifecycle_SubscriptionsAreSymmetric` | render lifecycle | Planned |
| APP-008 | Happy | `VariableAscii_FrameGeneration_IsDeterministic` | ASCII frame parity | Planned |
| APP-009 | Boundary | `Editorial_ObstacleRouting_ProducesValidSlots` | obstacle-aware layout | Planned |
| APP-010 | Boundary | `Justification_Strategies_PreserveContent` | 세 justification 전략 | Planned |
| APP-011 | Error | `SafeUriLauncher_InvalidScheme_Throws` | HTTP(S) URI allowlist | Planned |
| APP-012 | Happy | `MarkdownParser_SupportedAst_ProducesDescriptors` | Markdig AST 변환 | Planned |
| APP-013 | Boundary | `PredictedStack_ViewportChange_RecyclesVisibleRange` | 예측 virtualization | Planned |
| APP-014 | Happy | `Masonry_Assignments_UseShortestColumn` | deterministic masonry | Planned |
| APP-015 | Manual | 9개 데모 탐색·상호작용 smoke | WPF-UI 갤러리 E2E | Planned |
| APP-016 | Manual | 창 resize·DPI·키보드·focus smoke | 접근성/렌더 lifecycle | Planned |
| APP-017 | Manual | Status recorded result 표시 | 검증 artifact provenance | Planned |
