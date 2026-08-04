using System.Globalization;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Layout;

/// <summary>
/// Deterministic layout tests driven through the internal
/// <c>TextLayoutEngine.Prepare(string, ISegmentMeasurer, CultureInfo, PrepareOptions)</c>
/// seam, so no WPF objects (<see cref="System.Windows.Media.FontFamily"/>, <c>TextStyle</c>)
/// are constructed anywhere in this file.
/// </summary>
public sealed class TextLayoutEngineTests
{
    private static readonly CultureInfo Culture = CultureInfo.InvariantCulture;

    /// <summary>
    /// Deterministic stand-in for <see cref="WpfTextMeasurer"/>, mirroring upstream
    /// pretext's fake canvas in <c>layout.test.ts</c>: a fixed width per grapheme
    /// (10.0), a lighter width for a plain space (5.0), and zero width for the
    /// zero-width space (U+200B) so break-opportunity segments genuinely
    /// contribute zero width, the way a real font renders them.
    /// </summary>
    internal sealed class FakeMeasurer : ISegmentMeasurer
    {
        internal static readonly FakeMeasurer Instance = new();

        public double MeasureSegment(string segment)
        {
            ArgumentNullException.ThrowIfNull(segment);

            GraphemeMap graphemes = new(segment);
            double width = 0;
            for (int i = 0; i < graphemes.Count; i++)
            {
                width += GraphemeWidth(graphemes.GetTextElement(i));
            }

            return width;
        }

