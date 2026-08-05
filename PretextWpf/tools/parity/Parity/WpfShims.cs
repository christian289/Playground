// Minimal stand-ins for the handful of WPF types the core's public surface mentions,
// so the platform-independent sources compile and run on any OS. Only genuinely
// device-dependent files (the formatter-backed measurer and its text source) are
// excluded from the build and stubbed below.
namespace System.Windows
{
    public enum FlowDirection
    {
        LeftToRight = 0,
        RightToLeft = 1,
    }

    public readonly record struct FontWeight(int Value);

    public readonly record struct FontStyle(int Value);

    public readonly record struct FontStretch(int Value);

    public static class FontWeights
    {
        public static FontWeight Thin => new(100);

        public static FontWeight Normal => new(400);

        public static FontWeight Bold => new(700);
    }

    public static class FontStyles
    {
        public static FontStyle Normal => new(0);

        public static FontStyle Italic => new(1);

        public static FontStyle Oblique => new(2);
    }

    public static class FontStretches
    {
        public static FontStretch Condensed => new(3);

        public static FontStretch Normal => new(5);

        public static FontStretch Expanded => new(7);
    }
}

namespace System.Windows.Media
{
    public sealed class FontFamily : IEquatable<FontFamily>
    {
        public FontFamily(string familyName)
        {
            ArgumentNullException.ThrowIfNull(familyName);
            Source = familyName;
        }

        public string Source { get; }

        public bool Equals(FontFamily? other) => other is not null && Source == other.Source;

        public override bool Equals(object? obj) => Equals(obj as FontFamily);

        public override int GetHashCode() => Source.GetHashCode(StringComparison.Ordinal);
    }

    public enum TextFormattingMode
    {
        Ideal = 0,
        Display = 1,
    }
}

namespace Pretext.Wpf
{
    /// <summary>
    /// Stub for the formatter-backed measurer. The offline runner always injects a
    /// deterministic measurer through the internal seams, so the real WPF path is
    /// never reached here.
    /// </summary>
    internal sealed class WpfTextMeasurer : ISegmentMeasurer
    {
        internal static WpfTextMeasurer GetOrCreate(TextStyle style) =>
            throw new PlatformNotSupportedException(
                "The offline parity runner cannot use WPF text measurement; inject a measurer instead.");

        public double MeasureSegment(string segment) =>
            throw new PlatformNotSupportedException(
                "The offline parity runner cannot use WPF text measurement; inject a measurer instead.");

        internal static void ClearCaches()
        {
        }
    }
}
