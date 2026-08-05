using System.Globalization;

namespace Pretext.Wpf;

internal readonly record struct NativeWordBreakRun
{
    public NativeWordBreakRun(int start, int length, CultureInfo culture)
    {
        ArgumentNullException.ThrowIfNull(culture);
        ArgumentOutOfRangeException.ThrowIfNegative(start);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(length);

        Start = start;
        Length = length;
        Culture = CultureInfo.ReadOnly((CultureInfo)culture.Clone());
    }

    public int Start { get; }

    public int Length { get; }

    public CultureInfo Culture { get; }
}

internal sealed class TextAnalysis
{
    private TextAnalysis(
        string normalized,
        string[] texts,
        bool[] isWordLike,
        SegmentBreakKind[] kinds,
        int[] starts,
        NativeWordBreakRun[] nativeWordBreakRuns)
    {
        Normalized = normalized;
        Texts = texts;
        IsWordLike = isWordLike;
        Kinds = kinds;
        Starts = starts;
        NativeWordBreakRuns = nativeWordBreakRuns;
    }

    public string Normalized { get; }

    public string[] Texts { get; }

    public bool[] IsWordLike { get; }

    public SegmentBreakKind[] Kinds { get; }

    public int[] Starts { get; }

    public NativeWordBreakRun[] NativeWordBreakRuns { get; }

    public int Length => Texts.Length;

    internal static TextAnalysis Create(
        string normalized,
        string[] texts,
        bool[] isWordLike,
        SegmentBreakKind[] kinds,
        int[] starts,
        NativeWordBreakRun[] nativeWordBreakRuns)
    {
        ArgumentNullException.ThrowIfNull(normalized);
        ArgumentNullException.ThrowIfNull(texts);
        ArgumentNullException.ThrowIfNull(isWordLike);
        ArgumentNullException.ThrowIfNull(kinds);
        ArgumentNullException.ThrowIfNull(starts);
        ArgumentNullException.ThrowIfNull(nativeWordBreakRuns);

        if (texts.Length != isWordLike.Length || texts.Length != kinds.Length || texts.Length != starts.Length)
        {
            throw new ArgumentException("Parallel segment arrays must have the same length.", nameof(texts));
        }

        int expectedStart = 0;
        for (int index = 0; index < texts.Length; index++)
        {
            string text = texts[index] ?? throw new ArgumentException("Segment text cannot be null.", nameof(texts));
            if (starts[index] != expectedStart || !normalized.AsSpan(expectedStart).StartsWith(text, StringComparison.Ordinal))
            {
                throw new ArgumentException("Segment starts and text must form a contiguous view of normalized text.", nameof(starts));
            }

            expectedStart += text.Length;
        }

        if (expectedStart != normalized.Length)
        {
            throw new ArgumentException("Segments must cover all normalized text.", nameof(texts));
        }

        foreach (NativeWordBreakRun run in nativeWordBreakRuns)
        {
            if (run.Start < 0 || run.Length <= 0 || run.Culture is null || run.Start > normalized.Length - run.Length)
            {
                throw new ArgumentOutOfRangeException(nameof(nativeWordBreakRuns), "Native word-break run exceeds normalized text.");
            }
        }

        return new TextAnalysis(
            normalized,
            (string[])texts.Clone(),
            (bool[])isWordLike.Clone(),
            (SegmentBreakKind[])kinds.Clone(),
            (int[])starts.Clone(),
            (NativeWordBreakRun[])nativeWordBreakRuns.Clone());
    }
}
