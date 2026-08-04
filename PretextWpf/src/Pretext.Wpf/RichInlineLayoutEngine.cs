namespace Pretext.Wpf;

/// <summary>
/// Helper for rich-text inline flow under CSS-style <c>white-space: normal</c>, ported from
/// upstream pretext <c>rich-inline.ts</c>. Keeps the core layout API (<see cref="TextLayoutEngine"/>)
/// low-level while taking over the boring shared work that rich-inline demos would otherwise
/// reimplement in userland:
/// <list type="bullet">
/// <item>collapsed boundary whitespace across item boundaries</item>
/// <item>atomic inline boxes such as pills/mention chips (<see cref="RichInlineBreakMode.Never"/>)</item>
/// <item>per-item extra horizontal chrome such as padding/borders</item>
/// </list>
/// <see cref="Prepare(IReadOnlyList{RichInlineItem})"/> segments and measures every item once;
/// the remaining methods walk the cached measurements with pure arithmetic per width.
/// </summary>
public static class RichInlineLayoutEngine
{
    public static PreparedRichInline Prepare(IReadOnlyList<RichInlineItem> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        GuardNoNullItems(items);
        return RichInlineWalker.Prepare(items, WpfTextMeasurer.GetOrCreate);
    }

    // Internal test seam: identical pipeline with an injected measurer, so deterministic
    // tests can avoid the STA-only WPF text formatter.
    internal static PreparedRichInline Prepare(IReadOnlyList<RichInlineItem> items, Func<TextStyle, ISegmentMeasurer> measurerFactory)
    {
        ArgumentNullException.ThrowIfNull(items);
        ArgumentNullException.ThrowIfNull(measurerFactory);
        GuardNoNullItems(items);
        return RichInlineWalker.Prepare(items, measurerFactory);
    }

    public static RichInlineLineRange? LayoutNextLineRange(PreparedRichInline prepared, RichInlineCursor start, double maxWidth)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardCursor(prepared, start);
        GuardMaxWidth(maxWidth);

        return RichInlineWalker.LayoutNextLineRange(prepared, maxWidth, start);
    }

    public static RichInlineLine MaterializeLineRange(PreparedRichInline prepared, RichInlineLineRange line)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        ArgumentNullException.ThrowIfNull(line);

        return RichInlineWalker.MaterializeLineRange(prepared, line);
    }

    public static RichInlineStats MeasureStats(PreparedRichInline prepared, double maxWidth)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        GuardMaxWidth(maxWidth);

        return RichInlineWalker.MeasureStats(prepared, maxWidth);
    }

    public static int WalkLineRanges(PreparedRichInline prepared, double maxWidth, RichInlineLineRangeVisitor onLine)
    {
        ArgumentNullException.ThrowIfNull(prepared);
        ArgumentNullException.ThrowIfNull(onLine);
        GuardMaxWidth(maxWidth);

        return RichInlineWalker.WalkLineRanges(prepared, maxWidth, onLine);
    }

    private static void GuardNoNullItems(IReadOnlyList<RichInlineItem> items)
    {
        for (int i = 0; i < items.Count; i++)
        {
            if (items[i] is null)
            {
                throw new ArgumentException("Items must not contain null elements.", nameof(items));
            }
        }
    }

    private static void GuardMaxWidth(double maxWidth)
    {
        if (double.IsNaN(maxWidth) || maxWidth < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxWidth), maxWidth, "Max width must be non-negative (positive infinity is allowed).");
        }
    }

    private static void GuardCursor(PreparedRichInline prepared, RichInlineCursor cursor)
    {
        if (cursor.ItemIndex < 0 || cursor.ItemIndex > prepared.Items.Count)
        {
            throw new ArgumentOutOfRangeException(nameof(cursor), cursor, "Cursor item index is outside the prepared item range.");
        }

        if (cursor.SegmentIndex < 0 || cursor.GraphemeIndex < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(cursor), cursor, "Cursor is outside the prepared segment range.");
        }

        if (cursor.ItemIndex < prepared.Items.Count &&
            cursor.SegmentIndex > prepared.Items[cursor.ItemIndex].Prepared.SegmentCount)
        {
            throw new ArgumentOutOfRangeException(nameof(cursor), cursor, "Cursor is outside the prepared segment range.");
        }
    }
}
