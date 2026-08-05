namespace Pretext.Wpf;

/// <summary>
/// Line-break walking core: chooses wrap points across the width/kind arrays
/// produced by <c>TextLayoutEngine.Prepare</c>. Ported line-for-line from
/// upstream pretext's <c>line-break.ts</c> — the heart of the layout engine.
/// Behavioral parity with upstream is the acceptance criterion; do not
/// "improve" the wrapping algorithm here.
/// </summary>
internal static class LineWalker
{
    internal delegate void LineVisitor(
        double width,
        int startSegmentIndex,
        int startGraphemeIndex,
        int endSegmentIndex,
        int endGraphemeIndex);

    // ---- Pure per-segment helpers (upstream lines 36-216) --------------

    private static bool ConsumesAtLineStart(SegmentBreakKind kind)
        => kind is SegmentBreakKind.Space or SegmentBreakKind.ZeroWidthBreak or SegmentBreakKind.SoftHyphen;

    private static bool BreaksAfter(SegmentBreakKind kind)
        => kind is SegmentBreakKind.Space or SegmentBreakKind.PreservedSpace or SegmentBreakKind.Tab
            or SegmentBreakKind.ZeroWidthBreak or SegmentBreakKind.SoftHyphen;

    private static int NormalizeLineStartSegmentIndex(PreparedText prepared, int segmentIndex)
        => NormalizeLineStartSegmentIndex(prepared, segmentIndex, prepared.Widths.Length);

    private static int NormalizeLineStartSegmentIndex(PreparedText prepared, int segmentIndex, int endSegmentIndex)
    {
        while (segmentIndex < endSegmentIndex)
        {
            if (!ConsumesAtLineStart(prepared.Kinds[segmentIndex])) break;
            segmentIndex++;
        }
        return segmentIndex;
    }

    private static double GetTabAdvance(double lineWidth, double tabStopAdvance)
    {
        if (tabStopAdvance <= 0) return 0;

        double remainder = lineWidth % tabStopAdvance;
        if (Math.Abs(remainder) <= 1e-6) return tabStopAdvance;
        return tabStopAdvance - remainder;
    }

    private static double GetLeadingLetterSpacing(PreparedText prepared, bool hasContent, int segmentIndex)
        => prepared.LetterSpacing != 0 && hasContent && prepared.SpacingGraphemeCounts[segmentIndex] > 0
            ? prepared.LetterSpacing
            : 0;

    private static double GetLineEndContribution(double leadingSpacing, double segmentContribution)
        => segmentContribution == 0 ? 0 : leadingSpacing + segmentContribution;

    private static double GetTabTrailingLetterSpacing(PreparedText prepared, int segmentIndex)
        => prepared.LetterSpacing != 0 && prepared.SpacingGraphemeCounts[segmentIndex] > 0
            ? prepared.LetterSpacing
            : 0;

    private static double GetWholeSegmentFitContribution(
        PreparedText prepared,
        SegmentBreakKind kind,
        int segmentIndex,
        double leadingSpacing,
        double segmentWidth)
    {
        double segmentContribution = kind == SegmentBreakKind.Tab
            ? segmentWidth + GetTabTrailingLetterSpacing(prepared, segmentIndex)
            : prepared.LineEndFitAdvances[segmentIndex];
        return GetLineEndContribution(leadingSpacing, segmentContribution);
    }

    private static double GetBreakOpportunityFitContribution(
        PreparedText prepared,
        SegmentBreakKind kind,
        int segmentIndex,
        double leadingSpacing)
    {
        double segmentContribution = kind == SegmentBreakKind.Tab ? 0 : prepared.LineEndFitAdvances[segmentIndex];
        return GetLineEndContribution(leadingSpacing, segmentContribution);
    }

    private static double GetLineEndPaintContribution(
        PreparedText prepared,
        SegmentBreakKind kind,
        int segmentIndex,
        double leadingSpacing,
        double segmentWidth)
    {
        double segmentContribution = kind == SegmentBreakKind.Tab ? segmentWidth : prepared.LineEndPaintAdvances[segmentIndex];
        return GetLineEndContribution(leadingSpacing, segmentContribution);
    }

    private static double GetBreakableGraphemeAdvance(PreparedText prepared, bool hasContent, double baseAdvance)
        => prepared.LetterSpacing != 0 && hasContent ? baseAdvance + prepared.LetterSpacing : baseAdvance;

    private static double GetBreakableCandidateFitWidth(PreparedText prepared, double candidatePaintWidth)
        => prepared.LetterSpacing == 0 ? candidatePaintWidth : candidatePaintWidth + prepared.LetterSpacing;

    private static int GetNextPreferredBreakIndex(int[] preferredBreaks, int preferredBreakIndex, int graphemeEnd)
    {
        int index = preferredBreakIndex;
        while (index < preferredBreaks.Length && preferredBreaks[index] < graphemeEnd) index++;
        return index;
    }

    private static double GetTerminalLetterSpacing(
        PreparedText prepared,
        int startSegmentIndex,
        int startGraphemeIndex,
        int endSegmentIndex,
        int endGraphemeIndex)
    {
        if (prepared.LetterSpacing == 0) return 0;

        if (endGraphemeIndex > 0)
        {
            return prepared.SpacingGraphemeCounts[endSegmentIndex] > 0 ? prepared.LetterSpacing : 0;
        }

        for (int i = endSegmentIndex - 1; i >= startSegmentIndex; i--)
        {
            SegmentBreakKind kind = prepared.Kinds[i];
            if (kind is SegmentBreakKind.Space or SegmentBreakKind.ZeroWidthBreak or SegmentBreakKind.HardBreak) continue;
            if (kind == SegmentBreakKind.SoftHyphen)
            {
                if (i == endSegmentIndex - 1) return 0;
                continue;
            }

            if (i == startSegmentIndex && startGraphemeIndex > 0)
            {
                return prepared.LetterSpacing;
            }

            return prepared.SpacingGraphemeCounts[i] > 0 ? prepared.LetterSpacing : 0;
        }

        return 0;
    }

    private static double FinalizeLinePaintWidth(
        PreparedText prepared,
        double width,
        int startSegmentIndex,
        int startGraphemeIndex,
        int endSegmentIndex,
        int endGraphemeIndex)
        => width + GetTerminalLetterSpacing(prepared, startSegmentIndex, startGraphemeIndex, endSegmentIndex, endGraphemeIndex);

