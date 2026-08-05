using System.Collections.Concurrent;
using System.Globalization;
using System.Text;

namespace Pretext.Wpf;

internal static class TextAnalyzer
{
    private static ConcurrentDictionary<AnalysisKey, Lazy<TextAnalysis>> cache = new();

    internal static TextAnalysis Analyze(
        string text,
        CultureInfo culture,
        WhiteSpaceMode whiteSpaceMode,
        WordBreakMode wordBreakMode)
    {
        ArgumentNullException.ThrowIfNull(text);
        ArgumentNullException.ThrowIfNull(culture);
        Guard.DefinedEnum(whiteSpaceMode, nameof(whiteSpaceMode));
        Guard.DefinedEnum(wordBreakMode, nameof(wordBreakMode));

        CultureInfo immutableCulture = CultureInfo.ReadOnly((CultureInfo)culture.Clone());
        AnalysisKey key = new(text, immutableCulture.Name, whiteSpaceMode, wordBreakMode);
        ConcurrentDictionary<AnalysisKey, Lazy<TextAnalysis>> currentCache = Volatile.Read(ref cache);
        Lazy<TextAnalysis> lazy = currentCache.GetOrAdd(
            key,
            _ => new Lazy<TextAnalysis>(
                () => AnalyzeCore(text, immutableCulture, whiteSpaceMode, wordBreakMode),
                LazyThreadSafetyMode.ExecutionAndPublication));
        return lazy.Value;
    }

    internal static void ClearCache()
    {
        Interlocked.Exchange(ref cache, new ConcurrentDictionary<AnalysisKey, Lazy<TextAnalysis>>());
    }

    private static TextAnalysis AnalyzeCore(
        string text,
        CultureInfo culture,
        WhiteSpaceMode whiteSpaceMode,
        WordBreakMode wordBreakMode)
    {
        string normalized = whiteSpaceMode == WhiteSpaceMode.PreWrap
            ? NormalizeWhitespacePreWrap(text)
            : NormalizeWhitespaceNormal(text);
        if (normalized.Length == 0)
        {
            return TextAnalysis.Create(
                normalized,
                Array.Empty<string>(),
                Array.Empty<bool>(),
                Array.Empty<SegmentBreakKind>(),
                Array.Empty<int>(),
                Array.Empty<NativeWordBreakRun>());
        }

        BaseSegmentation baseSegmentation = WordSegmenter.Segment(normalized, culture, whiteSpaceMode);
        List<AnalysisPiece> pieces = MergeDecimalRuns(baseSegmentation.Pieces);
        pieces = AttachNumericAffixes(pieces);
        pieces = MergeUrlAndSymbolRuns(pieces);
        pieces = MergeArabicMarks(pieces);
        pieces = MergePunctuation(pieces);
        pieces = MergeApostropheElisions(pieces);
        pieces = ApplyCjkKinsoku(pieces);
        if (wordBreakMode == WordBreakMode.KeepAll)
        {
            pieces = MergeKeepAllTextSegments(pieces);
        }

        return BuildMergedSegmentation(normalized, pieces, baseSegmentation.NativeWordBreakRuns);
    }

    private static string NormalizeWhitespaceNormal(string text)
    {
        int firstChange = -1;
        bool previousWasCollapsible = true;
        for (int index = 0; index < text.Length; index++)
        {
            bool collapsible = IsCollapsibleWhitespace(text[index]);
            if (collapsible && (previousWasCollapsible || text[index] != ' '))
            {
                firstChange = index;
                break;
            }

            previousWasCollapsible = collapsible;
        }

        if (firstChange < 0 && (text.Length == 0 || text[^1] != ' '))
        {
            return text;
        }

        StringBuilder builder = new(text.Length);
        bool pendingSpace = false;
        foreach (char character in text)
        {
            if (IsCollapsibleWhitespace(character))
            {
                pendingSpace = builder.Length > 0;
                continue;
            }

            if (pendingSpace)
            {
                builder.Append(' ');
                pendingSpace = false;
            }

            builder.Append(character);
        }

        return builder.ToString();
    }

