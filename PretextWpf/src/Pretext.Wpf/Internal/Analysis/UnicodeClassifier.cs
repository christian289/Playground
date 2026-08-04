using System.Globalization;
using System.Text;

namespace Pretext.Wpf;

internal enum UnicodeScript
{
    Common,
    Latin,
    Greek,
    Cyrillic,
    Arabic,
    Hebrew,
    Devanagari,
    Thai,
    Lao,
    Khmer,
    Myanmar,
    Cjk,
    Hangul,
    Other,
}

internal static class UnicodeClassifier
{
    private static readonly (int Start, int End)[] CjkRanges =
    {
        (0x3000, 0x30FF),
        (0x3130, 0x318F),
        (0x3400, 0x4DBF),
        (0x4E00, 0x9FFF),
        (0xF900, 0xFAFF),
        (0xFF00, 0xFFEF),
        (0x20000, 0x2A6DF),
        (0x2A700, 0x2B73F),
        (0x2B740, 0x2B81F),
        (0x2B820, 0x2CEAF),
        (0x2CEB0, 0x2EBEF),
        (0x2EBF0, 0x2EE5D),
        (0x2F800, 0x2FA1F),
        (0x30000, 0x3134F),
        (0x31350, 0x323AF),
        (0x323B0, 0x33479),
    };

    private static readonly (int Start, int End)[] HangulRanges =
    {
        (0x1100, 0x11FF),
        (0x3130, 0x318F),
        (0xA960, 0xA97F),
        (0xAC00, 0xD7AF),
        (0xD7B0, 0xD7FF),
    };

    private static readonly (int Start, int End)[] EmojiRanges =
    {
        (0x20E3, 0x20E3),
        (0x2600, 0x27BF),
        (0xFE0E, 0xFE0F),
        (0x1F000, 0x1FAFF),
    };

    internal static bool IsCjk(Rune rune) => IsInRanges(rune.Value, CjkRanges);

    internal static bool IsHangul(Rune rune) => IsInRanges(rune.Value, HangulRanges);

    internal static bool IsOpeningPunctuation(Rune rune)
    {
        UnicodeCategory category = Rune.GetUnicodeCategory(rune);
        return category is UnicodeCategory.OpenPunctuation or UnicodeCategory.InitialQuotePunctuation;
    }

    internal static bool IsClosingPunctuation(Rune rune)
    {
        UnicodeCategory category = Rune.GetUnicodeCategory(rune);
        return category is UnicodeCategory.ClosePunctuation or UnicodeCategory.FinalQuotePunctuation
            || rune.Value is ',' or '.' or '!' or '?' or ':' or ';' or '%'
            || rune.Value is 0x3001 or 0x3002 or 0x30FB or 0x2026;
    }

    internal static bool IsDashOrConnector(Rune rune)
    {
        UnicodeCategory category = Rune.GetUnicodeCategory(rune);
        return category is UnicodeCategory.DashPunctuation or UnicodeCategory.ConnectorPunctuation;
    }

    internal static bool IsWordLike(Rune rune)
    {
        UnicodeCategory category = Rune.GetUnicodeCategory(rune);
        return category is
            UnicodeCategory.UppercaseLetter or
            UnicodeCategory.LowercaseLetter or
            UnicodeCategory.TitlecaseLetter or
            UnicodeCategory.ModifierLetter or
            UnicodeCategory.OtherLetter or
            UnicodeCategory.DecimalDigitNumber or
            UnicodeCategory.LetterNumber or
            UnicodeCategory.OtherNumber or
            UnicodeCategory.NonSpacingMark or
            UnicodeCategory.SpacingCombiningMark or
            UnicodeCategory.EnclosingMark or
            UnicodeCategory.ConnectorPunctuation;
    }

    internal static bool IsDecimalDigit(Rune rune) =>
        Rune.GetUnicodeCategory(rune) == UnicodeCategory.DecimalDigitNumber;

    internal static bool IsMark(Rune rune)
    {
        UnicodeCategory category = Rune.GetUnicodeCategory(rune);
        return category is UnicodeCategory.NonSpacingMark or UnicodeCategory.SpacingCombiningMark or UnicodeCategory.EnclosingMark;
    }

    internal static bool IsEmojiCandidate(Rune rune) => IsInRanges(rune.Value, EmojiRanges);

    internal static bool IsNativeWordBreakScript(UnicodeScript script) =>
        script is UnicodeScript.Thai or UnicodeScript.Lao or UnicodeScript.Khmer or UnicodeScript.Myanmar;

    internal static UnicodeScript GetScript(Rune rune)
    {
        int value = rune.Value;
        if (IsHangul(rune))
        {
            return UnicodeScript.Hangul;
        }

        if (IsCjk(rune))
        {
            return UnicodeScript.Cjk;
        }

        if (In(value, 0x0041, 0x024F) || In(value, 0x1E00, 0x1EFF))
        {
            return UnicodeScript.Latin;
        }

        if (In(value, 0x0370, 0x03FF) || In(value, 0x1F00, 0x1FFF))
        {
            return UnicodeScript.Greek;
        }

        if (In(value, 0x0400, 0x052F) || In(value, 0x2DE0, 0x2DFF) || In(value, 0xA640, 0xA69F))
        {
            return UnicodeScript.Cyrillic;
        }

        if (In(value, 0x0590, 0x05FF) || In(value, 0xFB1D, 0xFB4F))
        {
            return UnicodeScript.Hebrew;
        }

        if (In(value, 0x0600, 0x06FF) || In(value, 0x0750, 0x077F) || In(value, 0x08A0, 0x08FF)
            || In(value, 0xFB50, 0xFDFF) || In(value, 0xFE70, 0xFEFF))
        {
            return UnicodeScript.Arabic;
        }

        if (In(value, 0x0900, 0x097F))
        {
            return UnicodeScript.Devanagari;
        }

        if (In(value, 0x0E00, 0x0E7F))
        {
            return UnicodeScript.Thai;
        }

        if (In(value, 0x0E80, 0x0EFF))
        {
            return UnicodeScript.Lao;
        }

        if (In(value, 0x1000, 0x109F) || In(value, 0xA9E0, 0xA9FF) || In(value, 0xAA60, 0xAA7F))
        {
            return UnicodeScript.Myanmar;
        }

        if (In(value, 0x1780, 0x17FF))
        {
            return UnicodeScript.Khmer;
        }

        UnicodeCategory category = Rune.GetUnicodeCategory(rune);
        return category is UnicodeCategory.SpaceSeparator or UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator
            or UnicodeCategory.Control or UnicodeCategory.Format or UnicodeCategory.OtherPunctuation
            or UnicodeCategory.MathSymbol or UnicodeCategory.CurrencySymbol or UnicodeCategory.ModifierSymbol
            or UnicodeCategory.OtherSymbol
            ? UnicodeScript.Common
            : UnicodeScript.Other;
    }

    private static bool IsInRanges(int value, (int Start, int End)[] ranges)
    {
        int low = 0;
        int high = ranges.Length - 1;
        while (low <= high)
        {
            int middle = low + ((high - low) / 2);
            (int start, int end) = ranges[middle];
            if (value < start)
            {
                high = middle - 1;
            }
            else if (value > end)
            {
                low = middle + 1;
            }
            else
            {
                return true;
            }
        }

        return false;
    }

    private static bool In(int value, int start, int end) => value >= start && value <= end;
}