    private static int FindChunkIndexForStart(PreparedText prepared, int segmentIndex)
    {
        PreparedLineChunk[] chunks = prepared.Chunks;
        int lo = 0;
        int hi = chunks.Length;

        while (lo < hi)
        {
            int mid = (lo + hi) / 2;
            if (segmentIndex < chunks[mid].ConsumedEndSegmentIndex) hi = mid;
            else lo = mid + 1;
        }

        return lo < chunks.Length ? lo : -1;
    }

    private static int NormalizeLineStartInChunk(PreparedText prepared, int chunkIndex, ref LineBreakCursor cursor)
    {
        int segmentIndex = cursor.SegmentIndex;
        if (cursor.GraphemeIndex > 0) return chunkIndex;

        PreparedLineChunk chunk = prepared.Chunks[chunkIndex];
        if (chunk.StartSegmentIndex == chunk.EndSegmentIndex && segmentIndex == chunk.StartSegmentIndex)
        {
            cursor.SegmentIndex = segmentIndex;
            cursor.GraphemeIndex = 0;
            return chunkIndex;
        }

        if (segmentIndex < chunk.StartSegmentIndex) segmentIndex = chunk.StartSegmentIndex;
        segmentIndex = NormalizeLineStartSegmentIndex(prepared, segmentIndex, chunk.EndSegmentIndex);
        if (segmentIndex < chunk.EndSegmentIndex)
        {
            cursor.SegmentIndex = segmentIndex;
            cursor.GraphemeIndex = 0;
            return chunkIndex;
        }

        if (chunk.ConsumedEndSegmentIndex >= prepared.Widths.Length) return -1;
        cursor.SegmentIndex = chunk.ConsumedEndSegmentIndex;
        cursor.GraphemeIndex = 0;
        return chunkIndex + 1;
    }

    /// <summary>Mutates <paramref name="cursor"/> to the next renderable line start and returns its chunk index.</summary>
    internal static int NormalizeLineStart(PreparedText prepared, ref LineBreakCursor cursor)
    {
        if (cursor.SegmentIndex >= prepared.Widths.Length) return -1;

        int chunkIndex = FindChunkIndexForStart(prepared, cursor.SegmentIndex);
        if (chunkIndex < 0) return -1;
        return NormalizeLineStartInChunk(prepared, chunkIndex, ref cursor);
    }

    private static int NormalizeLineStartChunkIndexFromHint(PreparedText prepared, int chunkIndex, ref LineBreakCursor cursor)
    {
        if (cursor.SegmentIndex >= prepared.Widths.Length) return -1;

        int nextChunkIndex = chunkIndex;
        PreparedLineChunk[] chunks = prepared.Chunks;
        while (nextChunkIndex < chunks.Length && cursor.SegmentIndex >= chunks[nextChunkIndex].ConsumedEndSegmentIndex)
        {
            nextChunkIndex++;
        }
        if (nextChunkIndex >= chunks.Length) return -1;
        return NormalizeLineStartInChunk(prepared, nextChunkIndex, ref cursor);
    }

    internal static int CountLines(PreparedText prepared, double maxWidth)
        => WalkLinesRaw(prepared, maxWidth, null);

    // ---- Simple fast-path walker (upstream lines 297-484) --------------

    private struct SimpleWalkState
    {
        internal double LineWidth;
        internal bool HasContent;
        internal int LineStartSegmentIndex;
        internal int LineStartGraphemeIndex;
        internal int LineEndSegmentIndex;
        internal int LineEndGraphemeIndex;
        internal int PendingBreakSegmentIndex;
        internal double PendingBreakPaintWidth;
    }

    private static void ClearPendingBreak(ref SimpleWalkState state)
    {
        state.PendingBreakSegmentIndex = -1;
        state.PendingBreakPaintWidth = 0;
    }

    private static void EmitCurrentLine(ref SimpleWalkState state, ref int lineCount, LineVisitor? onLine)
        => EmitCurrentLine(ref state, ref lineCount, onLine, state.LineEndSegmentIndex, state.LineEndGraphemeIndex, state.LineWidth);

    private static void EmitCurrentLine(
        ref SimpleWalkState state,
        ref int lineCount,
        LineVisitor? onLine,
        int endSegmentIndex,
        int endGraphemeIndex,
        double width)
    {
        lineCount++;
        onLine?.Invoke(width, state.LineStartSegmentIndex, state.LineStartGraphemeIndex, endSegmentIndex, endGraphemeIndex);
        state.LineWidth = 0;
        state.HasContent = false;
        ClearPendingBreak(ref state);
    }

    private static void StartLineAtSegment(ref SimpleWalkState state, int segmentIndex, double width)
    {
        state.HasContent = true;
        state.LineStartSegmentIndex = segmentIndex;
        state.LineStartGraphemeIndex = 0;
        state.LineEndSegmentIndex = segmentIndex + 1;
        state.LineEndGraphemeIndex = 0;
        state.LineWidth = width;
    }

    private static void StartLineAtGrapheme(ref SimpleWalkState state, int segmentIndex, int graphemeIndex, double width)
    {
        state.HasContent = true;
        state.LineStartSegmentIndex = segmentIndex;
        state.LineStartGraphemeIndex = graphemeIndex;
        state.LineEndSegmentIndex = segmentIndex;
        state.LineEndGraphemeIndex = graphemeIndex + 1;
        state.LineWidth = width;
    }

    private static void AppendWholeSegment(ref SimpleWalkState state, int segmentIndex, double width)
    {
        if (!state.HasContent)
        {
            StartLineAtSegment(ref state, segmentIndex, width);
            return;
        }
        state.LineWidth += width;
        state.LineEndSegmentIndex = segmentIndex + 1;
        state.LineEndGraphemeIndex = 0;
    }

