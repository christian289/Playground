# Pretext WPF 테스트 인벤토리

| ID | 분류 | 테스트 | 보호 계약 | 상태 |
|---|---|---|---|---|
| ARCH-001 | Error | `IsAllowed_FrameworkAndWpfAssemblies_ExpectedPolicy` | 핵심 DLL 허용 assembly allowlist | Passing |
| ARCH-002 | Error | `CoreAssembly_ReferencesOnlyFrameworkAndWpfAssemblies_Expected` | 핵심 DLL third-party 참조 금지 | Passing |
| AN-001 | Error | `TextStyle_InvalidValues_Throws` | 공개 style 입력 검증 | Planned |
| AN-002 | Error | `PrepareOptions_InvalidValues_Throws` | 공개 option 입력 검증 | Planned |
| AN-003 | Happy | `Analyze_MixedUnicode_MapsUtf16AndGraphemes` | UTF-16/grapheme 불변식 | Planned |
| AN-004 | Boundary | `Segment_UnicodeScripts_UsesExpectedBreaks` | STA/CJK/Thai/Lao/Khmer/Myanmar 줄 경계 | Planned |
| BIDI-001 | Happy | `ComputeSegmentLevels_MixedHebrewLatin_ExpectedLevels` | 혼합 bidi level | Planned |
| BIDI-002 | Boundary | `ComputeSegmentLevels_BracketsAndEmoji_ExpectedLevels` | bracket/astral 처리 | Planned |
| BIDI-003 | Error | `ComputeSegmentLevels_InvalidOffsets_Throws` | bidi 입력 범위 검증 | Planned |
| MEAS-001 | Happy | `Measure_SegmentsOnSta_ReturnsFiniteAdvances` | WPF shaping 측정 | Planned |
| MEAS-002 | Boundary | `Measure_StyledBoundaries_PreservesWidths` | style boundary 측정 | Planned |
| MEAS-003 | Happy | `Measure_RepeatedRequest_UsesCache` | 측정 cache 재사용 | Planned |
| MEAS-004 | Error | `Measure_NonStaThread_Throws` | STA 실행 계약 | Planned |
| LAY-001 | Happy | `Prepare_Text_CompilesImmutableSegments` | prepared 불변 handle | Planned |
| LAY-002 | Boundary | `Layout_WrapCases_MatchesExpectedRanges` | 줄바꿈 핵심 경계 | Planned |
| LAY-003 | Boundary | `LayoutNextLineRange_Cursor_ContinuesStreaming` | streaming cursor | Planned |
| LAY-004 | Error | `Layout_InvalidArguments_Throws` | layout guard matrix | Planned |
| LAY-005 | Happy | `Layout_WarmedPreparedText_AllocatesZeroBytes` | hot-path 0 B/op | Planned |
| RICH-001 | Error | `RichInline_InvalidArguments_Throws` | rich API guard matrix | Planned |
| RICH-002 | Happy | `RichInline_StyledItems_MaterializesOwnedFragments` | fragment ownership/spacing | Planned |
| RICH-003 | Boundary | `RichInline_ChipsAndBidi_PreservesAtomicRanges` | chip/bidi/letter spacing | Planned |
| RICH-004 | Happy | `RichInline_WarmedPrepared_AllocatesZeroBytes` | rich hot-path 0 B/op | Planned |
| ORACLE-001 | Happy | `Oracle_RepresentativeCorpus_MatchesWpfLayout` | WPF oracle range/height parity | Planned |
| ORACLE-002 | Boundary | `Oracle_UnicodeCorpus_MatchesWpfLayout` | Unicode corpus parity | Planned |
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
