using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Parity;

/// <summary>
/// Deterministic measurer mirroring the fake canvas backend upstream pretext uses in
/// its own suite (<c>src/layout.test.ts</c>). Both sides of the differential therefore
/// measure identically, so any divergence is a line-breaking difference, not a font one.
/// </summary>
internal sealed class CanvasParityMeasurer : ISegmentMeasurer
{
    private static readonly char[] PunctuationChars =
        ['.', ',', '!', '?', ';', ':', '%', ')', ']', '}', '\'', '"', '\u201D', '\u2019', '\u00BB', '\u203A', '\u2026', '\u2014', '-'];

    private static readonly Dictionary<string, int[]> NativeWordDictionary = LoadNativeWordDictionary();

    private readonly double fontSize;
    private readonly Dictionary<string, double> widths = new(StringComparer.Ordinal);

    public CanvasParityMeasurer(double fontSize)
    {
        this.fontSize = fontSize;
    }

    public double MeasureSegment(string segment)
    {
        if (widths.TryGetValue(segment, out double cached))
        {
            return cached;
        }

        double width = 0;
        bool previousWasDecimalDigit = false;
        foreach (Rune rune in segment.EnumerateRunes())
        {
            if (rune.Value == ' ')
            {
                width += fontSize * 0.33;
                previousWasDecimalDigit = false;
            }
            else if (rune.Value == '\t')
            {
                width += fontSize * 1.32;
                previousWasDecimalDigit = false;
            }
            else if (rune.Value is >= 0x1F300 and <= 0x1FAFF or 0xFE0F)
            {
                width += fontSize;
                previousWasDecimalDigit = false;
            }
            else if (Rune.GetUnicodeCategory(rune) == UnicodeCategory.DecimalDigitNumber)
            {
                width += fontSize * (previousWasDecimalDigit ? 0.48 : 0.52);
                previousWasDecimalDigit = true;
            }
            else if (IsWideCharacter(rune.Value))
            {
                width += fontSize;
                previousWasDecimalDigit = false;
            }
            else if (rune.Value <= 0xFFFF && Array.IndexOf(PunctuationChars, (char)rune.Value) >= 0)
            {
                width += fontSize * 0.4;
                previousWasDecimalDigit = false;
            }
            else
            {
                width += fontSize * 0.6;
                previousWasDecimalDigit = false;
            }
        }

        widths[segment] = width;
        return width;
    }

    /// <summary>
    /// Stands in for WPF's line-breaking dictionary using the ICU boundaries captured
    /// alongside the corpus, so scriptio-continua runs (Thai) split the same way on
    /// both sides without needing the real formatter.
    /// </summary>
    public int[]? GetNativeBreakOffsets(string run)
    {
        return NativeWordDictionary.TryGetValue(run, out int[]? offsets) && offsets.Length > 0
            ? offsets
            : null;
    }

    private static Dictionary<string, int[]> LoadNativeWordDictionary()
    {
        return JsonSerializer.Deserialize<Dictionary<string, int[]>>(
            File.ReadAllText(TestDataPaths.Resolve("native-word-dictionary.json")))!;
    }

    private static bool IsWideCharacter(int code)
    {
        return (code >= 0x4E00 && code <= 0x9FFF)
            || (code >= 0x3400 && code <= 0x4DBF)
            || (code >= 0xF900 && code <= 0xFAFF)
            || (code >= 0x2F800 && code <= 0x2FA1F)
            || (code >= 0x20000 && code <= 0x2A6DF)
            || (code >= 0x2A700 && code <= 0x2B73F)
            || (code >= 0x2B740 && code <= 0x2B81F)
            || (code >= 0x2B820 && code <= 0x2CEAF)
            || (code >= 0x2CEB0 && code <= 0x2EBEF)
            || (code >= 0x2EBF0 && code <= 0x2EE5D)
            || (code >= 0x30000 && code <= 0x3134F)
            || (code >= 0x31350 && code <= 0x323AF)
            || (code >= 0x323B0 && code <= 0x33479)
            || (code >= 0x3000 && code <= 0x303F)
            || (code >= 0x3040 && code <= 0x309F)
            || (code >= 0x30A0 && code <= 0x30FF)
            || (code >= 0x3130 && code <= 0x318F)
            || (code >= 0xAC00 && code <= 0xD7AF)
            || (code >= 0xFF00 && code <= 0xFFEF);
    }
}

/// <summary>
/// Locates committed test fixtures. The test assembly copies TestData next to itself;
/// the offline parity runner executes from a different output directory, so fall back
/// to walking up to the repository copy.
/// </summary>
internal static class TestDataPaths
{
    internal static string Resolve(string fileName)
    {
        string local = Path.Combine(AppContext.BaseDirectory, "TestData", fileName);
        if (File.Exists(local))
        {
            return local;
        }

        DirectoryInfo? directory = new(AppContext.BaseDirectory);
        while (directory is not null)
        {
            string candidate = Path.Combine(
                directory.FullName,
                "tests",
                "Pretext.Wpf.Tests",
                "TestData",
                fileName);
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException($"Test fixture '{fileName}' was not found.", fileName);
    }
}