    private static void AppendBreakableSegmentFrom(
        PreparedText prepared,
        ref SimpleWalkState state,
        ref int lineCount,
        LineVisitor? onLine,
        double fitLimit,
        int segmentIndex,
        int startGraphemeIndex)
    {
        double[] fitAdvances = prepared.BreakableFitAdvances[segmentIndex]!;
        int[]? preferredBreaks = prepared.BreakablePreferredBreaks[segmentIndex];
        int preferredBreakIndex = preferredBreaks is null
            ? -1
            : GetNextPreferredBreakIndex(preferredBreaks, 0, startGraphemeIndex + 1);
        int lastPreferredBreakEnd = -1;
        double lastPreferredBreakWidth = 0;

        int g = startGraphemeIndex;
        while (g < fitAdvances.Length)
        {
            double gw = fitAdvances[g];

            if (!state.HasContent)
            {
                StartLineAtGrapheme(ref state, segmentIndex, g, gw);
            }
            else if (state.LineWidth + gw > fitLimit)
            {
                if (preferredBreaks is not null && lastPreferredBreakEnd > startGraphemeIndex)
                {
                    EmitCurrentLine(ref state, ref lineCount, onLine, segmentIndex, lastPreferredBreakEnd, lastPreferredBreakWidth);
                    g = lastPreferredBreakEnd;
                    preferredBreakIndex = GetNextPreferredBreakIndex(preferredBreaks, preferredBreakIndex, g + 1);
                    lastPreferredBreakEnd = -1;
                    lastPreferredBreakWidth = 0;
                    continue;
                }
                EmitCurrentLine(ref state, ref lineCount, onLine);
                StartLineAtGrapheme(ref state, segmentIndex, g, gw);
            }
            else
            {
                state.LineWidth += gw;
                state.LineEndSegmentIndex = segmentIndex;
                state.LineEndGraphemeIndex = g + 1;
            }

            int graphemeEnd = g + 1;
            if (preferredBreaks is not null && preferredBreakIndex < preferredBreaks.Length && preferredBreaks[preferredBreakIndex] == graphemeEnd)
            {
                lastPreferredBreakEnd = graphemeEnd;
                lastPreferredBreakWidth = state.LineWidth;
                preferredBreakIndex++;
            }
            g++;
        }

        if (state.HasContent && state.LineEndSegmentIndex == segmentIndex && state.LineEndGraphemeIndex == fitAdvances.Length)
        {
            state.LineEndSegmentIndex = segmentIndex + 1;
            state.LineEndGraphemeIndex = 0;
        }
    }

    private static int WalkLinesSimple(PreparedText prepared, double maxWidth, LineVisitor? onLine)
    {
        double[] widths = prepared.Widths;
        if (widths.Length == 0) return 0;

        double fitLimit = maxWidth + LayoutProfile.LineFitEpsilon;

        int lineCount = 0;
        SimpleWalkState state = default;
        ClearPendingBreak(ref state);

        int i = 0;
        while (i < widths.Length)
        {
            if (!state.HasContent)
            {
                i = NormalizeLineStartSegmentIndex(prepared, i);
                if (i >= widths.Length) break;
            }

            double w = widths[i];
            SegmentBreakKind kind = prepared.Kinds[i];
            bool breakAfter = BreaksAfter(kind);

            if (!state.HasContent)
            {
                if (w > fitLimit && prepared.BreakableFitAdvances[i] is not null)
                {
                    AppendBreakableSegmentFrom(prepared, ref state, ref lineCount, onLine, fitLimit, i, 0);
                }
                else
                {
                    StartLineAtSegment(ref state, i, w);
                }
                if (breakAfter)
                {
                    state.PendingBreakSegmentIndex = i + 1;
                    state.PendingBreakPaintWidth = state.LineWidth - w;
                }
                i++;
                continue;
            }

            double newW = state.LineWidth + w;
            if (newW > fitLimit)
            {
                if (breakAfter)
                {
                    AppendWholeSegment(ref state, i, w);
                    EmitCurrentLine(ref state, ref lineCount, onLine, i + 1, 0, state.LineWidth - w);
                    i++;
                    continue;
                }

                if (state.PendingBreakSegmentIndex >= 0)
                {
                    if (state.LineEndSegmentIndex > state.PendingBreakSegmentIndex
                        || (state.LineEndSegmentIndex == state.PendingBreakSegmentIndex && state.LineEndGraphemeIndex > 0))
                    {
                        EmitCurrentLine(ref state, ref lineCount, onLine);
                        continue;
                    }
                    EmitCurrentLine(ref state, ref lineCount, onLine, state.PendingBreakSegmentIndex, 0, state.PendingBreakPaintWidth);
                    continue;
                }

                if (w > fitLimit && prepared.BreakableFitAdvances[i] is not null)
                {
                    EmitCurrentLine(ref state, ref lineCount, onLine);
                    AppendBreakableSegmentFrom(prepared, ref state, ref lineCount, onLine, fitLimit, i, 0);
                    i++;
                    continue;
                }

                EmitCurrentLine(ref state, ref lineCount, onLine);
                continue;
            }

            AppendWholeSegment(ref state, i, w);
            if (breakAfter)
            {
                state.PendingBreakSegmentIndex = i + 1;
                state.PendingBreakPaintWidth = state.LineWidth - w;
            }
            i++;
        }

        if (state.HasContent) EmitCurrentLine(ref state, ref lineCount, onLine);
        return lineCount;
    }

    internal static int WalkLines(PreparedText prepared, double maxWidth, LineVisitor onLine)
        => WalkLinesRaw(prepared, maxWidth, onLine);

    private static int WalkLinesRaw(PreparedText prepared, double maxWidth, LineVisitor? onLine)
        => prepared.SimpleLineWalkFastPath
            ? WalkLinesSimple(prepared, maxWidth, onLine)
            : WalkLinesChunked(prepared, maxWidth, onLine);

    // ---- Chunked (hard-break aware) walker (upstream lines 486-776) ----

    private struct ChunkWalkState
    {
        internal double LineWidth;
        internal bool HasContent;
        internal int LineStartSegmentIndex;
        internal int LineStartGraphemeIndex;
        internal int LineEndSegmentIndex;
        internal int LineEndGraphemeIndex;
        internal int PendingBreakSegmentIndex;
        internal double PendingBreakFitWidth;
        internal double PendingBreakPaintWidth;
        internal SegmentBreakKind? PendingBreakKind;
    }

    private static void ClearPendingBreak(ref ChunkWalkState state)
    {
        state.PendingBreakSegmentIndex = -1;
        state.PendingBreakFitWidth = 0;
        state.PendingBreakPaintWidth = 0;
        state.PendingBreakKind = null;
    }

    private static double GetCurrentLinePaintWidth(in ChunkWalkState state)
        => state.PendingBreakKind == SegmentBreakKind.SoftHyphen
            && state.PendingBreakSegmentIndex == state.LineEndSegmentIndex
            && state.LineEndGraphemeIndex == 0
            ? state.PendingBreakPaintWidth
            : state.LineWidth;

