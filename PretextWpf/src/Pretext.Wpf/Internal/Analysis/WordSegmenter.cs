using System.Globalization;
using System.Text;

namespace Pretext.Wpf;

internal readonly record struct AnalysisPiece(
    string Text,
    bool IsWordLike,
    SegmentBreakKind Kind,
    int Start,
    UnicodeScript Script);

internal sealed record BaseSegmentation(
    List<AnalysisPiece> Pieces,
    List<NativeWordBreakRun> NativeWordBreakRuns);

internal static class WordSegmenter
{
    internal static BaseSegmentation Segment(
        string normalized,
        CultureInfo culture,
        WhiteSpaceMode whiteSpaceMode)
    {
        GraphemeMap graphemes = new(normalized);
        List<AnalysisPiece> pieces = new(graphemes.Count);
        List<NativeWordBreakRun> nativeRuns = new();

        int index = 0;
        while (index < graphemes.Count)
        {
            int start = graphemes.Starts[index];
            string textElement = graphemes.GetTextElement(index);
            SegmentBreakKind breakKind = ClassifyBreakKind(textElement, whiteSpaceMode);
            if (breakKind != SegmentBreakKind.Text)
            {
                pieces.Add(new AnalysisPiece(textElement, false, breakKind, start, UnicodeScript.Common));
                index++;
                continue;
            }

            Rune firstRune = Rune.GetRuneAt(textElement, 0);
            UnicodeScript script = UnicodeClassifier.GetScript(firstRune);
            bool isWordLike = ContainsWordLikeRune(textElement);

            if (UnicodeClassifier.IsNativeWordBreakScript(script) && isWordLike)
            {
                int endIndex = index + 1;
                while (endIndex < graphemes.Count)
                {
                    string candidate = graphemes.GetTextElement(endIndex);
                    if (ClassifyBreakKind(candidate, whiteSpaceMode) != SegmentBreakKind.Text)
                    {
                        break;
                    }

                    Rune candidateRune = Rune.GetRuneAt(candidate, 0);
                    if (UnicodeClassifier.GetScript(candidateRune) != script || !ContainsWordLikeRune(candidate))
                    {
                        break;
                    }

                    endIndex++;
                }

                int end = endIndex < graphemes.Count ? graphemes.Starts[endIndex] : normalized.Length;
                string runText = normalized[start..end];
                pieces.Add(new AnalysisPiece(runText, true, SegmentBreakKind.Text, start, script));
                nativeRuns.Add(new NativeWordBreakRun(start, end - start, culture));
                index = endIndex;
                continue;
            }

            if (isWordLike && script is not UnicodeScript.Cjk and not UnicodeScript.Hangul)
            {
                int endIndex = index + 1;
                while (endIndex < graphemes.Count)
                {
                    string candidate = graphemes.GetTextElement(endIndex);
                    if (ClassifyBreakKind(candidate, whiteSpaceMode) != SegmentBreakKind.Text)
                    {
                        break;
                    }

                    Rune candidateRune = Rune.GetRuneAt(candidate, 0);
                    UnicodeScript candidateScript = UnicodeClassifier.GetScript(candidateRune);
                    if (!ContainsWordLikeRune(candidate)
                        || (candidateScript != script && candidateScript != UnicodeScript.Common))
                    {
                        break;
                    }

                    endIndex++;
                }

                int end = endIndex < graphemes.Count ? graphemes.Starts[endIndex] : normalized.Length;
                pieces.Add(new AnalysisPiece(normalized[start..end], true, SegmentBreakKind.Text, start, script));
                index = endIndex;
                continue;
            }

            pieces.Add(new AnalysisPiece(textElement, isWordLike, SegmentBreakKind.Text, start, script));
            index++;
        }

        return new BaseSegmentation(pieces, nativeRuns);
    }

    private static SegmentBreakKind ClassifyBreakKind(string textElement, WhiteSpaceMode whiteSpaceMode)
    {
        if (textElement.Length != 1)
        {
            return SegmentBreakKind.Text;
        }

        return textElement[0] switch
        {
            ' ' when whiteSpaceMode == WhiteSpaceMode.PreWrap => SegmentBreakKind.PreservedSpace,
            ' ' => SegmentBreakKind.Space,
            '\t' when whiteSpaceMode == WhiteSpaceMode.PreWrap => SegmentBreakKind.Tab,
            '\n' when whiteSpaceMode == WhiteSpaceMode.PreWrap => SegmentBreakKind.HardBreak,
            '\u00A0' or '\u202F' or '\u2060' or '\uFEFF' => SegmentBreakKind.Glue,
            '\u200B' => SegmentBreakKind.ZeroWidthBreak,
            '\u00AD' => SegmentBreakKind.SoftHyphen,
            _ => SegmentBreakKind.Text,
        };
    }

    private static bool ContainsWordLikeRune(string textElement)
    {
        foreach (Rune rune in textElement.EnumerateRunes())
        {
            if (UnicodeClassifier.IsWordLike(rune))
            {
                return true;
            }
        }

        return false;
    }
}
