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

## 데모 앱 — Pretext Playground 재현

`Pretext.Wpf.Demo`는 pretext.cool에 배포된 커뮤니티 쇼케이스
"Pretext Playground"(0xNyk)를 WPF로 재현한 것이다(배포 번들 캡처 기반 —
`upstream-manifest.json`의 pretext.cool source 참고). 탭 3개:

- **Dragon** — pretext 레이아웃으로 조판된 페이지의 모든 글자가 물리 파티클이 되고,
  마우스를 따라오는 ASCII 용, 클릭 유지 화염(글자 점화·잔불·화면 흔들림), 적 4종+점수,
  룬, 원근 텍스트 터널, 커스텀 커서, 프리셋 6종 + 설정 패널(P/Esc) 포함.
- **ASCII Animations** — Matrix Rain / Text Wave / Text Morph / Particle Text /
  Typewriter 5개 씬. Typewriter는 매 프레임 `Prepare`+`LayoutWithLines`로 줄바꿈을
  다시 계산하고 `WalkLineRanges`로 shrinkwrap 폭을 측정한다.
- **Layout Lab** — 기존 smoke surface(`PretextTextSurface`) 유지.

이전에 계획만 있던 9종 upstream 갤러리(accordion·bubbles·masonry 등, APP-001~017)는
이 재현으로 대체되어 폐기했다.

| ID | 분류 | 테스트 | 보호 계약 | 상태 |
|---|---|---|---|---|
| APP-001 | Manual | 탭 3종 전환·렌더 smoke (UIA+스크린샷) | 셸/탭/렌더 루프 lifecycle | Passing (manual, Windows) |
| APP-002 | Manual | Dragon 설정 패널 열기·Chaos 프리셋 적용 smoke | 패널 바인딩/프리셋 | Passing (manual, Windows) |
| APP-003 | Manual | ASCII 5씬 전환 smoke (씬별 스크린샷) | ascii 씬 동작 | Passing (manual, Windows) |
| APP-004 | Manual | 창 760×900 resize 시 1열 재레이아웃 smoke | resize→Prepare/Layout 경로 | Passing (manual, Windows) |

화염 분사(클릭 유지)와 P/Esc 키보드 토글은 실제 포인터/키 입력이 필요해 자동 스크린샷
검증에서 제외했다 — 코드 경로는 업스트림 번들을 그대로 포팅했고, 수동 확인을 권장한다.