    private static void EmitCurrentLine(PreparedText prepared, ref ChunkWalkState state, ref int lineCount, LineVisitor? onLine)
        => EmitCurrentLine(
            prepared, ref state, ref lineCount, onLine,
            state.LineEndSegmentIndex, state.LineEndGraphemeIndex, GetCurrentLinePaintWidth(state));

    private static void EmitCurrentLine(
        PreparedText prepared,
        ref ChunkWalkState state,
        ref int lineCount,
        LineVisitor? onLine,
        int endSegmentIndex,
        int endGraphemeIndex,
        double width)
    {
        lineCount++;
        if (onLine is not null)
        {
            double paintWidth = FinalizeLinePaintWidth(
                prepared, width, state.LineStartSegmentIndex, state.LineStartGraphemeIndex, endSegmentIndex, endGraphemeIndex);
            onLine(paintWidth, state.LineStartSegmentIndex, state.LineStartGraphemeIndex, endSegmentIndex, endGraphemeIndex);
        }
        state.LineWidth = 0;
        state.HasContent = false;
        ClearPendingBreak(ref state);
    }

    private static void StartLineAtSegment(ref ChunkWalkState state, int segmentIndex, double width)
    {
        state.HasContent = true;
        state.LineStartSegmentIndex = segmentIndex;
        state.LineStartGraphemeIndex = 0;
        state.LineEndSegmentIndex = segmentIndex + 1;
        state.LineEndGraphemeIndex = 0;
        state.LineWidth = width;
    }

    private static void StartLineAtGrapheme(ref ChunkWalkState state, int segmentIndex, int graphemeIndex, double width)
    {
        state.HasContent = true;
        state.LineStartSegmentIndex = segmentIndex;
        state.LineStartGraphemeIndex = graphemeIndex;
        state.LineEndSegmentIndex = segmentIndex;
        state.LineEndGraphemeIndex = graphemeIndex + 1;
        state.LineWidth = width;
    }

    private static void AppendWholeSegment(ref ChunkWalkState state, int segmentIndex, double advance)
    {
        if (!state.HasContent)
        {
            StartLineAtSegment(ref state, segmentIndex, advance);
            return;
        }
        state.LineWidth += advance;
        state.LineEndSegmentIndex = segmentIndex + 1;
        state.LineEndGraphemeIndex = 0;
    }

    private static void UpdatePendingBreakForWholeSegment(
        PreparedText prepared,
        ref ChunkWalkState state,
        SegmentBreakKind kind,
        bool breakAfter,
        int segmentIndex,
        double segmentWidth,
        double leadingSpacing,
        double advance)
    {
        if (!breakAfter) return;
        double fitAdvance = GetBreakOpportunityFitContribution(prepared, kind, segmentIndex, leadingSpacing);
        double paintAdvance = GetLineEndPaintContribution(prepared, kind, segmentIndex, leadingSpacing, segmentWidth);
        state.PendingBreakSegmentIndex = segmentIndex + 1;
        state.PendingBreakFitWidth = state.LineWidth - advance + fitAdvance;
        state.PendingBreakPaintWidth = state.LineWidth - advance + paintAdvance;
        state.PendingBreakKind = kind;
    }

    private static void AppendBreakableSegmentFrom(
        PreparedText prepared,
        ref ChunkWalkState state,
        ref int lineCount,
        LineVisitor? onLine,
        double fitLimit,
        int segmentIndex,
        int startGraphemeIndex)
    {
        double[] fitAdvances = prepared.BreakableFitAdvances[segmentIndex]!;
        int[]? preferredBreaks = prepared.BreakablePreferredBreaks[segmentIndex];
        int preferredBreakIndex = preferredBreaks is null
            ? -1
            : GetNextPreferredBreakIndex(preferredBreaks, 0, startGraphemeIndex + 1);
        int lastPreferredBreakEnd = -1;
        double lastPreferredBreakWidth = 0;

        int g = startGraphemeIndex;
        while (g < fitAdvances.Length)
        {
            double baseGw = fitAdvances[g];

            if (!state.HasContent)
            {
                StartLineAtGrapheme(ref state, segmentIndex, g, baseGw);
            }
            else
            {
                double gw = GetBreakableGraphemeAdvance(prepared, true, baseGw);
                double candidatePaintWidth = state.LineWidth + gw;
                if (GetBreakableCandidateFitWidth(prepared, candidatePaintWidth) > fitLimit)
                {
                    if (preferredBreaks is not null && lastPreferredBreakEnd > startGraphemeIndex)
                    {
                        EmitCurrentLine(prepared, ref state, ref lineCount, onLine, segmentIndex, lastPreferredBreakEnd, lastPreferredBreakWidth);
                        g = lastPreferredBreakEnd;
                        preferredBreakIndex = GetNextPreferredBreakIndex(preferredBreaks, preferredBreakIndex, g + 1);
                        lastPreferredBreakEnd = -1;
                        lastPreferredBreakWidth = 0;
                        continue;
                    }
                    EmitCurrentLine(prepared, ref state, ref lineCount, onLine);
                    StartLineAtGrapheme(ref state, segmentIndex, g, baseGw);
                }
                else
                {
                    state.LineWidth = candidatePaintWidth;
                    state.LineEndSegmentIndex = segmentIndex;
                    state.LineEndGraphemeIndex = g + 1;
                }
            }

            int graphemeEnd = g + 1;
            if (preferredBreaks is not null && preferredBreakIndex < preferredBreaks.Length && preferredBreaks[preferredBreakIndex] == graphemeEnd)
            {
                lastPreferredBreakEnd = graphemeEnd;
                lastPreferredBreakWidth = state.LineWidth;
                preferredBreakIndex++;
            }
            g++;
        }

        if (state.HasContent && state.LineEndSegmentIndex == segmentIndex && state.LineEndGraphemeIndex == fitAdvances.Length)
        {
            state.LineEndSegmentIndex = segmentIndex + 1;
            state.LineEndGraphemeIndex = 0;
        }
    }

    private static void EmitEmptyChunk(ref ChunkWalkState state, ref int lineCount, LineVisitor? onLine, PreparedLineChunk chunk)
    {
        lineCount++;
        onLine?.Invoke(0, chunk.StartSegmentIndex, 0, chunk.ConsumedEndSegmentIndex, 0);
        ClearPendingBreak(ref state);
    }