        internal static double GraphemeWidth(string grapheme) => grapheme switch
        {
            " " => 5.0,
            "\u200B" => 0.0,
            _ => 10.0,
        };
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void Prepare_Text_CompilesImmutableSegments()
    {
        const string text = "  Hello\u00A0World  \u4e16\u754c  ";
        TextAnalysis analysis = TextAnalyzer.Analyze(text, Culture, WhiteSpaceMode.Normal, WordBreakMode.Normal);

        PreparedTextWithSegments first = TextLayoutEngine.PrepareWithSegments(text, FakeMeasurer.Instance, Culture, default);
        Assert.Equal(analysis.Normalized, string.Concat(first.Segments.ToArray()));

        // Public surface exposes no mutation: Segments/SegmentLevels are ReadOnlySpan.
        Assert.Equal(typeof(ReadOnlySpan<string>), typeof(PreparedTextWithSegments).GetProperty(nameof(PreparedTextWithSegments.Segments))!.PropertyType);
        Assert.Equal(typeof(ReadOnlySpan<sbyte>), typeof(PreparedTextWithSegments).GetProperty(nameof(PreparedTextWithSegments.SegmentLevels))!.PropertyType);

        // Repeated Prepare of the same input yields equal (independently built) segment arrays.
        PreparedTextWithSegments second = TextLayoutEngine.PrepareWithSegments(text, FakeMeasurer.Instance, Culture, default);
        Assert.NotSame(first, second);
        Assert.Equal(first.Segments.ToArray(), second.Segments.ToArray());

        // The prepared handle is reusable across multiple Layout calls with different
        // widths: no state bleeds between calls (same result for the same width
        // regardless of what other widths were laid out in between).
        LayoutResult atNarrowWidthBefore = TextLayoutEngine.Layout(first, 20, 10);
        LayoutResult atWideWidth = TextLayoutEngine.Layout(first, 500, 10);
        LayoutResult atNarrowWidthAfter = TextLayoutEngine.Layout(first, 20, 10);
        Assert.Equal(atNarrowWidthBefore, atNarrowWidthAfter);
        Assert.NotEqual(atNarrowWidthBefore.LineCount, atWideWidth.LineCount);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Layout_WrapCases_MatchesExpectedRanges()
    {
        const double lineHeight = 10;

        // (a) simple two-word wrap: "foo"=30, " "=5 (hangs), "bar"=30. A maxWidth
        // that exactly fits "foo" forces "bar" onto its own line; the hanging
        // space is consumed into line 1's cursor range but not its width.
        {
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("foo bar", FakeMeasurer.Instance, Culture, default);
            LayoutLinesResult result = TextLayoutEngine.LayoutWithLines(prepared, 30, lineHeight);

            Assert.Equal(2, result.LineCount);
            Assert.Equal(["foo ", "bar"], result.Lines.Select(line => line.Text));
            Assert.Equal([30.0, 30.0], result.Lines.Select(line => line.Width));
            Assert.Equal(result.LineCount, TextLayoutEngine.Layout(prepared, 30, lineHeight).LineCount);
        }

        // (b) trailing spaces hang: "foo"'s word (30) fits under maxWidth=32, but
        // adding the space (35) would not; the line still counts as 1 (the space
        // does not force an extra line) and its reported width excludes the space.
        // Unlike (a) — where the wrap happens AT the space, so the space is consumed
        // into line 1's range — a trailing space at end of text stays outside the
        // range, so the materialized text carries no trailing space.
        {
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("foo ", FakeMeasurer.Instance, Culture, default);
            LayoutLinesResult result = TextLayoutEngine.LayoutWithLines(prepared, 32, lineHeight);

            Assert.Equal(1, result.LineCount);
            Assert.Equal("foo", result.Lines[0].Text);
            Assert.Equal(30.0, result.Lines[0].Width);
        }

        // (c) an overlong single word (10 graphemes x 10.0 = 100) breaks at
        // grapheme boundaries when maxWidth only fits 2 graphemes at a time.
        {
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("abcdefghij", FakeMeasurer.Instance, Culture, default);
            LayoutLinesResult result = TextLayoutEngine.LayoutWithLines(prepared, 25, lineHeight);

            Assert.Equal(5, result.LineCount);
            Assert.Equal(["ab", "cd", "ef", "gh", "ij"], result.Lines.Select(line => line.Text));
            Assert.All(result.Lines, line => Assert.Equal(20.0, line.Width));
            Assert.Equal(result.LineCount, TextLayoutEngine.Layout(prepared, 25, lineHeight).LineCount);
        }

        // (d) a hard break under PreWrap forces a new line regardless of how much
        // room is left on the current line.
        {
            PrepareOptions options = new(whiteSpace: WhiteSpaceMode.PreWrap);
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("ab\ncd", FakeMeasurer.Instance, Culture, options);
            LayoutLinesResult result = TextLayoutEngine.LayoutWithLines(prepared, 200, lineHeight);

            Assert.Equal(2, result.LineCount);
            Assert.Equal(["ab", "cd"], result.Lines.Select(line => line.Text));
            Assert.Equal([20.0, 20.0], result.Lines.Select(line => line.Width));
        }

        // (e) a soft hyphen is chosen as the break: "ab"=20, discretionary hyphen
        // width=10 ("-" is one grapheme), "cd"=20. maxWidth=30 fits "ab" plus the
        // hyphen but not "cd", so the materialized first line ends with '-'.
        {
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("ab\u00ADcd", FakeMeasurer.Instance, Culture, default);
            LayoutLinesResult result = TextLayoutEngine.LayoutWithLines(prepared, 30, lineHeight);

            Assert.Equal(2, result.LineCount);
            Assert.Equal("ab-", result.Lines[0].Text);
            Assert.EndsWith("-", result.Lines[0].Text, StringComparison.Ordinal);
            Assert.Equal(30.0, result.Lines[0].Width);
            Assert.Equal("cd", result.Lines[1].Text);
            Assert.Equal(20.0, result.Lines[1].Width);
        }

        // (f) a zero-width break creates an opportunity without contributing any
        // width: maxWidth=20 fits "ab" exactly but not "ab"+"cd", so the break is
        // taken at the ZWSP, and line 1's width stays 20 (not 20 + something).
        {
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("ab\u200Bcd", FakeMeasurer.Instance, Culture, default);
            LayoutLinesResult result = TextLayoutEngine.LayoutWithLines(prepared, 20, lineHeight);

            Assert.Equal(2, result.LineCount);
            Assert.Equal("ab\u200B", result.Lines[0].Text);
            Assert.Equal(20.0, result.Lines[0].Width);
            Assert.Equal("cd", result.Lines[1].Text);
            Assert.Equal(20.0, result.Lines[1].Width);
        }
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void LayoutNextLineRange_Cursor_ContinuesStreaming()
    {
        LayoutCorpus corpus = LayoutCorpusLoader.Load();
        double[] widths = [corpus.Widths[0], corpus.Widths[3], corpus.Widths[6]];

        foreach (LayoutCorpusText entry in corpus.Texts)
        {
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments(entry.Text, FakeMeasurer.Instance, Culture, default);

            foreach (double width in widths)
            {
                List<LayoutLineRange> walked = [];
                TextLayoutEngine.WalkLineRanges(prepared, width, (in LayoutLineRange line) => walked.Add(line));

                List<LayoutLineRange> streamed = [];
                LayoutCursor cursor = new(0, 0);
                while (true)
                {
                    LayoutLineRange? next = TextLayoutEngine.LayoutNextLineRange(prepared, cursor, width);
                    if (next is null)
                    {
                        break;
                    }

                    streamed.Add(next.Value);
                    cursor = next.Value.End;
                }

                Assert.Equal(walked, streamed);
                Assert.Null(TextLayoutEngine.LayoutNextLineRange(prepared, cursor, width));
            }
        }
    }

    [Fact]
    [Trait("Category", "Error")]
    public void Layout_InvalidArguments_Throws()
    {
        PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments("ab cd", FakeMeasurer.Instance, Culture, default);

        // null prepared/text/style/onLine.
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.Prepare(null!, null!));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.Prepare("abc", null!));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.PrepareWithSegments(null!, null!));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.PrepareWithSegments("abc", null!));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.Layout(null!, 100, 10));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.LayoutWithLines(null!, 100, 10));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.WalkLineRanges(null!, 100, static (in LayoutLineRange _) => { }));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.WalkLineRanges(prepared, 100, null!));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.MeasureLineStats(null!, 100));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.MeasureNaturalWidth(null!));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.LayoutNextLine(null!, default, 100));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.LayoutNextLineRange(null!, default, 100));
        Assert.Throws<ArgumentNullException>(() => TextLayoutEngine.MaterializeLineRange(null!, default));

        // NaN/negative maxWidth throws; PositiveInfinity is explicitly legal.
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.Layout(prepared, double.NaN, 10));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.Layout(prepared, -1, 10));
        LayoutResult infiniteWidthResult = TextLayoutEngine.Layout(prepared, double.PositiveInfinity, 10);
        Assert.True(infiniteWidthResult.LineCount >= 1);

        // NaN/negative/infinite lineHeight all throw (unlike maxWidth, +Infinity is not legal here).
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.Layout(prepared, 100, double.NaN));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.Layout(prepared, 100, -1));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.Layout(prepared, 100, double.PositiveInfinity));

        // Out-of-range cursors for LayoutNextLine/LayoutNextLineRange/MaterializeLineRange.
        LayoutCursor negativeSegment = new(-1, 0);
        LayoutCursor beyondSegmentCount = new(prepared.SegmentCount + 1, 0);
        LayoutCursor negativeGrapheme = new(0, -1);

        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.LayoutNextLine(prepared, negativeSegment, 100));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.LayoutNextLine(prepared, beyondSegmentCount, 100));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.LayoutNextLine(prepared, negativeGrapheme, 100));

        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.LayoutNextLineRange(prepared, negativeSegment, 100));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.LayoutNextLineRange(prepared, beyondSegmentCount, 100));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.LayoutNextLineRange(prepared, negativeGrapheme, 100));

        LayoutLineRange rangeWithBadStart = new(0, negativeSegment, new LayoutCursor(0, 0));
        LayoutLineRange rangeWithBadEnd = new(0, new LayoutCursor(0, 0), beyondSegmentCount);
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.MaterializeLineRange(prepared, rangeWithBadStart));
        Assert.Throws<ArgumentOutOfRangeException>(() => TextLayoutEngine.MaterializeLineRange(prepared, rangeWithBadEnd));
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void Layout_WarmedPreparedText_AllocatesZeroBytes()
    {
        PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments(
            "The quick brown fox jumps over the lazy dog trans\u00ADatlantic ab\u200Bcd",
            FakeMeasurer.Instance,
            Culture,
            default);
        double[] widths = [20, 40, 80, 160, 320, double.PositiveInfinity];

        // Warm up: JIT, any lazy caches on the prepared handle, and GC bookkeeping.
        foreach (double warmWidth in widths)
        {
            TextLayoutEngine.Layout(prepared, warmWidth, 19);
            TextLayoutEngine.Layout(prepared, warmWidth, 19);
        }

        long before = GC.GetAllocatedBytesForCurrentThread();
        for (int i = 0; i < 1000; i++)
        {
            TextLayoutEngine.Layout(prepared, widths[i % widths.Length], 19);
        }

        long after = GC.GetAllocatedBytesForCurrentThread();
        Assert.Equal(0, after - before);

        // LayoutNextLineRange streaming is allocation-free after warmup too:
        // LayoutLineRange/LayoutCursor are structs, so no boxing occurs.
        LayoutCursor cursor = default;
        TextLayoutEngine.LayoutNextLineRange(prepared, cursor, 40);
        TextLayoutEngine.LayoutNextLineRange(prepared, cursor, 40);

        long beforeStreaming = GC.GetAllocatedBytesForCurrentThread();
        for (int i = 0; i < 1000; i++)
        {
            TextLayoutEngine.LayoutNextLineRange(prepared, cursor, 40);
        }

        long afterStreaming = GC.GetAllocatedBytesForCurrentThread();
        Assert.Equal(0, afterStreaming - beforeStreaming);
    }
}