    private static string NormalizeWhitespacePreWrap(string text)
    {
        if (!text.AsSpan().ContainsAny('\r', '\f'))
        {
            return text;
        }

        StringBuilder builder = new(text.Length);
        for (int index = 0; index < text.Length; index++)
        {
            char character = text[index];
            if (character == '\r')
            {
                if (index + 1 < text.Length && text[index + 1] == '\n')
                {
                    index++;
                }

                builder.Append('\n');
            }
            else if (character == '\f')
            {
                builder.Append('\n');
            }
            else
            {
                builder.Append(character);
            }
        }

        return builder.ToString();
    }

    private static List<AnalysisPiece> MergeDecimalRuns(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        int index = 0;
        while (index < source.Count)
        {
            if (!ContainsDecimalDigit(source[index]))
            {
                result.Add(source[index]);
                index++;
                continue;
            }

            int end = index + 1;
            while (end < source.Count)
            {
                if (ContainsDecimalDigit(source[end]))
                {
                    end++;
                    continue;
                }

                if (IsNumericJoiner(source[end]) && end + 1 < source.Count && ContainsDecimalDigit(source[end + 1]))
                {
                    end += 2;
                    continue;
                }

                break;
            }

            result.Add(MergeRange(source, index, end));
            index = end;
        }

        return result;
    }

    private static List<AnalysisPiece> MergeUrlAndSymbolRuns(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        int index = 0;
        while (index < source.Count)
        {
            if (source[index].Kind != SegmentBreakKind.Text)
            {
                result.Add(source[index]);
                index++;
                continue;
            }

            int end = index + 1;
            while (end < source.Count && source[end].Kind == SegmentBreakKind.Text)
            {
                end++;
            }

            if (end - index > 1 && LooksLikeUrlOrSymbolRun(source, index, end))
            {
                result.Add(MergeRange(source, index, end));
            }
            else
            {
                for (int copy = index; copy < end; copy++)
                {
                    result.Add(source[copy]);
                }
            }

            index = end;
        }

        return result;
    }

    private static List<AnalysisPiece> MergeArabicMarks(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        foreach (AnalysisPiece piece in source)
        {
            if (piece.Kind == SegmentBreakKind.Text && IsMarkOnly(piece.Text) && result.Count > 0
                && result[^1].Kind == SegmentBreakKind.Text)
            {
                AnalysisPiece previous = result[^1];
                result[^1] = MergePair(previous, piece);
            }
            else
            {
                result.Add(piece);
            }
        }

        return result;
    }

    private static List<AnalysisPiece> MergePunctuation(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        int index = 0;
        while (index < source.Count)
        {
            AnalysisPiece piece = source[index];
            if (piece.Kind == SegmentBreakKind.Text && IsClosingPunctuation(piece.Text)
                && result.Count > 0 && result[^1].Kind == SegmentBreakKind.Text)
            {
                result[^1] = MergePair(result[^1], piece);
                index++;
                continue;
            }

            if (piece.Kind == SegmentBreakKind.Text && IsOpeningPunctuation(piece.Text)
                && index + 1 < source.Count && source[index + 1].Kind == SegmentBreakKind.Text)
            {
                result.Add(MergePair(piece, source[index + 1]));
                index += 2;
                continue;
            }

            result.Add(piece);
            index++;
        }

        return result;
    }

    private static List<AnalysisPiece> ApplyCjkKinsoku(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        foreach (AnalysisPiece piece in source)
        {
            if (piece.Kind == SegmentBreakKind.Text
                && (IsClosingPunctuation(piece.Text) || IsKinsokuStartOnly(piece.Text))
                && result.Count > 0 && result[^1].Script is UnicodeScript.Cjk or UnicodeScript.Hangul)
            {
                result[^1] = MergePair(result[^1], piece);
            }
            else
            {
                result.Add(piece);
            }
        }

        return result;
    }

    private static List<AnalysisPiece> MergeKeepAllTextSegments(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        foreach (AnalysisPiece piece in source)
        {
            if (piece.Kind == SegmentBreakKind.Text && result.Count > 0 && result[^1].Kind == SegmentBreakKind.Text)
            {
                result[^1] = MergePair(result[^1], piece);
            }
            else
            {
                result.Add(piece);
            }
        }

        return result;
    }

