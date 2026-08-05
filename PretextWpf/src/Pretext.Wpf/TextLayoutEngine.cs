using System.Globalization;
using System.Text;
using System.Windows;

namespace Pretext.Wpf;

/// <summary>
/// Two-phase text layout, ported from upstream pretext <c>layout.ts</c>.
/// <para>
/// <see cref="Prepare(string, TextStyle, PrepareOptions)"/> segments the text,
/// measures each segment through the WPF text formatter, and caches the widths.
/// Call once when a text block first appears.
/// </para>
/// <para>
/// <see cref="Layout(PreparedText, double, double)"/> walks the cached widths
/// with pure arithmetic to count lines and compute height — no formatter calls,
/// no string operations, no allocations. Call on every resize.
/// </para>
/// </summary>
public static class TextLayoutEngine
{
    private enum BreakableFitMode
    {
        SumGraphemes,
        SegmentPrefixes,
        PairContext,
    }

    public static PreparedText Prepare(string text, TextStyle style, PrepareOptions options = default)
    {
        ArgumentNullException.ThrowIfNull(text);
        ArgumentNullException.ThrowIfNull(style);
        return Prepare(text, WpfTextMeasurer.GetOrCreate(style), style.Culture, style.FlowDirection, options);
    }

    public static PreparedTextWithSegments PrepareWithSegments(string text, TextStyle style, PrepareOptions options = default)
    {
        ArgumentNullException.ThrowIfNull(text);
        ArgumentNullException.ThrowIfNull(style);
        return PrepareWithSegments(text, WpfTextMeasurer.GetOrCreate(style), style.Culture, style.FlowDirection, options);
    }

    internal static PreparedText Prepare(string text, ISegmentMeasurer measurer, CultureInfo culture, PrepareOptions options)
    {
        return PrepareInternal(text, measurer, culture, FlowDirection.LeftToRight, includeSegments: false, options);
    }

    internal static PreparedText Prepare(string text, ISegmentMeasurer measurer, CultureInfo culture, FlowDirection flowDirection, PrepareOptions options)
    {
        return PrepareInternal(text, measurer, culture, flowDirection, includeSegments: false, options);
    }

    internal static PreparedTextWithSegments PrepareWithSegments(string text, ISegmentMeasurer measurer, CultureInfo culture, PrepareOptions options)
    {
        return PrepareWithSegments(text, measurer, culture, FlowDirection.LeftToRight, options);
    }

    internal static PreparedTextWithSegments PrepareWithSegments(string text, ISegmentMeasurer measurer, CultureInfo culture, FlowDirection flowDirection, PrepareOptions options)
    {
        return (PreparedTextWithSegments)PrepareInternal(text, measurer, culture, flowDirection, includeSegments: true, options);
    }

    /// <summary>
    /// Layout prepared text at a given max width and caller-provided line height.
    /// Pure arithmetic on cached widths; the hot resize path stays specialized
    /// and allocation-free while <see cref="LayoutWithLines"/> shares the same
    /// break semantics with extra per-line bookkeeping.
    /// </summary>
    public static LayoutResult Layout(PreparedText prepared, double maxWidth, double lineHeight)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardMaxWidth(maxWidth);
        Guard.NonNegativeFinite(lineHeight, nameof(lineHeight));