    private static int WalkLinesChunked(PreparedText prepared, double maxWidth, LineVisitor? onLine)
    {
        double[] widths = prepared.Widths;
        SegmentBreakKind[] kinds = prepared.Kinds;
        PreparedLineChunk[] chunks = prepared.Chunks;
        if (widths.Length == 0 || chunks.Length == 0) return 0;

        double fitLimit = maxWidth + LayoutProfile.LineFitEpsilon;

        int lineCount = 0;
        ChunkWalkState state = default;

        for (int chunkIndex = 0; chunkIndex < chunks.Length; chunkIndex++)
        {
            PreparedLineChunk chunk = chunks[chunkIndex];
            if (chunk.StartSegmentIndex == chunk.EndSegmentIndex)
            {
                EmitEmptyChunk(ref state, ref lineCount, onLine, chunk);
                continue;
            }

            state = default;
            state.LineStartSegmentIndex = chunk.StartSegmentIndex;
            state.LineEndSegmentIndex = chunk.StartSegmentIndex;
            ClearPendingBreak(ref state);

            int i = chunk.StartSegmentIndex;
            while (i < chunk.EndSegmentIndex)
            {
                if (!state.HasContent)
                {
                    i = NormalizeLineStartSegmentIndex(prepared, i, chunk.EndSegmentIndex);
                    if (i >= chunk.EndSegmentIndex) break;
                }

                SegmentBreakKind kind = kinds[i];
                bool breakAfter = BreaksAfter(kind);
                double leadingSpacing = GetLeadingLetterSpacing(prepared, state.HasContent, i);
                double w = kind == SegmentBreakKind.Tab
                    ? GetTabAdvance(state.LineWidth + leadingSpacing, prepared.TabStopAdvance)
                    : widths[i];
                double advance = leadingSpacing + w;
                double fitAdvance = GetWholeSegmentFitContribution(prepared, kind, i, leadingSpacing, w);

                if (kind == SegmentBreakKind.SoftHyphen)
                {
                    if (state.HasContent)
                    {
                        state.LineEndSegmentIndex = i + 1;
                        state.LineEndGraphemeIndex = 0;
                        state.PendingBreakSegmentIndex = i + 1;
                        state.PendingBreakFitWidth = state.LineWidth + prepared.DiscretionaryHyphenWidth;
                        state.PendingBreakPaintWidth = state.LineWidth + prepared.DiscretionaryHyphenWidth;
                        state.PendingBreakKind = kind;
                    }
                    i++;
                    continue;
                }

                if (!state.HasContent)
                {
                    if (fitAdvance > fitLimit && prepared.BreakableFitAdvances[i] is not null)
                    {
                        AppendBreakableSegmentFrom(prepared, ref state, ref lineCount, onLine, fitLimit, i, 0);
                    }
                    else
                    {
                        StartLineAtSegment(ref state, i, w);
                    }
                    UpdatePendingBreakForWholeSegment(prepared, ref state, kind, breakAfter, i, w, leadingSpacing, advance);
                    i++;
                    continue;
                }

                double newFitW = state.LineWidth + fitAdvance;
                if (newFitW > fitLimit)
                {
                    double currentBreakFitWidth = state.LineWidth + GetBreakOpportunityFitContribution(prepared, kind, i, leadingSpacing);
                    double currentBreakPaintWidth = state.LineWidth + GetLineEndPaintContribution(prepared, kind, i, leadingSpacing, w);

                    if (breakAfter && currentBreakFitWidth <= fitLimit)
                    {
                        AppendWholeSegment(ref state, i, advance);
                        EmitCurrentLine(prepared, ref state, ref lineCount, onLine, i + 1, 0, currentBreakPaintWidth);
                        i++;
                        continue;
                    }

                    if (state.PendingBreakSegmentIndex >= 0 && state.PendingBreakFitWidth <= fitLimit)
                    {
                        if (state.LineEndSegmentIndex > state.PendingBreakSegmentIndex
                            || (state.LineEndSegmentIndex == state.PendingBreakSegmentIndex && state.LineEndGraphemeIndex > 0))
                        {
                            EmitCurrentLine(prepared, ref state, ref lineCount, onLine);
                            continue;
                        }
                        int nextSegmentIndex = state.PendingBreakSegmentIndex;
                        EmitCurrentLine(prepared, ref state, ref lineCount, onLine, nextSegmentIndex, 0, state.PendingBreakPaintWidth);
                        i = nextSegmentIndex;
                        continue;
                    }

                    if (fitAdvance > fitLimit && prepared.BreakableFitAdvances[i] is not null)
                    {
                        EmitCurrentLine(prepared, ref state, ref lineCount, onLine);
                        AppendBreakableSegmentFrom(prepared, ref state, ref lineCount, onLine, fitLimit, i, 0);
                        i++;
                        continue;
                    }

                    EmitCurrentLine(prepared, ref state, ref lineCount, onLine);
                    continue;
                }

                AppendWholeSegment(ref state, i, advance);
                UpdatePendingBreakForWholeSegment(prepared, ref state, kind, breakAfter, i, w, leadingSpacing, advance);
                i++;
            }

            if (state.HasContent)
            {
                double finalPaintWidth = state.PendingBreakSegmentIndex == chunk.ConsumedEndSegmentIndex
                    ? state.PendingBreakPaintWidth
                    : state.LineWidth;
                EmitCurrentLine(prepared, ref state, ref lineCount, onLine, chunk.ConsumedEndSegmentIndex, 0, finalPaintWidth);
            }
        }

        return lineCount;
    }

    // ---- Single-chunk geometry step (upstream lines 778-1017) ----------

    private struct ChunkStepState
    {
        internal readonly int LineStartSegmentIndex;
        internal readonly int LineStartGraphemeIndex;
        internal double LineWidth;
        internal bool HasContent;
        internal int LineEndSegmentIndex;
        internal int LineEndGraphemeIndex;
        internal int PendingBreakSegmentIndex;
        internal double PendingBreakFitWidth;
        internal double PendingBreakPaintWidth;
        internal SegmentBreakKind? PendingBreakKind;