    private static TextAnalysis BuildMergedSegmentation(
        string normalized,
        List<AnalysisPiece> pieces,
        List<NativeWordBreakRun> nativeRuns)
    {
        string[] texts = new string[pieces.Count];
        bool[] isWordLike = new bool[pieces.Count];
        SegmentBreakKind[] kinds = new SegmentBreakKind[pieces.Count];
        int[] starts = new int[pieces.Count];
        for (int index = 0; index < pieces.Count; index++)
        {
            AnalysisPiece piece = pieces[index];
            texts[index] = piece.Text;
            isWordLike[index] = piece.IsWordLike;
            kinds[index] = piece.Kind;
            starts[index] = piece.Start;
        }

        return TextAnalysis.Create(normalized, texts, isWordLike, kinds, starts, nativeRuns.ToArray());
    }

    private static AnalysisPiece MergeRange(List<AnalysisPiece> source, int start, int end)
    {
        AnalysisPiece merged = source[start];
        for (int index = start + 1; index < end; index++)
        {
            merged = MergePair(merged, source[index]);
        }

        return merged;
    }

    private static AnalysisPiece MergePair(AnalysisPiece left, AnalysisPiece right)
    {
        UnicodeScript script = left.Script == UnicodeScript.Common ? right.Script : left.Script;
        return new AnalysisPiece(
            string.Concat(left.Text, right.Text),
            left.IsWordLike || right.IsWordLike,
            SegmentBreakKind.Text,
            left.Start,
            script);
    }

    private static bool LooksLikeUrlOrSymbolRun(List<AnalysisPiece> source, int start, int end)
    {
        StringBuilder builder = new();
        for (int index = start; index < end; index++)
        {
            builder.Append(source[index].Text);
        }

        string candidate = builder.ToString();
        return candidate.Contains("://", StringComparison.Ordinal)
            || candidate.StartsWith("www.", StringComparison.OrdinalIgnoreCase)
            || candidate.Contains('@', StringComparison.Ordinal)
            || candidate.StartsWith('#')
            || candidate.Contains('/', StringComparison.Ordinal);
    }

