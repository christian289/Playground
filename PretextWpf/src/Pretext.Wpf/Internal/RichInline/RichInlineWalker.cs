namespace Pretext.Wpf;

/// <summary>
/// Rich-text inline flow walking/preparation core, ported from upstream pretext's
/// <c>rich-inline.ts</c>. Collapses boundary whitespace across item boundaries, keeps
/// <c>break: never</c> items atomic, and folds per-item horizontal chrome
/// (<c>extraWidth</c>) into the greedy line-fitting walk. <see cref="RichInlineLayoutEngine"/>
/// is the thin, argument-validating public wrapper around this class.
/// </summary>
internal static class RichInlineWalker
{
    internal delegate void FragmentCollector(
        PreparedRichInlineItem item,
        double gapBefore,
        double occupiedWidth,
        LayoutCursor start,
        LayoutCursor end);

    // ---- Boundary-whitespace helpers (upstream COLLAPSIBLE_BOUNDARY_RE family) ----
    // [ \t\n\f\r]+ ported as plain char scans instead of Regex, per port contract.

    private static bool IsCollapsibleBoundaryChar(char value)
        => value is ' ' or '\t' or '\n' or '\f' or '\r';

    private static bool ContainsCollapsibleBoundary(string text)
    {
        foreach (char c in text)
        {
            if (IsCollapsibleBoundaryChar(c)) return true;
        }

        return false;
    }

    private static string TrimCollapsibleBoundary(string text)
    {
        int start = 0;
        while (start < text.Length && IsCollapsibleBoundaryChar(text[start])) start++;

        int end = text.Length;
        while (end > start && IsCollapsibleBoundaryChar(text[end - 1])) end--;

        return start == 0 && end == text.Length ? text : text[start..end];
    }

    private static bool IsLineStartCursor(int segmentIndex, int graphemeIndex)
        => segmentIndex == 0 && graphemeIndex == 0;

    private static bool EndsInsideFirstSegment(int segmentIndex, int graphemeIndex)
        => segmentIndex == 0 && graphemeIndex > 0;

    private static double GetCollapsedSpaceWidth(
        TextStyle style,
        double letterSpacing,
        Func<TextStyle, ISegmentMeasurer> measurerFactory,
        Dictionary<(TextStyle Style, double LetterSpacing), double> cache)
    {
        (TextStyle Style, double LetterSpacing) key = (style, letterSpacing);
        if (cache.TryGetValue(key, out double cached)) return cached;

        ISegmentMeasurer measurer = measurerFactory(style);
        PrepareOptions options = new(letterSpacing: letterSpacing);
        PreparedTextWithSegments joined = TextLayoutEngine.PrepareWithSegments(
            "A A", measurer, style.Culture, style.FlowDirection, options);
        PreparedTextWithSegments compact = TextLayoutEngine.PrepareWithSegments(
            "AA", measurer, style.Culture, style.FlowDirection, options);
        double joinedWidth = TextLayoutEngine.MeasureNaturalWidth(joined);
        double compactWidth = TextLayoutEngine.MeasureNaturalWidth(compact);
        double collapsedWidth = Math.Max(0, joinedWidth - compactWidth);
        cache[key] = collapsedWidth;
        return collapsedWidth;
    }

    private static (int EndSegmentIndex, int EndGraphemeIndex, double Width)? PrepareWholeItemLine(
        PreparedTextWithSegments prepared)
    {
        LineBreakCursor end = default;
        double? width = LineWalker.StepLineGeometry(prepared, ref end, double.PositiveInfinity);
        return width is null ? null : (end.SegmentIndex, end.GraphemeIndex, width.Value);
    }

    // ---- Preparation (upstream prepareRichInline) ----