        internal ChunkStepState(int lineStartSegmentIndex, int lineStartGraphemeIndex, int lineEndSegmentIndex, int lineEndGraphemeIndex)
        {
            LineStartSegmentIndex = lineStartSegmentIndex;
            LineStartGraphemeIndex = lineStartGraphemeIndex;
            LineWidth = 0;
            HasContent = false;
            LineEndSegmentIndex = lineEndSegmentIndex;
            LineEndGraphemeIndex = lineEndGraphemeIndex;
            PendingBreakSegmentIndex = -1;
            PendingBreakFitWidth = 0;
            PendingBreakPaintWidth = 0;
            PendingBreakKind = null;
        }
    }

    private static double GetCurrentLinePaintWidth(in ChunkStepState state)
        => state.PendingBreakKind == SegmentBreakKind.SoftHyphen
            && state.PendingBreakSegmentIndex == state.LineEndSegmentIndex
            && state.LineEndGraphemeIndex == 0
            ? state.PendingBreakPaintWidth
            : state.LineWidth;

    private static double? FinishLine(PreparedText prepared, ref ChunkStepState state, ref LineBreakCursor cursor)
        => FinishLine(prepared, ref state, ref cursor, state.LineEndSegmentIndex, state.LineEndGraphemeIndex, GetCurrentLinePaintWidth(state));

    private static double? FinishLine(
        PreparedText prepared,
        ref ChunkStepState state,
        ref LineBreakCursor cursor,
        int endSegmentIndex,
        int endGraphemeIndex,
        double width)
    {
        if (!state.HasContent) return null;
        cursor.SegmentIndex = endSegmentIndex;
        cursor.GraphemeIndex = endGraphemeIndex;
        return FinalizeLinePaintWidth(prepared, width, state.LineStartSegmentIndex, state.LineStartGraphemeIndex, endSegmentIndex, endGraphemeIndex);
    }

    private static void StartLineAtSegment(ref ChunkStepState state, int segmentIndex, double width)
    {
        state.HasContent = true;
        state.LineEndSegmentIndex = segmentIndex + 1;
        state.LineEndGraphemeIndex = 0;
        state.LineWidth = width;
    }

    private static void StartLineAtGrapheme(ref ChunkStepState state, int segmentIndex, int graphemeIndex, double width)
    {
        state.HasContent = true;
        state.LineEndSegmentIndex = segmentIndex;
        state.LineEndGraphemeIndex = graphemeIndex + 1;
        state.LineWidth = width;
    }

    private static void AppendWholeSegment(ref ChunkStepState state, int segmentIndex, double advance)
    {
        if (!state.HasContent)
        {
            StartLineAtSegment(ref state, segmentIndex, advance);
            return;
        }
        state.LineWidth += advance;
        state.LineEndSegmentIndex = segmentIndex + 1;
        state.LineEndGraphemeIndex = 0;
    }

    private static void UpdatePendingBreakForWholeSegment(
        PreparedText prepared,
        ref ChunkStepState state,
        SegmentBreakKind kind,
        bool breakAfter,
        int segmentIndex,
        double segmentWidth,
        double leadingSpacing,
        double advance)
    {
        if (!breakAfter) return;
        double fitAdvance = GetBreakOpportunityFitContribution(prepared, kind, segmentIndex, leadingSpacing);
        double paintAdvance = GetLineEndPaintContribution(prepared, kind, segmentIndex, leadingSpacing, segmentWidth);
        state.PendingBreakSegmentIndex = segmentIndex + 1;
        state.PendingBreakFitWidth = state.LineWidth - advance + fitAdvance;
        state.PendingBreakPaintWidth = state.LineWidth - advance + paintAdvance;
        state.PendingBreakKind = kind;
    }

    private static double? AppendBreakableSegmentFrom(
        PreparedText prepared,
        ref ChunkStepState state,
        ref LineBreakCursor cursor,
        double fitLimit,
        int segmentIndex,
        int startGraphemeIndex)
    {
        double[] fitAdvances = prepared.BreakableFitAdvances[segmentIndex]!;
        int[]? preferredBreaks = prepared.BreakablePreferredBreaks[segmentIndex];
        int preferredBreakIndex = preferredBreaks is null
            ? -1
            : GetNextPreferredBreakIndex(preferredBreaks, 0, startGraphemeIndex + 1);
        int lastPreferredBreakEnd = -1;
        double lastPreferredBreakWidth = 0;

        for (int g = startGraphemeIndex; g < fitAdvances.Length; g++)
        {
            double baseGw = fitAdvances[g];

            if (!state.HasContent)
            {
                StartLineAtGrapheme(ref state, segmentIndex, g, baseGw);
            }
            else
            {
                double gw = GetBreakableGraphemeAdvance(prepared, true, baseGw);
                double candidatePaintWidth = state.LineWidth + gw;
                if (GetBreakableCandidateFitWidth(prepared, candidatePaintWidth) > fitLimit)
                {
                    if (preferredBreaks is not null && lastPreferredBreakEnd > startGraphemeIndex)
                    {
                        return FinishLine(prepared, ref state, ref cursor, segmentIndex, lastPreferredBreakEnd, lastPreferredBreakWidth);
                    }
                    return FinishLine(prepared, ref state, ref cursor);
                }

                state.LineWidth = candidatePaintWidth;
                state.LineEndSegmentIndex = segmentIndex;
                state.LineEndGraphemeIndex = g + 1;
            }

            int graphemeEnd = g + 1;
            if (preferredBreaks is not null && preferredBreakIndex < preferredBreaks.Length && preferredBreaks[preferredBreakIndex] == graphemeEnd)
            {
                lastPreferredBreakEnd = graphemeEnd;
                lastPreferredBreakWidth = state.LineWidth;
                preferredBreakIndex++;
            }
        }

        if (state.HasContent && state.LineEndSegmentIndex == segmentIndex && state.LineEndGraphemeIndex == fitAdvances.Length)
        {
            state.LineEndSegmentIndex = segmentIndex + 1;
            state.LineEndGraphemeIndex = 0;
        }
        return null;
    }

    private static double? MaybeFinishAtSoftHyphen(PreparedText prepared, ref ChunkStepState state, ref LineBreakCursor cursor, double fitLimit)
    {
        if (state.PendingBreakKind != SegmentBreakKind.SoftHyphen || state.PendingBreakSegmentIndex < 0) return null;

        if (state.PendingBreakFitWidth <= fitLimit)
        {
            return FinishLine(prepared, ref state, ref cursor, state.PendingBreakSegmentIndex, 0, state.PendingBreakPaintWidth);
        }

        return null;
    }