    private static bool ContainsDecimalDigit(AnalysisPiece piece)
    {
        if (piece.Kind != SegmentBreakKind.Text)
        {
            return false;
        }

        foreach (Rune rune in piece.Text.EnumerateRunes())
        {
            if (UnicodeClassifier.IsDecimalDigit(rune))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsNumericJoiner(AnalysisPiece piece)
    {
        if (piece.Kind != SegmentBreakKind.Text || piece.Text.Length != 1)
        {
            return false;
        }

        // Ordinary ASCII joiners plus the Arabic decimal/thousands separators and
        // the dash/times forms upstream treats as numeric-internal.
        return piece.Text[0] is '.' or ',' or ':' or '/' or '+' or '-' or '%' or '$'
            or '\u00D7' or '\u066B' or '\u066C' or '\u2013' or '\u2014';
    }

    /// <summary>
    /// Binds currency/percent affixes to the numeric run they belong to, so
    /// "$42.99" and "158.50₪" stay single break units instead of letting the
    /// symbol wrap away from its digits.
    /// </summary>
    private static List<AnalysisPiece> AttachNumericAffixes(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        for (int index = 0; index < source.Count; index++)
        {
            AnalysisPiece piece = source[index];
            if (!IsNumericAffixOnly(piece))
            {
                result.Add(piece);
                continue;
            }

            if (index + 1 < source.Count && StartsWithDecimalDigit(source[index + 1]))
            {
                result.Add(MergePair(piece, source[index + 1]));
                index++;
                continue;
            }

            if (result.Count > 0 && EndsWithDecimalDigit(result[^1]))
            {
                result[^1] = MergePair(result[^1], piece);
                continue;
            }

            result.Add(piece);
        }

        return result;
    }

    /// <summary>
    /// Re-joins apostrophe elisions ("can't", "l'homme"). Punctuation merging
    /// attaches the apostrophe to the left word, which would otherwise leave the
    /// tail letters as their own break opportunity (UAX #29 WB6/WB7).
    /// </summary>
    private static List<AnalysisPiece> MergeApostropheElisions(List<AnalysisPiece> source)
    {
        List<AnalysisPiece> result = new(source.Count);
        for (int index = 0; index < source.Count; index++)
        {
            AnalysisPiece piece = source[index];

            // "can’t": the curly apostrophe already merged left as closing
            // punctuation, leaving the tail letters stranded.
            if (piece.Kind == SegmentBreakKind.Text
                && result.Count > 0
                && EndsWithIntraWordApostrophe(result[^1])
                && StartsWithLetter(piece))
            {
                result[^1] = MergePair(result[^1], piece);
                continue;
            }

            // "can't": the straight apostrophe is Po, so it stands alone between
            // two letter runs and would otherwise be its own break opportunity.
            if (IsApostropheOnly(piece)
                && result.Count > 0
                && EndsWithLetter(result[^1])
                && index + 1 < source.Count
                && StartsWithLetter(source[index + 1])
                && source[index + 1].Kind == SegmentBreakKind.Text)
            {
                result[^1] = MergePair(MergePair(result[^1], piece), source[index + 1]);
                index++;
                continue;
            }

            result.Add(piece);
        }

        return result;
    }

    private static bool IsApostropheOnly(AnalysisPiece piece)
    {
        return piece.Kind == SegmentBreakKind.Text
            && piece.Text.Length == 1
            && piece.Text[0] is '\'' or '\u2019';
    }

    private static bool EndsWithLetter(AnalysisPiece piece)
    {
        if (piece.Kind != SegmentBreakKind.Text || piece.Text.Length == 0)
        {
            return false;
        }

        Rune last = default;
        foreach (Rune rune in piece.Text.EnumerateRunes())
        {
            last = rune;
        }

        return UnicodeClassifier.IsWordLike(last);
    }

    private static bool IsKinsokuStartOnly(string text)
    {
        bool sawRune = false;
        foreach (Rune rune in text.EnumerateRunes())
        {
            sawRune = true;
            if (!UnicodeClassifier.IsKinsokuStart(rune))
            {
                return false;
            }
        }

        return sawRune;
    }

    private static bool IsNumericAffixOnly(AnalysisPiece piece)
    {
        if (piece.Kind != SegmentBreakKind.Text)
        {
            return false;
        }

        bool sawRune = false;
        foreach (Rune rune in piece.Text.EnumerateRunes())
        {
            sawRune = true;
            if (!UnicodeClassifier.IsLineBreakNumericAffix(rune))
            {
                return false;
            }
        }

        return sawRune;
    }

    private static bool StartsWithDecimalDigit(AnalysisPiece piece)
    {
        return piece.Kind == SegmentBreakKind.Text
            && piece.Text.Length > 0
            && UnicodeClassifier.IsDecimalDigit(Rune.GetRuneAt(piece.Text, 0));
    }

    private static bool EndsWithDecimalDigit(AnalysisPiece piece)
    {
        if (piece.Kind != SegmentBreakKind.Text || piece.Text.Length == 0)
        {
            return false;
        }

        Rune last = default;
        foreach (Rune rune in piece.Text.EnumerateRunes())
        {
            last = rune;
        }

        return UnicodeClassifier.IsDecimalDigit(last);
    }

    private static bool StartsWithLetter(AnalysisPiece piece)
    {
        return piece.Text.Length > 0 && UnicodeClassifier.IsWordLike(Rune.GetRuneAt(piece.Text, 0));
    }

    private static bool EndsWithIntraWordApostrophe(AnalysisPiece piece)
    {
        if (piece.Kind != SegmentBreakKind.Text || piece.Text.Length < 2)
        {
            return false;
        }

        Rune last = default;
        Rune previous = default;
        foreach (Rune rune in piece.Text.EnumerateRunes())
        {
            previous = last;
            last = rune;
        }

        return last.Value is '\'' or '\u2019' && UnicodeClassifier.IsWordLike(previous);
    }

    private static bool IsMarkOnly(string text)
    {
        bool found = false;
        foreach (Rune rune in text.EnumerateRunes())
        {
            found = true;
            if (!UnicodeClassifier.IsMark(rune))
            {
                return false;
            }
        }

        return found;
    }

    private static bool IsOpeningPunctuation(string text)
    {
        Rune rune = Rune.GetRuneAt(text, 0);
        return UnicodeClassifier.IsOpeningPunctuation(rune);
    }

    private static bool IsClosingPunctuation(string text)
    {
        Rune rune = Rune.GetRuneAt(text, 0);
        return UnicodeClassifier.IsClosingPunctuation(rune);
    }

    private static bool IsCollapsibleWhitespace(char character) =>
        character is ' ' or '\t' or '\n' or '\r' or '\f';

    private readonly record struct AnalysisKey(
        string Text,
        string CultureName,
        WhiteSpaceMode WhiteSpaceMode,
        WordBreakMode WordBreakMode);
}