    internal static PreparedRichInline Prepare(
        IReadOnlyList<RichInlineItem> items,
        Func<TextStyle, ISegmentMeasurer> measurerFactory)
    {
        List<PreparedRichInlineItem> preparedItems = new(items.Count);
        PreparedRichInlineItem?[] itemsBySourceItemIndex = new PreparedRichInlineItem?[items.Count];
        Dictionary<(TextStyle Style, double LetterSpacing), double> collapsedSpaceWidthCache = new();
        double pendingGapWidth = 0;

        for (int index = 0; index < items.Count; index++)
        {
            RichInlineItem item = items[index];
            double letterSpacing = item.LetterSpacing;
            string text = item.Text;

            bool hasLeadingWhitespace = text.Length > 0 && IsCollapsibleBoundaryChar(text[0]);
            bool hasTrailingWhitespace = text.Length > 0 && IsCollapsibleBoundaryChar(text[^1]);
            string trimmedText = TrimCollapsibleBoundary(text);

            if (trimmedText.Length == 0)
            {
                if (pendingGapWidth == 0 && ContainsCollapsibleBoundary(text))
                {
                    pendingGapWidth = GetCollapsedSpaceWidth(item.Style, letterSpacing, measurerFactory, collapsedSpaceWidthCache);
                }

                continue;
            }

            double gapBefore = pendingGapWidth > 0
                ? pendingGapWidth
                : hasLeadingWhitespace
                    ? GetCollapsedSpaceWidth(item.Style, letterSpacing, measurerFactory, collapsedSpaceWidthCache)
                    : 0;

            ISegmentMeasurer measurer = measurerFactory(item.Style);
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments(
                trimmedText,
                measurer,
                item.Style.Culture,
                item.Style.FlowDirection,
                new PrepareOptions(letterSpacing: letterSpacing));

            (int EndSegmentIndex, int EndGraphemeIndex, double Width)? wholeLine = PrepareWholeItemLine(prepared);
            if (wholeLine is null)
            {
                pendingGapWidth = hasTrailingWhitespace
                    ? GetCollapsedSpaceWidth(item.Style, letterSpacing, measurerFactory, collapsedSpaceWidthCache)
                    : 0;
                continue;
            }

            PreparedRichInlineItem preparedItem = new(
                item.BreakMode,
                wholeLine.Value.EndGraphemeIndex,
                wholeLine.Value.EndSegmentIndex,
                item.ExtraWidth,
                gapBefore,
                wholeLine.Value.Width,
                prepared,
                index);
            preparedItems.Add(preparedItem);
            itemsBySourceItemIndex[index] = preparedItem;

            pendingGapWidth = hasTrailingWhitespace
                ? GetCollapsedSpaceWidth(item.Style, letterSpacing, measurerFactory, collapsedSpaceWidthCache)
                : 0;
        }

        return new PreparedRichInline(preparedItems, itemsBySourceItemIndex);
    }

    // ---- Line-range stepping over items (upstream stepRichInlineLine) ----

