namespace Pretext.Wpf;

/// <summary>
/// Measures shaped advance widths for prepared-text segments.
/// The production implementation wraps the WPF text formatter; tests inject
/// deterministic fakes so layout behavior stays font-independent.
/// </summary>
internal interface ISegmentMeasurer
{
    /// <summary>
    /// Returns the shaped advance width of <paramref name="segment"/> in
    /// device-independent pixels. Implementations cache by segment text.
    /// </summary>
    double MeasureSegment(string segment);

    /// <summary>
    /// Returns UTF-16 offsets inside <paramref name="run"/> where the platform's
    /// dictionary line breaker allows a break, for scripts without visible word
    /// spacing (Thai, Lao, Khmer, Myanmar). Offsets are strictly increasing and
    /// exclude 0 and the run length.
    /// <para>
    /// Returns <see langword="null"/> when the implementation has no dictionary,
    /// in which case such runs stay a single break unit and only overflow-break at
    /// grapheme boundaries.
    /// </para>
    /// </summary>
    int[]? GetNativeBreakOffsets(string run) => null;
}