    private static double? StepChunkLineGeometry(PreparedText prepared, ref LineBreakCursor cursor, int chunkIndex, double maxWidth)
    {
        PreparedLineChunk chunk = prepared.Chunks[chunkIndex];
        if (chunk.StartSegmentIndex == chunk.EndSegmentIndex)
        {
            cursor.SegmentIndex = chunk.ConsumedEndSegmentIndex;
            cursor.GraphemeIndex = 0;
            return 0;
        }

        double[] widths = prepared.Widths;
        SegmentBreakKind[] kinds = prepared.Kinds;
        double fitLimit = maxWidth + LayoutProfile.LineFitEpsilon;

        int lineStartSegmentIndex = cursor.SegmentIndex;
        int lineStartGraphemeIndex = cursor.GraphemeIndex;
        ChunkStepState state = new(lineStartSegmentIndex, lineStartGraphemeIndex, lineStartSegmentIndex, lineStartGraphemeIndex);

        for (int i = lineStartSegmentIndex; i < chunk.EndSegmentIndex; i++)
        {
            SegmentBreakKind kind = kinds[i];
            bool breakAfter = BreaksAfter(kind);
            int startGraphemeIndex = i == lineStartSegmentIndex ? lineStartGraphemeIndex : 0;
            double leadingSpacing = GetLeadingLetterSpacing(prepared, state.HasContent, i);
            double w = kind == SegmentBreakKind.Tab
                ? GetTabAdvance(state.LineWidth + leadingSpacing, prepared.TabStopAdvance)
                : widths[i];
            double advance = leadingSpacing + w;
            double fitAdvance = GetWholeSegmentFitContribution(prepared, kind, i, leadingSpacing, w);

            if (kind == SegmentBreakKind.SoftHyphen && startGraphemeIndex == 0)
            {
                if (state.HasContent)
                {
                    state.LineEndSegmentIndex = i + 1;
                    state.LineEndGraphemeIndex = 0;
                    state.PendingBreakSegmentIndex = i + 1;
                    state.PendingBreakFitWidth = state.LineWidth + prepared.DiscretionaryHyphenWidth;
                    state.PendingBreakPaintWidth = state.LineWidth + prepared.DiscretionaryHyphenWidth;
                    state.PendingBreakKind = kind;
                }
                continue;
            }

            if (!state.HasContent)
            {
                if (startGraphemeIndex > 0)
                {
                    double? line = AppendBreakableSegmentFrom(prepared, ref state, ref cursor, fitLimit, i, startGraphemeIndex);
                    if (line is not null) return line;
                }
                else if (fitAdvance > fitLimit && prepared.BreakableFitAdvances[i] is not null)
                {
                    double? line = AppendBreakableSegmentFrom(prepared, ref state, ref cursor, fitLimit, i, 0);
                    if (line is not null) return line;
                }
                else
                {
                    StartLineAtSegment(ref state, i, w);
                }
                UpdatePendingBreakForWholeSegment(prepared, ref state, kind, breakAfter, i, w, leadingSpacing, advance);
                continue;
            }

            double newFitW = state.LineWidth + fitAdvance;
            if (newFitW > fitLimit)
            {
                double currentBreakFitWidth = state.LineWidth + GetBreakOpportunityFitContribution(prepared, kind, i, leadingSpacing);
                double currentBreakPaintWidth = state.LineWidth + GetLineEndPaintContribution(prepared, kind, i, leadingSpacing, w);

                double? softBreakLine = MaybeFinishAtSoftHyphen(prepared, ref state, ref cursor, fitLimit);
                if (softBreakLine is not null) return softBreakLine;

                if (breakAfter && currentBreakFitWidth <= fitLimit)
                {
                    AppendWholeSegment(ref state, i, advance);
                    return FinishLine(prepared, ref state, ref cursor, i + 1, 0, currentBreakPaintWidth);
                }

                if (state.PendingBreakSegmentIndex >= 0 && state.PendingBreakFitWidth <= fitLimit)
                {
                    if (state.LineEndSegmentIndex > state.PendingBreakSegmentIndex
                        || (state.LineEndSegmentIndex == state.PendingBreakSegmentIndex && state.LineEndGraphemeIndex > 0))
                    {
                        return FinishLine(prepared, ref state, ref cursor);
                    }
                    return FinishLine(prepared, ref state, ref cursor, state.PendingBreakSegmentIndex, 0, state.PendingBreakPaintWidth);
                }

                if (fitAdvance > fitLimit && prepared.BreakableFitAdvances[i] is not null)
                {
                    double? currentLine = FinishLine(prepared, ref state, ref cursor);
                    if (currentLine is not null) return currentLine;
                    double? line = AppendBreakableSegmentFrom(prepared, ref state, ref cursor, fitLimit, i, 0);
                    if (line is not null) return line;
                }

                return FinishLine(prepared, ref state, ref cursor);
            }

            AppendWholeSegment(ref state, i, advance);
            UpdatePendingBreakForWholeSegment(prepared, ref state, kind, breakAfter, i, w, leadingSpacing, advance);
        }

        if (state.PendingBreakSegmentIndex == chunk.ConsumedEndSegmentIndex && state.LineEndGraphemeIndex == 0)
        {
            return FinishLine(prepared, ref state, ref cursor, chunk.ConsumedEndSegmentIndex, 0, state.PendingBreakPaintWidth);
        }

        return FinishLine(prepared, ref state, ref cursor, chunk.ConsumedEndSegmentIndex, 0, state.LineWidth);
    }

    // ---- Simple fast-path geometry step (upstream lines 1019-1142) -----