    internal static double? StepLine(
        PreparedRichInline flow,
        double maxWidth,
        ref RichInlineWalkCursor cursor,
        FragmentCollector? collectFragment)
    {
        IReadOnlyList<PreparedRichInlineItem> items = flow.Items;
        if (items.Count == 0 || cursor.ItemIndex >= items.Count) return null;

        double safeWidth = Math.Max(1, maxWidth);
        double lineWidth = 0;
        double remainingWidth = safeWidth;
        int itemIndex = cursor.ItemIndex;

        while (itemIndex < items.Count)
        {
            PreparedRichInlineItem item = items[itemIndex];
            bool atItemStart = IsLineStartCursor(cursor.SegmentIndex, cursor.GraphemeIndex);

            if (!atItemStart &&
                cursor.SegmentIndex == item.EndSegmentIndex &&
                cursor.GraphemeIndex == item.EndGraphemeIndex)
            {
                itemIndex++;
                cursor.SegmentIndex = 0;
                cursor.GraphemeIndex = 0;
                continue;
            }

            double gapBefore = lineWidth == 0 ? 0 : item.GapBefore;

            if (item.BreakMode == RichInlineBreakMode.Never)
            {
                if (!atItemStart)
                {
                    itemIndex++;
                    cursor.SegmentIndex = 0;
                    cursor.GraphemeIndex = 0;
                    continue;
                }

                double chipOccupiedWidth = item.NaturalWidth + item.ExtraWidth;
                double chipTotalWidth = gapBefore + chipOccupiedWidth;
                if (lineWidth > 0 && chipTotalWidth > remainingWidth) break;

                collectFragment?.Invoke(
                    item,
                    gapBefore,
                    chipOccupiedWidth,
                    new LayoutCursor(0, 0),
                    new LayoutCursor(item.EndSegmentIndex, item.EndGraphemeIndex));
                lineWidth += chipTotalWidth;
                remainingWidth = Math.Max(0, safeWidth - lineWidth);
                itemIndex++;
                cursor.SegmentIndex = 0;
                cursor.GraphemeIndex = 0;
                continue;
            }

            double reservedWidth = gapBefore + item.ExtraWidth;
            if (lineWidth > 0 && reservedWidth >= remainingWidth) break;

            if (atItemStart)
            {
                double totalWidth = reservedWidth + item.NaturalWidth;
                if (totalWidth <= remainingWidth)
                {
                    collectFragment?.Invoke(
                        item,
                        gapBefore,
                        item.NaturalWidth + item.ExtraWidth,
                        new LayoutCursor(0, 0),
                        new LayoutCursor(item.EndSegmentIndex, item.EndGraphemeIndex));
                    lineWidth += totalWidth;
                    remainingWidth = Math.Max(0, safeWidth - lineWidth);
                    itemIndex++;
                    cursor.SegmentIndex = 0;
                    cursor.GraphemeIndex = 0;
                    continue;
                }
            }

            double availableWidth = Math.Max(1, remainingWidth - reservedWidth);
            LineBreakCursor lineEnd = new(cursor.SegmentIndex, cursor.GraphemeIndex);
            double? lineWidthForItem = LineWalker.StepLineGeometry(item.Prepared, ref lineEnd, availableWidth);
            if (lineWidthForItem is null)
            {
                itemIndex++;
                cursor.SegmentIndex = 0;
                cursor.GraphemeIndex = 0;
                continue;
            }

            if (cursor.SegmentIndex == lineEnd.SegmentIndex && cursor.GraphemeIndex == lineEnd.GraphemeIndex)
            {
                itemIndex++;
                cursor.SegmentIndex = 0;
                cursor.GraphemeIndex = 0;
                continue;
            }

            double itemOccupiedWidth = lineWidthForItem.Value + item.ExtraWidth;
            double lineWidthContribution = gapBefore + itemOccupiedWidth;

            // The lower-level walker may force one unit to make progress. If that unit
            // only fits on a fresh line, wrap before this rich item instead.
            if (lineWidth > 0 && atItemStart && lineWidthContribution > remainingWidth) break;

            // If the only thing we can fit after paying the boundary gap is a partial
            // slice of the item's first segment, prefer wrapping before the item so we
            // keep whole-word-style boundaries when they exist. But once the current
            // line can consume a real breakable unit from the item, stay greedy and
            // keep filling the line.
            if (lineWidth > 0 &&
                atItemStart &&
                gapBefore > 0 &&
                EndsInsideFirstSegment(lineEnd.SegmentIndex, lineEnd.GraphemeIndex))
            {
                LineBreakCursor freshLineEnd = default;
                double? freshLineWidth = LineWalker.StepLineGeometry(
                    item.Prepared,
                    ref freshLineEnd,
                    Math.Max(1, safeWidth - item.ExtraWidth));
                if (freshLineWidth is not null &&
                    (freshLineEnd.SegmentIndex > lineEnd.SegmentIndex ||
                     (freshLineEnd.SegmentIndex == lineEnd.SegmentIndex && freshLineEnd.GraphemeIndex > lineEnd.GraphemeIndex)))
                {
                    break;
                }
            }

            collectFragment?.Invoke(
                item,
                gapBefore,
                itemOccupiedWidth,
                new LayoutCursor(cursor.SegmentIndex, cursor.GraphemeIndex),
                new LayoutCursor(lineEnd.SegmentIndex, lineEnd.GraphemeIndex));
            lineWidth += lineWidthContribution;
            remainingWidth = Math.Max(0, safeWidth - lineWidth);

            if (lineEnd.SegmentIndex == item.EndSegmentIndex && lineEnd.GraphemeIndex == item.EndGraphemeIndex)
            {
                itemIndex++;
                cursor.SegmentIndex = 0;
                cursor.GraphemeIndex = 0;
                continue;
            }

            cursor.SegmentIndex = lineEnd.SegmentIndex;
            cursor.GraphemeIndex = lineEnd.GraphemeIndex;
            break;
        }

        if (lineWidth == 0) return null;

        cursor.ItemIndex = itemIndex;
        return lineWidth;
    }

    // ---- Range walking, materialization, and stats glue ----

