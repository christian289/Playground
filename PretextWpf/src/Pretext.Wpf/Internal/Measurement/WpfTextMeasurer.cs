using System.Collections.Concurrent;
using System.Threading;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.TextFormatting;

namespace Pretext.Wpf;

/// <summary>
/// WPF replacement for upstream's canvas <c>measureText</c> (measurement.ts). Shapes each segment
/// with <see cref="TextFormatter"/> and returns the advance width in DIPs. Unlike the canvas
/// backend there is no engine-profile emoji correction to apply — WPF measures with the real
/// renderer, so the corrected width upstream computes collapses to the plain shaped width here.
/// </summary>
internal sealed class WpfTextMeasurer : ISegmentMeasurer
{
    // WPF rejects a paragraphWidth of PositiveInfinity outright and caps finite values at
    // MS.Internal.TextFormatting.Constants.RealInfiniteWidth (IdealInfiniteWidth * DefaultIdealToReal
    // ≈ 3,579,139.4 DIPs; see TextFormatterImp.VerifyTextFormattingArguments). A large-but-finite
    // width, combined with TextWrapping.NoWrap on PretextTextParagraphProperties, reproduces
    // upstream's unwrapped single-line measurement without tripping that guard.
    private const double UnwrappedLineWidth = 1_000_000d;

    // Formatting a scriptio-continua run at a near-zero width with WrapWithOverflow makes WPF
    // emit exactly one dictionary word per line (it overflows rather than splitting a word),
    // which is how the dictionary break offsets are recovered.
    private const double MinimumWrapWidth = 0.01d;

    private static ConcurrentDictionary<MeasurerKey, WpfTextMeasurer> cache = new();

    private readonly TextFormatter formatter;
    private readonly TextRunProperties runProperties;
    private readonly TextParagraphProperties paragraphProperties;
    private readonly TextParagraphProperties wrappingParagraphProperties;
    private readonly ConcurrentDictionary<string, double> segmentWidths = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, int[]?> nativeBreakOffsets = new(StringComparer.Ordinal);
    private readonly object formatterLock = new();

    private WpfTextMeasurer(TextStyle style)
    {
        runProperties = new PretextTextRunProperties(style);
        paragraphProperties = new PretextTextParagraphProperties(style.FlowDirection, runProperties);
        wrappingParagraphProperties = new PretextTextParagraphProperties(
            style.FlowDirection,
            runProperties,
            TextWrapping.WrapWithOverflow);
        formatter = TextFormatter.Create(style.FormattingMode);
    }

    /// <summary>
    /// Returns the process-wide cached measurer for <paramref name="style"/>, keyed by style
    /// value (not reference identity) so two equal styles share one <see cref="TextFormatter"/>.
    /// </summary>
    internal static WpfTextMeasurer GetOrCreate(TextStyle style)
    {
        ArgumentNullException.ThrowIfNull(style);

        MeasurerKey key = new(
            style.FontFamily.Source,
            style.FontSize,
            style.FontWeight,
            style.FontStyle,
            style.FontStretch,
            style.Culture.Name,
            style.FlowDirection,
            style.PixelsPerDip,
            style.FormattingMode);

        ConcurrentDictionary<MeasurerKey, WpfTextMeasurer> currentCache = Volatile.Read(ref cache);
        return currentCache.GetOrAdd(key, _ => new WpfTextMeasurer(style));
    }

    /// <summary>
    /// Measures the shaped advance width of <paramref name="segment"/> in DIPs. Must be called on
    /// an STA thread: WPF's <see cref="TextFormatter"/> is not usable from an MTA thread.
    /// </summary>
    public double MeasureSegment(string segment)
    {
        ArgumentNullException.ThrowIfNull(segment);
        EnsureStaThread();

        if (segment.Length == 0)
        {
            return 0d;
        }

        return segmentWidths.GetOrAdd(segment, MeasureUncached);
    }

    /// <summary>
    /// Discovers WPF's own dictionary line-break opportunities inside a scriptio-continua run
    /// (Thai, Lao, Khmer, Myanmar). WPF ships the line-breaking dictionary that
    /// <see cref="System.Globalization"/> does not expose, so the run is formatted at a
    /// deliberately tiny paragraph width with <see cref="TextWrapping.WrapWithOverflow"/>:
    /// each returned line is exactly one dictionary word (overflow instead of splitting one),
    /// and the cumulative lengths are the break offsets.
    /// <para>
    /// Prepare-time only and cached per run, so the layout hot path never pays for it.
    /// </para>
    /// </summary>
    public int[]? GetNativeBreakOffsets(string run)
    {
        ArgumentNullException.ThrowIfNull(run);
        EnsureStaThread();

        if (run.Length < 2)
        {
            return null;
        }

        return nativeBreakOffsets.GetOrAdd(run, ProbeNativeBreakOffsets);
    }

    internal static void ClearCaches()
    {
        Interlocked.Exchange(ref cache, new ConcurrentDictionary<MeasurerKey, WpfTextMeasurer>());
    }

    private double MeasureUncached(string segment)
    {
        // TextFormatter instances are not thread-safe; only the cache-miss path touches the
        // formatter, so cache hits never contend on this lock.
        lock (formatterLock)
        {
            PlainTextSource source = new(segment, runProperties);
            using TextLine line = formatter.FormatLine(source, 0, UnwrappedLineWidth, paragraphProperties, null);
            return line.WidthIncludingTrailingWhitespace;
        }
    }

    private int[]? ProbeNativeBreakOffsets(string run)
    {
        List<int>? offsets = null;
        lock (formatterLock)
        {
            PlainTextSource source = new(run, runProperties);
            int offset = 0;
            while (offset < run.Length)
            {
                using TextLine line = formatter.FormatLine(
                    source,
                    offset,
                    MinimumWrapWidth,
                    wrappingParagraphProperties,
                    null);
                int length = line.Length;
                if (length <= 0)
                {
                    // Defensive: a non-advancing formatter result would spin forever.
                    return null;
                }

                offset += length;
                if (offset < run.Length)
                {
                    offsets ??= new List<int>();
                    offsets.Add(offset);
                }
            }
        }

        return offsets?.ToArray();
    }

    private static void EnsureStaThread()
    {
        if (Thread.CurrentThread.GetApartmentState() != ApartmentState.STA)
        {
            throw new InvalidOperationException(
                "WpfTextMeasurer.MeasureSegment must run on an STA thread: WPF's TextFormatter " +
                "relies on apartment-threaded text shaping and is not safe to call from an MTA thread.");
        }
    }

    private readonly record struct MeasurerKey(
        string FontFamilySource,
        double FontSize,
        FontWeight FontWeight,
        FontStyle FontStyle,
        FontStretch FontStretch,
        string CultureName,
        FlowDirection FlowDirection,
        double PixelsPerDip,
        TextFormattingMode FormattingMode);
}
