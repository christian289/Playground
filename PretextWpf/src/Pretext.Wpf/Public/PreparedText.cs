namespace Pretext.Wpf;

/// <summary>
/// Internal hard-break chunk hint for the line walker. Segments in
/// [StartSegmentIndex, EndSegmentIndex) lay out as one paragraph;
/// ConsumedEndSegmentIndex additionally covers the hard-break segment itself.
/// </summary>
internal readonly record struct PreparedLineChunk(
    int StartSegmentIndex,
    int EndSegmentIndex,
    int ConsumedEndSegmentIndex);

/// <summary>
/// Mutable segment/grapheme cursor used by the internal line walker.
/// The public API surfaces the immutable <see cref="LayoutCursor"/> instead.
/// </summary>
internal struct LineBreakCursor
{
    internal int SegmentIndex;
    internal int GraphemeIndex;

    internal LineBreakCursor(int segmentIndex, int graphemeIndex)
    {
        SegmentIndex = segmentIndex;
        GraphemeIndex = graphemeIndex;
    }
}

/// <summary>
/// Width-independent handle produced by <c>TextLayoutEngine.Prepare</c>.
/// Opaque on purpose: layout walks the cached measurements with pure
/// arithmetic, so the internal representation must stay free to change.
/// </summary>
public class PreparedText
{
    internal PreparedText(
        double[] widths,
        double[] lineEndFitAdvances,
        double[] lineEndPaintAdvances,
        SegmentBreakKind[] kinds,
        bool simpleLineWalkFastPath,
        double[]?[] breakableFitAdvances,
        int[]?[] breakablePreferredBreaks,
        double letterSpacing,
        int[] spacingGraphemeCounts,
        double discretionaryHyphenWidth,
        double tabStopAdvance,
        PreparedLineChunk[] chunks)
    {
        Widths = widths;
        LineEndFitAdvances = lineEndFitAdvances;
        LineEndPaintAdvances = lineEndPaintAdvances;
        Kinds = kinds;
        SimpleLineWalkFastPath = simpleLineWalkFastPath;
        BreakableFitAdvances = breakableFitAdvances;
        BreakablePreferredBreaks = breakablePreferredBreaks;
        LetterSpacing = letterSpacing;
        SpacingGraphemeCounts = spacingGraphemeCounts;
        DiscretionaryHyphenWidth = discretionaryHyphenWidth;
        TabStopAdvance = tabStopAdvance;
        Chunks = chunks;
    }

    /// <summary>Measured advance per segment, including internal letter-spacing.</summary>
    internal double[] Widths { get; }

    /// <summary>Width contribution when a line ends after this segment.</summary>
    internal double[] LineEndFitAdvances { get; }

    /// <summary>Painted contribution before terminal line-end letter-spacing.</summary>
    internal double[] LineEndPaintAdvances { get; }

    /// <summary>Break behavior per segment.</summary>
    internal SegmentBreakKind[] Kinds { get; }

    /// <summary>Normal text can use the simpler line walker across all layout APIs.</summary>
    internal bool SimpleLineWalkFastPath { get; }

    /// <summary>Per-grapheme fit advances for breakable segments, else null.</summary>
    internal double[]?[] BreakableFitAdvances { get; }

    /// <summary>Preferred grapheme break ends inside breakable segments, else null.</summary>
    internal int[]?[] BreakablePreferredBreaks { get; }

    /// <summary>Extra advance between rendered graphemes on the same line.</summary>
    internal double LetterSpacing { get; }

    /// <summary>Rendered grapheme counts for letter-spacing gaps; empty when LetterSpacing is 0.</summary>
    internal int[] SpacingGraphemeCounts { get; }

    /// <summary>Visible width added when a soft hyphen is chosen as the break.</summary>
    internal double DiscretionaryHyphenWidth { get; }

    /// <summary>Absolute advance between tab stops for pre-wrap tab segments.</summary>
    internal double TabStopAdvance { get; }

    /// <summary>Precompiled hard-break chunks for line walking.</summary>
    internal PreparedLineChunk[] Chunks { get; }

    internal int SegmentCount => Widths.Length;
}

/// <summary>
/// Manual-layout handle that additionally exposes the structural segment data
/// used by range/cursor APIs and custom rendering.
/// </summary>
public sealed class PreparedTextWithSegments : PreparedText
{
    private string[]?[]? segmentGraphemes;

    internal PreparedTextWithSegments(
        double[] widths,
        double[] lineEndFitAdvances,
        double[] lineEndPaintAdvances,
        SegmentBreakKind[] kinds,
        bool simpleLineWalkFastPath,
        double[]?[] breakableFitAdvances,
        int[]?[] breakablePreferredBreaks,
        double letterSpacing,
        int[] spacingGraphemeCounts,
        double discretionaryHyphenWidth,
        double tabStopAdvance,
        PreparedLineChunk[] chunks,
        string[] segments,
        sbyte[]? segmentLevels)
        : base(
            widths,
            lineEndFitAdvances,
            lineEndPaintAdvances,
            kinds,
            simpleLineWalkFastPath,
            breakableFitAdvances,
            breakablePreferredBreaks,
            letterSpacing,
            spacingGraphemeCounts,
            discretionaryHyphenWidth,
            tabStopAdvance,
            chunks)
    {
        SegmentArray = segments;
        SegmentLevelArray = segmentLevels;
    }

    internal string[] SegmentArray { get; }

    /// <summary>Bidi embedding level per segment; null for pure-LTR text.</summary>
    internal sbyte[]? SegmentLevelArray { get; }

    /// <summary>Segment text aligned with the prepared measurements.</summary>
    public ReadOnlySpan<string> Segments => SegmentArray;

    /// <summary>
    /// Bidi embedding level per segment for custom rendering.
    /// Empty for pure-LTR text, where visual order equals logical order.
    /// </summary>
    public ReadOnlySpan<sbyte> SegmentLevels => SegmentLevelArray;

    /// <summary>Lazily cached grapheme split per segment for line-text materialization.</summary>
    internal string[]?[] SegmentGraphemeCache =>
        segmentGraphemes ??= new string[]?[SegmentArray.Length];
}
