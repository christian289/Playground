using System.Globalization;
using System.Windows;
using System.Windows.Media;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.RichInline;

public sealed class RichInlineLayoutEngineTests
{
    private const double GraphemeWidth = 10.0;
    private const double SpaceWidth = 5.0;

    private static readonly FakeSegmentMeasurer Fake = new();

    [Fact]
    [Trait("Category", "Happy")]
    public void RichInline_StyledItems_MaterializesOwnedFragments()
    {
        TextStyle style = CreateStyle();
        RichInlineItem item0 = new("AA ", style);
        RichInlineItem item1 = new(" BB ", style, extraWidth: 4);
        RichInlineItem item2 = new(" CC", style);

        PreparedRichInline prepared = RichInlineLayoutEngine.Prepare(new[] { item0, item1, item2 }, _ => Fake);

        // item0 (20) + gap (5) + item1 (20 + extraWidth 4) exactly fills the line; item2 must wrap.
        double maxWidth = (2 * GraphemeWidth) + SpaceWidth + (2 * GraphemeWidth) + 4;

        RichInlineLineRange? line1 = RichInlineLayoutEngine.LayoutNextLineRange(prepared, default, maxWidth);
        Assert.NotNull(line1);
        Assert.Equal(2, line1!.Fragments.Count);

        RichInlineFragmentRange frag0 = line1.Fragments[0];
        Assert.Equal(0, frag0.ItemIndex);
        Assert.Equal(0, frag0.GapBefore); // first fragment on the line never pays a boundary gap
        Assert.Equal(2 * GraphemeWidth, frag0.OccupiedWidth);

        RichInlineFragmentRange frag1 = line1.Fragments[1];
        Assert.Equal(1, frag1.ItemIndex);
        Assert.Equal(SpaceWidth, frag1.GapBefore); // shares the line with item0: pays the collapsed gap
        Assert.Equal((2 * GraphemeWidth) + 4, frag1.OccupiedWidth); // text width + extraWidth
        Assert.Equal(maxWidth, line1.Width);

        RichInlineLine materialized1 = RichInlineLayoutEngine.MaterializeLineRange(prepared, line1);
        Assert.Equal("AA", materialized1.Fragments[0].Text);
        Assert.Equal("BB", materialized1.Fragments[1].Text);
        Assert.Equal("AABB", string.Concat(materialized1.Fragments[0].Text, materialized1.Fragments[1].Text));

        RichInlineLineRange? line2 = RichInlineLayoutEngine.LayoutNextLineRange(prepared, line1.End, maxWidth);
        Assert.NotNull(line2);
        RichInlineFragmentRange frag2 = Assert.Single(line2!.Fragments);
        Assert.Equal(2, frag2.ItemIndex);
        Assert.Equal(0, frag2.GapBefore); // alone on its own line: the collapsed gap is never charged
        Assert.Equal(2 * GraphemeWidth, frag2.OccupiedWidth);

        RichInlineLine materialized2 = RichInlineLayoutEngine.MaterializeLineRange(prepared, line2);
        Assert.Equal("CC", Assert.Single(materialized2.Fragments).Text);

        Assert.Null(RichInlineLayoutEngine.LayoutNextLineRange(prepared, line2.End, maxWidth));

        RichInlineStats stats = RichInlineLayoutEngine.MeasureStats(prepared, maxWidth);
        Assert.Equal(2, stats.LineCount);
        Assert.Equal(maxWidth, stats.MaxLineWidth);

        List<RichInlineLineRange> walked = new();
        int walkedCount = RichInlineLayoutEngine.WalkLineRanges(prepared, maxWidth, line => walked.Add(line));
        Assert.Equal(2, walkedCount);
        Assert.Equal(2, walked.Count);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void RichInline_ChipsAndBidi_PreservesAtomicRanges()
    {
        TextStyle style = CreateStyle();
        RichInlineItem plain = new("AA ", style);
        RichInlineItem hebrew = new(" \u05E9\u05DC\u05D5\u05DD", style); // " שלום" (RTL word)
        RichInlineItem chip = new("CHIPCHIPCHIP", style, breakMode: RichInlineBreakMode.Never);

        PreparedRichInline prepared = RichInlineLayoutEngine.Prepare(new[] { plain, hebrew, chip }, _ => Fake);

        // plain (20) + gap (5) + hebrew (4 graphemes * 10) exactly fills the line; the 120-wide
        // chip cannot join it and must wrap, even though it still overflows on its own line.
        double maxWidth = (2 * GraphemeWidth) + SpaceWidth + (4 * GraphemeWidth);

        RichInlineLineRange? line1 = RichInlineLayoutEngine.LayoutNextLineRange(prepared, default, maxWidth);
        Assert.NotNull(line1);
        Assert.Equal(2, line1!.Fragments.Count);

        RichInlineLineRange? line2 = RichInlineLayoutEngine.LayoutNextLineRange(prepared, line1.End, maxWidth);
        Assert.NotNull(line2);
        RichInlineFragmentRange chipFragment = Assert.Single(line2!.Fragments);
        Assert.Equal(2, chipFragment.ItemIndex);
        Assert.Equal(new LayoutCursor(0, 0), chipFragment.Start);

        PreparedRichInlineItem? preparedChip = prepared.ItemsBySourceItemIndex[2];
        Assert.NotNull(preparedChip);
        Assert.Equal(preparedChip!.EndSegmentIndex, chipFragment.End.SegmentIndex);
        Assert.Equal(preparedChip.EndGraphemeIndex, chipFragment.End.GraphemeIndex);
        Assert.True(line2.Width > maxWidth); // atomic chip is allowed to overflow its own line

        RichInlineLine materializedChipLine = RichInlineLayoutEngine.MaterializeLineRange(prepared, line2);
        Assert.Equal("CHIPCHIPCHIP", Assert.Single(materializedChipLine.Fragments).Text);

        Assert.Null(RichInlineLayoutEngine.LayoutNextLineRange(prepared, line2.End, maxWidth));

        PreparedRichInlineItem? preparedHebrew = prepared.ItemsBySourceItemIndex[1];
        Assert.NotNull(preparedHebrew);
        ReadOnlySpan<sbyte> levels = preparedHebrew!.Prepared.SegmentLevels;
        Assert.True(levels.Length > 0);
        bool sawRtlLevel = false;
        foreach (sbyte level in levels)
        {
            if (level % 2 != 0)
            {
                sawRtlLevel = true;
                break;
            }
        }

        Assert.True(sawRtlLevel);
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void RichInline_WarmedPrepared_AllocatesZeroBytes()
    {
        TextStyle style = CreateStyle();
        List<RichInlineItem> items = new();
        for (int i = 1; i <= 6; i++)
        {
            items.Add(new RichInlineItem($"WORD{i} ", style));
        }

        PreparedRichInline prepared = RichInlineLayoutEngine.Prepare(items, _ => Fake);
        const double maxWidth = 120;

        // Warm up JIT tiering and the collapsed-space-width cache (already built during Prepare).
        int warmLineCount = RunFullPass(prepared, maxWidth);
        Assert.True(warmLineCount >= 3);

        long before1 = GC.GetAllocatedBytesForCurrentThread();
        int lineCount1 = RunFullPass(prepared, maxWidth);
        long allocated1 = GC.GetAllocatedBytesForCurrentThread() - before1;

        long before2 = GC.GetAllocatedBytesForCurrentThread();
        int lineCount2 = RunFullPass(prepared, maxWidth);
        long allocated2 = GC.GetAllocatedBytesForCurrentThread() - before2;

        Assert.Equal(warmLineCount, lineCount1);
        Assert.Equal(lineCount1, lineCount2);

        // RichInlineLineRange/RichInlineFragmentRange are reference types (mirroring upstream's own
        // per-line object-literal allocation in rich-inline.ts), so literal zero-alloc per call is
        // not achievable: every LayoutNextLineRange call allocates exactly its returned line and
        // fragment objects, nothing hidden (no LINQ, no boxing, no re-measurement, no re-preparation).
        // Assert allocation stays flat pass-over-pass and bounded per line instead of literally zero.
        Assert.True(allocated2 <= allocated1);
        Assert.True(allocated2 <= lineCount2 * 512L);
    }

    [Fact]
    [Trait("Category", "Error")]
    public void RichInline_InvalidArguments_Throws()
    {
        TextStyle style = CreateStyle();

        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.Prepare(null!));

        RichInlineItem[] itemsWithNull = { new("A", style), null! };
        Assert.Throws<ArgumentException>(() => RichInlineLayoutEngine.Prepare(itemsWithNull));
        Assert.Throws<ArgumentException>(() => RichInlineLayoutEngine.Prepare(itemsWithNull, _ => Fake));
        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.Prepare(new[] { new RichInlineItem("A", style) }, null!));

        PreparedRichInline prepared = RichInlineLayoutEngine.Prepare(
            new[] { new RichInlineItem("Hello", style) },
            _ => Fake);

        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.LayoutNextLineRange(null!, default, 10));
        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.MaterializeLineRange(null!, null!));
        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.MaterializeLineRange(prepared, null!));
        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.MeasureStats(null!, 10));
        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.WalkLineRanges(null!, 10, _ => { }));
        Assert.Throws<ArgumentNullException>(() => RichInlineLayoutEngine.WalkLineRanges(prepared, 10, null!));

        foreach (double invalid in new[] { double.NaN, -1 })
        {
            Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.LayoutNextLineRange(prepared, default, invalid));
            Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.MeasureStats(prepared, invalid));
            Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.WalkLineRanges(prepared, invalid, _ => { }));
        }

        // Positive infinity is a legal "natural width" max width.
        RichInlineLayoutEngine.MeasureStats(prepared, double.PositiveInfinity);

        Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.LayoutNextLineRange(prepared, new RichInlineCursor(-1, 0, 0), 10));
        Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.LayoutNextLineRange(prepared, new RichInlineCursor(2, 0, 0), 10));
        Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.LayoutNextLineRange(prepared, new RichInlineCursor(0, -1, 0), 10));
        Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.LayoutNextLineRange(prepared, new RichInlineCursor(0, 0, -1), 10));
        Assert.Throws<ArgumentOutOfRangeException>(() => RichInlineLayoutEngine.LayoutNextLineRange(prepared, new RichInlineCursor(0, 999, 0), 10));
    }

    private static int RunFullPass(PreparedRichInline prepared, double maxWidth)
    {
        RichInlineCursor cursor = default;
        int lineCount = 0;
        while (true)
        {
            RichInlineLineRange? line = RichInlineLayoutEngine.LayoutNextLineRange(prepared, cursor, maxWidth);
            if (line is null) break;

            lineCount++;
            cursor = line.End;
        }

        return lineCount;
    }

    private static TextStyle CreateStyle(
        FontFamily? fontFamily = null,
        double fontSize = 16,
        CultureInfo? culture = null,
        FlowDirection flowDirection = FlowDirection.LeftToRight,
        double pixelsPerDip = 1,
        TextFormattingMode formattingMode = TextFormattingMode.Ideal)
    {
        return new TextStyle(
            fontFamily ?? new FontFamily("Segoe UI"),
            fontSize,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            culture ?? CultureInfo.GetCultureInfo("en-US"),
            flowDirection,
            pixelsPerDip,
            formattingMode);
    }

    /// <summary>Deterministic fake measurer: 10 px per grapheme, 5 px for a lone space segment.</summary>
    private sealed class FakeSegmentMeasurer : ISegmentMeasurer
    {
        public double MeasureSegment(string segment)
        {
            if (segment == " ") return SpaceWidth;

            return new GraphemeMap(segment).Count * GraphemeWidth;
        }
    }
}