        int lineCount = LineWalker.CountLines(prepared, maxWidth);
        return new LayoutResult(lineCount, lineCount * lineHeight);
    }

    /// <summary>
    /// Rich layout for callers that want the actual line contents and widths.
    /// Mirrors <see cref="Layout"/>'s break decisions; keep it off the resize hot path.
    /// </summary>
    public static LayoutLinesResult LayoutWithLines(PreparedTextWithSegments prepared, double maxWidth, double lineHeight)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardMaxWidth(maxWidth);
        Guard.NonNegativeFinite(lineHeight, nameof(lineHeight));

        List<LayoutLine> lines = new();
        if (prepared.SegmentCount == 0)
        {
            return new LayoutLinesResult(0, 0, lines);
        }

        int lineCount = LineWalker.WalkLines(
            prepared,
            maxWidth,
            (width, startSegmentIndex, startGraphemeIndex, endSegmentIndex, endGraphemeIndex) =>
                lines.Add(CreateLayoutLine(
                    prepared,
                    width,
                    startSegmentIndex,
                    startGraphemeIndex,
                    endSegmentIndex,
                    endGraphemeIndex)));

        return new LayoutLinesResult(lineCount, lineCount * lineHeight, lines);
    }

    /// <summary>
    /// Batch low-level line-range pass; the non-materializing counterpart to
    /// <see cref="LayoutWithLines"/> for shrinkwrap and aggregate stats work.
    /// Returns the line count.
    /// </summary>
    public static int WalkLineRanges(PreparedTextWithSegments prepared, double maxWidth, LineRangeVisitor onLine)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        ArgumentNullException.ThrowIfNull(onLine);
        GuardMaxWidth(maxWidth);

        if (prepared.SegmentCount == 0)
        {
            return 0;
        }

        return LineWalker.WalkLines(
            prepared,
            maxWidth,
            (width, startSegmentIndex, startGraphemeIndex, endSegmentIndex, endGraphemeIndex) =>
            {
                LayoutLineRange line = new(
                    width,
                    new LayoutCursor(startSegmentIndex, startGraphemeIndex),
                    new LayoutCursor(endSegmentIndex, endGraphemeIndex));
                onLine(in line);
            });
    }

    public static LineStats MeasureLineStats(PreparedTextWithSegments prepared, double maxWidth)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardMaxWidth(maxWidth);
        return LineWalker.MeasureLineGeometry(prepared, maxWidth);
    }

    /// <summary>
    /// Intrinsic-width helper: how wide is the prepared text when container
    /// width is not the thing forcing wraps? Explicit hard breaks still count,
    /// so this returns the widest forced line.
    /// </summary>
    public static double MeasureNaturalWidth(PreparedTextWithSegments prepared)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        return LineWalker.MeasureLineGeometry(prepared, double.PositiveInfinity).MaxLineWidth;
    }

    public static LayoutLine? LayoutNextLine(PreparedTextWithSegments prepared, LayoutCursor start, double maxWidth)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardCursor(prepared, start);
        GuardMaxWidth(maxWidth);

        LineBreakCursor end = new(start.SegmentIndex, start.GraphemeIndex);
        int chunkIndex = LineWalker.NormalizeLineStart(prepared, ref end);
        if (chunkIndex < 0)
        {
            return null;
        }

        int lineStartSegmentIndex = end.SegmentIndex;
        int lineStartGraphemeIndex = end.GraphemeIndex;
        double? width = LineWalker.StepLineGeometryFromChunk(prepared, ref end, chunkIndex, maxWidth);
        if (width is null)
        {
            return null;
        }

        return CreateLayoutLine(
            prepared,
            width.Value,
            lineStartSegmentIndex,
            lineStartGraphemeIndex,
            end.SegmentIndex,
            end.GraphemeIndex);
    }

    public static LayoutLineRange? LayoutNextLineRange(PreparedTextWithSegments prepared, LayoutCursor start, double maxWidth)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardCursor(prepared, start);
        GuardMaxWidth(maxWidth);

        LineBreakCursor end = new(start.SegmentIndex, start.GraphemeIndex);
        int chunkIndex = LineWalker.NormalizeLineStart(prepared, ref end);
        if (chunkIndex < 0)
        {
            return null;
        }

        int lineStartSegmentIndex = end.SegmentIndex;
        int lineStartGraphemeIndex = end.GraphemeIndex;
        double? width = LineWalker.StepLineGeometryFromChunk(prepared, ref end, chunkIndex, maxWidth);
        if (width is null)
        {
            return null;
        }

        return new LayoutLineRange(
            width.Value,
            new LayoutCursor(lineStartSegmentIndex, lineStartGraphemeIndex),
            new LayoutCursor(end.SegmentIndex, end.GraphemeIndex));
    }

    public static LayoutLine MaterializeLineRange(PreparedTextWithSegments prepared, in LayoutLineRange line)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardCursor(prepared, line.Start);
        GuardCursor(prepared, line.End);

        return CreateLayoutLine(
            prepared,
            line.Width,
            line.Start.SegmentIndex,
            line.Start.GraphemeIndex,
            line.End.SegmentIndex,
            line.End.GraphemeIndex);
    }

    public static void ClearCaches()
    {
        TextAnalyzer.ClearCache();
        WpfTextMeasurer.ClearCaches();
    }

    private static LayoutLine CreateLayoutLine(
        PreparedTextWithSegments prepared,
        double width,
        int startSegmentIndex,
        int startGraphemeIndex,
        int endSegmentIndex,
        int endGraphemeIndex)
    {
        return new LayoutLine(
            LineTextMaterializer.BuildLineText(
                prepared,
                startSegmentIndex,
                startGraphemeIndex,
                endSegmentIndex,
                endGraphemeIndex),
            width,
            new LayoutCursor(startSegmentIndex, startGraphemeIndex),
            new LayoutCursor(endSegmentIndex, endGraphemeIndex));
    }

    private static void GuardMaxWidth(double maxWidth)
    {
        if (double.IsNaN(maxWidth) || maxWidth < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxWidth), maxWidth, "Max width must be non-negative (positive infinity is allowed).");
        }
    }

    private static void GuardCursor(PreparedText prepared, LayoutCursor cursor)
    {
        if (cursor.SegmentIndex < 0 || cursor.SegmentIndex > prepared.SegmentCount || cursor.GraphemeIndex < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(cursor), cursor, "Cursor is outside the prepared segment range.");
        }
    }

    // --- Prepare pipeline (port of layout.ts measureAnalysis) ---

    private static PreparedText PrepareInternal(
        string text,
        ISegmentMeasurer measurer,
        CultureInfo culture,
        FlowDirection flowDirection,
        bool includeSegments,
        PrepareOptions options)
    {
        ArgumentNullException.ThrowIfNull(measurer);
        ArgumentNullException.ThrowIfNull(culture);
        Guard.DefinedEnum(flowDirection, nameof(flowDirection));

        TextAnalysis analysis = TextAnalyzer.Analyze(text, culture, options.WhiteSpace, options.WordBreak);
        return MeasureAnalysis(analysis, measurer, flowDirection, includeSegments, options.WordBreak, options.LetterSpacing);
    }

    private static PreparedText MeasureAnalysis(
        TextAnalysis analysis,
        ISegmentMeasurer measurer,
        FlowDirection flowDirection,
        bool includeSegments,
        WordBreakMode wordBreak,
        double letterSpacing)
    {
        double discretionaryHyphenWidth =
            measurer.MeasureSegment("-") + (letterSpacing == 0 ? 0 : letterSpacing * 2);
        double tabStopAdvance = measurer.MeasureSegment(" ") * 8;
        bool hasLetterSpacing = letterSpacing != 0;

        if (analysis.Length == 0)
        {
            return CreateEmptyPrepared(includeSegments, letterSpacing, discretionaryHyphenWidth, tabStopAdvance);
        }

        int count = analysis.Length;
        List<double> widths = new(count);
        List<double> lineEndFitAdvances = new(count);
        List<double> lineEndPaintAdvances = new(count);
        List<SegmentBreakKind> kinds = new(count);
        bool simpleLineWalkFastPath = !hasLetterSpacing;
        List<int>? segmentStarts = includeSegments ? new List<int>(count) : null;
        List<double[]?> breakableFitAdvances = new(count);
        List<int[]?> breakablePreferredBreaks = new(count);
        List<int> spacingGraphemeCounts = hasLetterSpacing ? new List<int>(count) : new List<int>();
        List<string>? segments = includeSegments ? new List<string>(count) : null;
        List<PreparedLineChunk> chunks = new();
        int chunkStartSegmentIndex = 0;

        void PushMeasuredSegment(
            string segmentText,
            double width,
            double lineEndFitAdvance,
            double lineEndPaintAdvance,
            SegmentBreakKind kind,
            int start,
            double[]? fitAdvances,
            int[]? preferredBreaks,
            int spacingGraphemeCount)
        {
            if (kind is not SegmentBreakKind.Text and not SegmentBreakKind.Space and not SegmentBreakKind.ZeroWidthBreak)
            {
                simpleLineWalkFastPath = false;
            }

            widths.Add(width);
            lineEndFitAdvances.Add(lineEndFitAdvance);
            lineEndPaintAdvances.Add(lineEndPaintAdvance);
            kinds.Add(kind);
            segmentStarts?.Add(start);
            breakableFitAdvances.Add(fitAdvances);
            breakablePreferredBreaks.Add(preferredBreaks);
            if (hasLetterSpacing)
            {
                spacingGraphemeCounts.Add(spacingGraphemeCount);
            }

            segments?.Add(segmentText);
        }

        void PushMeasuredTextSegment(
            string segmentText,
            SegmentBreakKind kind,
            int start,
            bool wordLike,
            bool allowOverflowBreaks)
        {
            int spacingGraphemeCount = hasLetterSpacing
                ? CountRenderedSpacingGraphemes(segmentText, kind)
                : 0;
            double width = AddInternalLetterSpacing(
                measurer.MeasureSegment(segmentText),
                spacingGraphemeCount,
                letterSpacing);
            double baseLineEndFitAdvance =
                kind is SegmentBreakKind.Space or SegmentBreakKind.PreservedSpace or SegmentBreakKind.ZeroWidthBreak
                    ? 0
                    : width;
            double lineEndFitAdvance =
                baseLineEndFitAdvance == 0
                    ? 0
                    : baseLineEndFitAdvance + (spacingGraphemeCount > 0 ? letterSpacing : 0);
            double lineEndPaintAdvance =
                kind is SegmentBreakKind.Space or SegmentBreakKind.ZeroWidthBreak
                    ? 0
                    : width;

            if (allowOverflowBreaks && wordLike && segmentText.Length > 1)
            {
                BreakableFitMode fitMode = BreakableFitMode.SumGraphemes;
                if (letterSpacing != 0)
                {
                    fitMode = BreakableFitMode.SegmentPrefixes;
                }
                else if (IsNumericRunSegment(segmentText))
                {
                    fitMode = BreakableFitMode.PairContext;
                }

                double[]? fitAdvances = GetSegmentBreakableFitAdvances(segmentText, measurer, fitMode);
                int[]? preferredBreaks =
                    fitAdvances is null || wordBreak == WordBreakMode.KeepAll
                        ? null
                        : GetBreakablePreferredBreaks(segmentText);
                PushMeasuredSegment(
                    segmentText,
                    width,
                    lineEndFitAdvance,
                    lineEndPaintAdvance,
                    kind,
                    start,
                    fitAdvances,
                    preferredBreaks,
                    spacingGraphemeCount);
                return;
            }

            PushMeasuredSegment(
                segmentText,
                width,
                lineEndFitAdvance,
                lineEndPaintAdvance,
                kind,
                start,
                null,
                null,
                spacingGraphemeCount);
        }

        for (int index = 0; index < count; index++)
        {
            string segmentText = analysis.Texts[index];
            bool segmentWordLike = analysis.IsWordLike[index];
            SegmentBreakKind segmentKind = analysis.Kinds[index];
            int segmentStart = analysis.Starts[index];

            if (segmentKind == SegmentBreakKind.SoftHyphen)
            {
                PushMeasuredSegment(
                    segmentText,
                    0,
                    discretionaryHyphenWidth,
                    discretionaryHyphenWidth,
                    segmentKind,
                    segmentStart,
                    null,
                    null,
                    0);
                continue;
            }

            if (segmentKind == SegmentBreakKind.HardBreak)
            {
                int endSegmentIndex = widths.Count;
                PushMeasuredSegment(segmentText, 0, 0, 0, segmentKind, segmentStart, null, null, 0);
                chunks.Add(new PreparedLineChunk(chunkStartSegmentIndex, endSegmentIndex, widths.Count));
                chunkStartSegmentIndex = widths.Count;
                continue;
            }

            if (segmentKind == SegmentBreakKind.Tab)
            {
                PushMeasuredSegment(
                    segmentText,
                    0,
                    0,
                    0,
                    segmentKind,
                    segmentStart,
                    null,
                    null,
                    hasLetterSpacing ? CountRenderedSpacingGraphemes(segmentText, segmentKind) : 0);
                continue;
            }

            // Analysis already splits CJK words into per-grapheme break units with
            // kinsoku/punctuation merging applied (upstream does this at measure
            // time), so the only remaining CJK decision is overflow breaking:
            // CJK units stay atomic under word-break: normal.
            bool allowOverflowBreaks =
                wordBreak == WordBreakMode.KeepAll || !ContainsCjk(segmentText);

            // Scripts written without spaces (Thai, Lao, Khmer, Myanmar) carry no
            // break opportunities of their own. The analyzer flags those runs; ask
            // the measurer for the platform dictionary's word boundaries and emit
            // one segment per word, mirroring what Intl.Segmenter gives upstream.
            if (wordBreak != WordBreakMode.KeepAll
                && IsNativeWordBreakRun(analysis, segmentStart, segmentText.Length))
            {
                int[]? breakOffsets = measurer.GetNativeBreakOffsets(segmentText);
                if (breakOffsets is { Length: > 0 })
                {
                    int wordStart = 0;
                    for (int breakIndex = 0; breakIndex <= breakOffsets.Length; breakIndex++)
                    {
                        int wordEnd = breakIndex < breakOffsets.Length
                            ? breakOffsets[breakIndex]
                            : segmentText.Length;
                        if (wordEnd <= wordStart || wordEnd > segmentText.Length)
                        {
                            continue;
                        }

                        PushMeasuredTextSegment(
                            segmentText[wordStart..wordEnd],
                            segmentKind,
                            segmentStart + wordStart,
                            segmentWordLike,
                            allowOverflowBreaks);
                        wordStart = wordEnd;
                    }

                    continue;
                }
            }

            PushMeasuredTextSegment(segmentText, segmentKind, segmentStart, segmentWordLike, allowOverflowBreaks);
        }

        if (chunkStartSegmentIndex < widths.Count)
        {
            chunks.Add(new PreparedLineChunk(chunkStartSegmentIndex, widths.Count, widths.Count));
        }

        if (segments is null)
        {
            return new PreparedText(
                widths.ToArray(),
                lineEndFitAdvances.ToArray(),
                lineEndPaintAdvances.ToArray(),
                kinds.ToArray(),
                simpleLineWalkFastPath,
                breakableFitAdvances.ToArray(),
                breakablePreferredBreaks.ToArray(),
                letterSpacing,
                spacingGraphemeCounts.ToArray(),
                discretionaryHyphenWidth,
                tabStopAdvance,
                chunks.ToArray());
        }

        sbyte[]? segmentLevels = BidiLevelResolver.ComputeSegmentLevels(
            analysis.Normalized,
            segmentStarts!.ToArray(),
            flowDirection);
        return new PreparedTextWithSegments(
            widths.ToArray(),
            lineEndFitAdvances.ToArray(),
            lineEndPaintAdvances.ToArray(),
            kinds.ToArray(),
            simpleLineWalkFastPath,
            breakableFitAdvances.ToArray(),
            breakablePreferredBreaks.ToArray(),
            letterSpacing,
            spacingGraphemeCounts.ToArray(),
            discretionaryHyphenWidth,
            tabStopAdvance,
            chunks.ToArray(),
            segments.ToArray(),
            segmentLevels);
    }

    private static PreparedText CreateEmptyPrepared(
        bool includeSegments,
        double letterSpacing,
        double discretionaryHyphenWidth,
        double tabStopAdvance)
    {
        if (includeSegments)
        {
            return new PreparedTextWithSegments(
                Array.Empty<double>(),
                Array.Empty<double>(),
                Array.Empty<double>(),
                Array.Empty<SegmentBreakKind>(),
                simpleLineWalkFastPath: true,
                Array.Empty<double[]?>(),
                Array.Empty<int[]?>(),
                letterSpacing,
                Array.Empty<int>(),
                discretionaryHyphenWidth,
                tabStopAdvance,
                Array.Empty<PreparedLineChunk>(),
                Array.Empty<string>(),
                segmentLevels: null);
        }

        return new PreparedText(
            Array.Empty<double>(),
            Array.Empty<double>(),
            Array.Empty<double>(),
            Array.Empty<SegmentBreakKind>(),
            simpleLineWalkFastPath: true,
            Array.Empty<double[]?>(),
            Array.Empty<int[]?>(),
            letterSpacing,
            Array.Empty<int>(),
            discretionaryHyphenWidth,
            tabStopAdvance,
            Array.Empty<PreparedLineChunk>());
    }

    private static double AddInternalLetterSpacing(double width, int graphemeCount, double letterSpacing)
    {
        return graphemeCount > 1 ? width + ((graphemeCount - 1) * letterSpacing) : width;
    }

    private static int CountRenderedSpacingGraphemes(string text, SegmentBreakKind kind)
    {
        if (kind is SegmentBreakKind.ZeroWidthBreak or SegmentBreakKind.SoftHyphen or SegmentBreakKind.HardBreak)
        {
            return 0;
        }

        if (kind == SegmentBreakKind.Tab)
        {
            return 1;
        }

        return new GraphemeMap(text).Count;
    }

    private static double[]? GetSegmentBreakableFitAdvances(
        string segmentText,
        ISegmentMeasurer measurer,
        BreakableFitMode mode)
    {
        GraphemeMap graphemes = new(segmentText);
        if (graphemes.Count <= 1)
        {
            return null;
        }

        if (mode == BreakableFitMode.SumGraphemes)
        {
            double[] advances = new double[graphemes.Count];
            for (int i = 0; i < advances.Length; i++)
            {
                advances[i] = measurer.MeasureSegment(graphemes.GetTextElement(i));
            }

            return advances;
        }

        if (mode == BreakableFitMode.PairContext || graphemes.Count > LayoutProfile.MaxPrefixFitGraphemes)
        {
            double[] advances = new double[graphemes.Count];
            string? previousGrapheme = null;
            double previousWidth = 0;

            for (int i = 0; i < advances.Length; i++)
            {
                string grapheme = graphemes.GetTextElement(i);
                double currentWidth = measurer.MeasureSegment(grapheme);

                if (previousGrapheme is null)
                {
                    advances[i] = currentWidth;
                }
                else
                {
                    string pair = string.Concat(previousGrapheme, grapheme);
                    advances[i] = measurer.MeasureSegment(pair) - previousWidth;
                }

                previousGrapheme = grapheme;
                previousWidth = currentWidth;
            }

            return advances;
        }

        double[] prefixAdvances = new double[graphemes.Count];
        double prefixWidth = 0;
        for (int i = 0; i < prefixAdvances.Length; i++)
        {
            double nextPrefixWidth = measurer.MeasureSegment(graphemes.GetPrefixText(i + 1));
            prefixAdvances[i] = nextPrefixWidth - prefixWidth;
            prefixWidth = nextPrefixWidth;
        }

        return prefixAdvances;
    }

    private static int[]? GetBreakablePreferredBreaks(string text)
    {
        List<int>? breaks = null;
        GraphemeMap graphemes = new(text);
        for (int i = 0; i < graphemes.Count; i++)
        {
            if (IsPreferredBreakGrapheme(graphemes.GetTextElement(i)))
            {
                breaks ??= new List<int>();
                breaks.Add(i + 1);
            }
        }

        return breaks?.ToArray();
    }

    private static bool IsPreferredBreakGrapheme(string grapheme)
    {
        return grapheme.Length == 1
            && grapheme[0] is '-' or '\u058A' or '\u2010' or '\u2012' or '\u2013' or '\u2014';
    }

    private static bool IsNumericRunSegment(string text)
    {
        if (text.Length == 0)
        {
            return false;
        }

        foreach (Rune rune in text.EnumerateRunes())
        {
            if (UnicodeClassifier.IsDecimalDigit(rune) || IsNumericJoinerRune(rune))
            {
                continue;
            }

            return false;
        }

        return true;
    }

    private static bool IsNumericJoinerRune(Rune rune)
    {
        return rune.Value is '.' or ',' or ':' or '/' or '+' or '-' or '%' or '$';
    }

    private static bool IsNativeWordBreakRun(TextAnalysis analysis, int start, int length)
    {
        foreach (NativeWordBreakRun run in analysis.NativeWordBreakRuns)
        {
            if (run.Start == start && run.Length == length)
            {
                return true;
            }
        }

        return false;
    }

    private static bool ContainsCjk(string text)
    {
        foreach (Rune rune in text.EnumerateRunes())
        {
            if (UnicodeClassifier.IsCjk(rune) || UnicodeClassifier.IsHangul(rune))
            {
                return true;
            }
        }

        return false;
    }
}