    internal static RichInlineLineRange? LayoutNextLineRange(
        PreparedRichInline prepared,
        double maxWidth,
        RichInlineCursor start)
    {
        RichInlineWalkCursor cursor = new(start.ItemIndex, start.SegmentIndex, start.GraphemeIndex);
        List<RichInlineFragmentRange> fragments = new();
        double? width = StepLine(
            prepared,
            maxWidth,
            ref cursor,
            (item, gapBefore, occupiedWidth, fragmentStart, fragmentEnd) =>
                fragments.Add(new RichInlineFragmentRange(item.SourceItemIndex, gapBefore, occupiedWidth, fragmentStart, fragmentEnd)));
        if (width is null) return null;

        RichInlineCursor end = new(cursor.ItemIndex, cursor.SegmentIndex, cursor.GraphemeIndex);
        return new RichInlineLineRange(fragments, width.Value, end);
    }

    private static string MaterializeFragmentText(PreparedRichInlineItem item, RichInlineFragmentRange fragment)
        => LineTextMaterializer.BuildLineText(
            item.Prepared,
            fragment.Start.SegmentIndex,
            fragment.Start.GraphemeIndex,
            fragment.End.SegmentIndex,
            fragment.End.GraphemeIndex);

    // Bridge from cheap range walking to full fragment text. Lets callers do
    // shrinkwrap/virtualization/probing work first, then only pay for text on the
    // lines they actually render.
    internal static RichInlineLine MaterializeLineRange(PreparedRichInline prepared, RichInlineLineRange line)
    {
        List<RichInlineFragment> fragments = new(line.Fragments.Count);
        for (int i = 0; i < line.Fragments.Count; i++)
        {
            RichInlineFragmentRange fragment = line.Fragments[i];
            PreparedRichInlineItem? item = fragment.ItemIndex >= 0 && fragment.ItemIndex < prepared.ItemsBySourceItemIndex.Count
                ? prepared.ItemsBySourceItemIndex[fragment.ItemIndex]
                : null;
            if (item is null)
            {
                throw new InvalidOperationException("Missing rich-text inline item for fragment.");
            }

            fragments.Add(new RichInlineFragment(
                fragment.ItemIndex,
                MaterializeFragmentText(item, fragment),
                fragment.GapBefore,
                fragment.OccupiedWidth,
                fragment.Start,
                fragment.End));
        }

        return new RichInlineLine(fragments, line.Width, line.End);
    }

    internal static int WalkLineRanges(PreparedRichInline prepared, double maxWidth, RichInlineLineRangeVisitor onLine)
    {
        int lineCount = 0;
        RichInlineCursor cursor = default;

        while (true)
        {
            RichInlineLineRange? line = LayoutNextLineRange(prepared, maxWidth, cursor);
            if (line is null) return lineCount;
            onLine(line);
            lineCount++;
            cursor = line.End;
        }
    }

    internal static RichInlineStats MeasureStats(PreparedRichInline prepared, double maxWidth)
    {
        int lineCount = 0;
        double maxLineWidth = 0;
        RichInlineWalkCursor cursor = default;

        while (true)
        {
            double? lineWidth = StepLine(prepared, maxWidth, ref cursor, null);
            if (lineWidth is null) return new RichInlineStats(lineCount, maxLineWidth);
            lineCount++;
            if (lineWidth.Value > maxLineWidth) maxLineWidth = lineWidth.Value;
        }
    }
}

/// <summary>
/// A rich-inline item after boundary-whitespace collapse and whole-item measurement.
/// Mirrors upstream's <c>PreparedRichInlineItem</c> shape from <c>rich-inline.ts</c>.
/// </summary>
internal sealed record PreparedRichInlineItem(
    RichInlineBreakMode BreakMode,
    int EndGraphemeIndex,
    int EndSegmentIndex,
    double ExtraWidth,
    double GapBefore,
    double NaturalWidth,
    PreparedTextWithSegments Prepared,
    int SourceItemIndex);

/// <summary>
/// Mutable per-item flow cursor used while stepping a rich-inline line. The public API
/// surfaces the immutable <see cref="RichInlineCursor"/> instead.
/// </summary>
internal struct RichInlineWalkCursor
{
    internal int ItemIndex;
    internal int SegmentIndex;
    internal int GraphemeIndex;

    internal RichInlineWalkCursor(int itemIndex, int segmentIndex, int graphemeIndex)
    {
        ItemIndex = itemIndex;
        SegmentIndex = segmentIndex;
        GraphemeIndex = graphemeIndex;
    }
}
