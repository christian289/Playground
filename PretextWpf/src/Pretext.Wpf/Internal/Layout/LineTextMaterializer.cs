using System.Text;

namespace Pretext.Wpf;

/// <summary>
/// Materializes line text from a prepared segment/grapheme range.
/// Port of upstream <c>line-text.ts</c>; the per-segment grapheme cache lives
/// on the <see cref="PreparedTextWithSegments"/> handle instead of a WeakMap.
/// </summary>
internal static class LineTextMaterializer
{
    internal static string BuildLineText(
        PreparedTextWithSegments prepared,
        int startSegmentIndex,
        int startGraphemeIndex,
        int endSegmentIndex,
        int endGraphemeIndex)
    {
        StringBuilder text = new();
        bool endsWithDiscretionaryHyphen = LineHasDiscretionaryHyphen(
            prepared.Kinds,
            startSegmentIndex,
            endSegmentIndex);

        for (int i = startSegmentIndex; i < endSegmentIndex; i++)
        {
            if (prepared.Kinds[i] is SegmentBreakKind.SoftHyphen or SegmentBreakKind.HardBreak)
            {
                continue;
            }

            if (i == startSegmentIndex && startGraphemeIndex > 0)
            {
                string[] graphemes = GetSegmentGraphemes(prepared, i);
                AppendSegmentGraphemeRange(text, graphemes, startGraphemeIndex, graphemes.Length);
            }
            else
            {
                text.Append(prepared.SegmentArray[i]);
            }
        }

        if (endGraphemeIndex > 0)
        {
            if (endsWithDiscretionaryHyphen)
            {
                text.Append('-');
            }

            string[] graphemes = GetSegmentGraphemes(prepared, endSegmentIndex);
            AppendSegmentGraphemeRange(
                text,
                graphemes,
                startSegmentIndex == endSegmentIndex ? startGraphemeIndex : 0,
                endGraphemeIndex);
        }
        else if (endsWithDiscretionaryHyphen)
        {
            text.Append('-');
        }

        return text.ToString();
    }

    internal static string[] GetSegmentGraphemes(PreparedTextWithSegments prepared, int segmentIndex)
    {
        string[]?[] cache = prepared.SegmentGraphemeCache;
        string[]? graphemes = cache[segmentIndex];
        if (graphemes is null)
        {
            GraphemeMap map = new(prepared.SegmentArray[segmentIndex]);
            graphemes = new string[map.Count];
            for (int i = 0; i < graphemes.Length; i++)
            {
                graphemes[i] = map.GetTextElement(i);
            }

            cache[segmentIndex] = graphemes;
        }

        return graphemes;
    }

    private static bool LineHasDiscretionaryHyphen(
        SegmentBreakKind[] kinds,
        int startSegmentIndex,
        int endSegmentIndex)
    {
        return endSegmentIndex > startSegmentIndex
            && kinds[endSegmentIndex - 1] == SegmentBreakKind.SoftHyphen;
    }

    private static void AppendSegmentGraphemeRange(
        StringBuilder text,
        string[] graphemes,
        int startGraphemeIndex,
        int endGraphemeIndex)
    {
        for (int i = startGraphemeIndex; i < endGraphemeIndex; i++)
        {
            text.Append(graphemes[i]);
        }
    }
}