    private static double? StepSimpleLineGeometry(PreparedText prepared, ref LineBreakCursor cursor, double maxWidth)
    {
        double[] widths = prepared.Widths;
        SegmentBreakKind[] kinds = prepared.Kinds;
        double fitLimit = maxWidth + LayoutProfile.LineFitEpsilon;

        double lineW = 0;
        bool hasContent = false;
        int lineEndSegmentIndex = cursor.SegmentIndex;
        int lineEndGraphemeIndex = cursor.GraphemeIndex;
        int pendingBreakSegmentIndex = -1;
        double pendingBreakPaintWidth = 0;

        for (int i = cursor.SegmentIndex; i < widths.Length; i++)
        {
            SegmentBreakKind kind = kinds[i];
            bool breakAfter = BreaksAfter(kind);
            int startGraphemeIndex = i == cursor.SegmentIndex ? cursor.GraphemeIndex : 0;
            double[]? breakableFitAdvance = prepared.BreakableFitAdvances[i];
            double w = widths[i];

            if (!hasContent)
            {
                if (startGraphemeIndex > 0 || (w > fitLimit && breakableFitAdvance is not null))
                {
                    double[] fitAdvances = breakableFitAdvance!;
                    int[]? preferredBreaks = prepared.BreakablePreferredBreaks[i];
                    int preferredBreakIndex = preferredBreaks is null
                        ? -1
                        : GetNextPreferredBreakIndex(preferredBreaks, 0, startGraphemeIndex + 1);
                    int lastPreferredBreakEnd = -1;
                    double lastPreferredBreakWidth = 0;
                    double firstGraphemeWidth = fitAdvances[startGraphemeIndex];

                    hasContent = true;
                    lineW = firstGraphemeWidth;
                    lineEndSegmentIndex = i;
                    lineEndGraphemeIndex = startGraphemeIndex + 1;
                    if (preferredBreaks is not null && preferredBreakIndex < preferredBreaks.Length
                        && preferredBreaks[preferredBreakIndex] == lineEndGraphemeIndex)
                    {
                        lastPreferredBreakEnd = lineEndGraphemeIndex;
                        lastPreferredBreakWidth = lineW;
                        preferredBreakIndex++;
                    }

                    for (int g = startGraphemeIndex + 1; g < fitAdvances.Length; g++)
                    {
                        double gw = fitAdvances[g];
                        if (lineW + gw > fitLimit)
                        {
                            if (preferredBreaks is not null && lastPreferredBreakEnd > startGraphemeIndex)
                            {
                                cursor.SegmentIndex = i;
                                cursor.GraphemeIndex = lastPreferredBreakEnd;
                                return lastPreferredBreakWidth;
                            }
                            cursor.SegmentIndex = lineEndSegmentIndex;
                            cursor.GraphemeIndex = lineEndGraphemeIndex;
                            return lineW;
                        }
                        lineW += gw;
                        lineEndSegmentIndex = i;
                        lineEndGraphemeIndex = g + 1;
                        if (preferredBreaks is not null && preferredBreakIndex < preferredBreaks.Length
                            && preferredBreaks[preferredBreakIndex] == lineEndGraphemeIndex)
                        {
                            lastPreferredBreakEnd = lineEndGraphemeIndex;
                            lastPreferredBreakWidth = lineW;
                            preferredBreakIndex++;
                        }
                    }

                    if (lineEndSegmentIndex == i && lineEndGraphemeIndex == fitAdvances.Length)
                    {
                        lineEndSegmentIndex = i + 1;
                        lineEndGraphemeIndex = 0;
                    }
                }
                else
                {
                    hasContent = true;
                    lineW = w;
                    lineEndSegmentIndex = i + 1;
                    lineEndGraphemeIndex = 0;
                }
                if (breakAfter)
                {
                    pendingBreakSegmentIndex = i + 1;
                    pendingBreakPaintWidth = lineW - w;
                }
                continue;
            }

            if (lineW + w > fitLimit)
            {
                if (breakAfter)
                {
                    cursor.SegmentIndex = i + 1;
                    cursor.GraphemeIndex = 0;
                    return lineW;
                }

                if (pendingBreakSegmentIndex >= 0)
                {
                    if (lineEndSegmentIndex > pendingBreakSegmentIndex
                        || (lineEndSegmentIndex == pendingBreakSegmentIndex && lineEndGraphemeIndex > 0))
                    {
                        cursor.SegmentIndex = lineEndSegmentIndex;
                        cursor.GraphemeIndex = lineEndGraphemeIndex;
                        return lineW;
                    }
                    cursor.SegmentIndex = pendingBreakSegmentIndex;
                    cursor.GraphemeIndex = 0;
                    return pendingBreakPaintWidth;
                }

                cursor.SegmentIndex = lineEndSegmentIndex;
                cursor.GraphemeIndex = lineEndGraphemeIndex;
                return lineW;
            }

            lineW += w;
            lineEndSegmentIndex = i + 1;
            lineEndGraphemeIndex = 0;
            if (breakAfter)
            {
                pendingBreakSegmentIndex = i + 1;
                pendingBreakPaintWidth = lineW - w;
            }
        }

        if (!hasContent) return null;
        cursor.SegmentIndex = lineEndSegmentIndex;
        cursor.GraphemeIndex = lineEndGraphemeIndex;
        return lineW;
    }

    internal static double? StepLineGeometryFromChunk(PreparedText prepared, ref LineBreakCursor cursor, int chunkIndex, double maxWidth)
    {
        if (prepared.SimpleLineWalkFastPath) return StepSimpleLineGeometry(prepared, ref cursor, maxWidth);

        return StepChunkLineGeometry(prepared, ref cursor, chunkIndex, maxWidth);
    }

    internal static double? StepLineGeometry(PreparedText prepared, ref LineBreakCursor cursor, double maxWidth)
    {
        int chunkIndex = NormalizeLineStart(prepared, ref cursor);
        if (chunkIndex < 0) return null;
        return StepLineGeometryFromChunk(prepared, ref cursor, chunkIndex, maxWidth);
    }

    internal static LineStats MeasureLineGeometry(PreparedText prepared, double maxWidth)
    {
        if (prepared.Widths.Length == 0) return new LineStats(0, 0);

        LineBreakCursor cursor = new(0, 0);
        int lineCount = 0;
        double maxLineWidth = 0;

        if (!prepared.SimpleLineWalkFastPath)
        {
            int chunkIndex = NormalizeLineStart(prepared, ref cursor);
            while (chunkIndex >= 0)
            {
                double? lineWidth = StepChunkLineGeometry(prepared, ref cursor, chunkIndex, maxWidth);
                if (lineWidth is null) return new LineStats(lineCount, maxLineWidth);
                lineCount++;
                if (lineWidth.Value > maxLineWidth) maxLineWidth = lineWidth.Value;
                chunkIndex = NormalizeLineStartChunkIndexFromHint(prepared, chunkIndex, ref cursor);
            }
            return new LineStats(lineCount, maxLineWidth);
        }

        while (true)
        {
            double? lineWidth = StepLineGeometry(prepared, ref cursor, maxWidth);
            if (lineWidth is null) return new LineStats(lineCount, maxLineWidth);
            lineCount++;
            if (lineWidth.Value > maxLineWidth) maxLineWidth = lineWidth.Value;
        }
    }
}
