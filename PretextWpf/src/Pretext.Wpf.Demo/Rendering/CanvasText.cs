using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace Pretext.Wpf.Demo.Rendering;

/// <summary>
/// Shared drawing/measuring services for the playground scenes: the canvas-equivalent
/// glyph sheets, a whole-string <see cref="FormattedText"/> cache for labels, a frozen
/// brush cache, and the pretext prepare helper that mirrors the upstream demos'
/// <c>prepare(text, "Npx Courier New")</c> calls against the ported engine.
/// </summary>
internal static class CanvasText
{
    private const int BrushCacheCap = 8192;
    private const int LabelCacheCap = 512;

    private static readonly FontFamily MonoFamily = new("Courier New");
    private static readonly Dictionary<Color, SolidColorBrush> Brushes = [];
    private static readonly Dictionary<(string Text, double Size, bool Bold, bool Ui), FormattedText> Labels = [];
    private static readonly Typeface MonoTypeface = new(MonoFamily, FontStyles.Normal, FontWeights.Normal, FontStretches.Normal);
    private static readonly Typeface MonoBoldTypeface = new(MonoFamily, FontStyles.Normal, FontWeights.Bold, FontStretches.Normal);
    private static readonly Typeface UiTypeface = new(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.Normal, FontStretches.Normal);
    private static readonly Typeface UiSemiBoldTypeface = new(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.SemiBold, FontStretches.Normal);

    internal static GlyphSheet Mono { get; } = new("Courier New", FontWeights.Normal);

    internal static GlyphSheet MonoBold { get; } = new("Courier New", FontWeights.Bold);

    /// <summary>prepare(text, "{size}px Courier New", options?) against the ported engine.</summary>
    internal static PreparedTextWithSegments Prepare(string text, double fontSize, bool preWrap = false)
    {
        TextStyle style = new(
            MonoFamily,
            fontSize,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            pixelsPerDip: 1.0,
            TextFormattingMode.Ideal);
        PrepareOptions options = new(whiteSpace: preWrap ? WhiteSpaceMode.PreWrap : WhiteSpaceMode.Normal);
        return TextLayoutEngine.PrepareWithSegments(text, style, options);
    }

    /// <summary>Grapheme clusters of a string (the demos iterate characters this way).</summary>
    internal static IEnumerable<string> Graphemes(string text)
    {
        TextElementEnumerator enumerator = StringInfo.GetTextElementEnumerator(text);
        while (enumerator.MoveNext())
        {
            yield return (string)enumerator.Current;
        }
    }

    internal static SolidColorBrush Brush(Color color)
    {
        if (Brushes.TryGetValue(color, out SolidColorBrush? cached))
        {
            return cached;
        }

        if (Brushes.Count >= BrushCacheCap)
        {
            Brushes.Clear();
        }

        SolidColorBrush brush = new(color);
        brush.Freeze();
        Brushes[color] = brush;
        return brush;
    }

    internal static SolidColorBrush Brush(byte r, byte g, byte b, double alpha = 1)
        => Brush(Color.FromArgb(ToByte(alpha * 255), r, g, b));

    /// <summary>rgb() component helper: clamps a double into the 0-255 byte range.</summary>
    internal static byte ToByte(double value)
        => (byte)Math.Clamp(value, 0, 255);

    /// <summary>Parses #rgb / #rrggbb hex colors used verbatim from the upstream bundle.</summary>
    internal static Color Hex(string hex, double alpha = 1)
    {
        string digits = hex[1..];
        if (digits.Length == 3)
        {
            digits = string.Concat(
                digits[0], digits[0], digits[1], digits[1], digits[2], digits[2]);
        }

        byte r = byte.Parse(digits[..2], NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        byte g = byte.Parse(digits[2..4], NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        byte b = byte.Parse(digits[4..6], NumberStyles.HexNumber, CultureInfo.InvariantCulture);
        return Color.FromArgb(ToByte(alpha * 255), r, g, b);
    }

    /// <summary>hsl() equivalent for the morph scene's per-character hues.</summary>
    internal static Color Hsl(double hueDegrees, double saturation, double lightness, double alpha = 1)
    {
        double h = ((hueDegrees % 360) + 360) % 360 / 60;
        double c = (1 - Math.Abs((2 * lightness) - 1)) * saturation;
        double x = c * (1 - Math.Abs((h % 2) - 1));
        (double r, double g, double b) = ((int)h) switch
        {
            0 => (c, x, 0d),
            1 => (x, c, 0d),
            2 => (0d, c, x),
            3 => (0d, x, c),
            4 => (x, 0d, c),
            _ => (c, 0d, x),
        };
        double m = lightness - (c / 2);
        return Color.FromArgb(
            ToByte(alpha * 255),
            ToByte((r + m) * 255),
            ToByte((g + m) * 255),
            ToByte((b + m) * 255));
    }

    /// <summary>Cached whole-string label (stats lines, tunnel phrases, score display).</summary>
    internal static FormattedText Label(string text, double size, bool bold = false, bool ui = false)
    {
        (string, double, bool, bool) key = (text, size, bold, ui);
        if (Labels.TryGetValue(key, out FormattedText? cached))
        {
            return cached;
        }

        if (Labels.Count >= LabelCacheCap)
        {
            Labels.Clear();
        }

        Typeface typeface = ui
            ? (bold ? UiSemiBoldTypeface : UiTypeface)
            : (bold ? MonoBoldTypeface : MonoTypeface);
        FormattedText formatted = new(
            text,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            typeface,
            size,
            System.Windows.Media.Brushes.White,
            pixelsPerDip: 1.0);
        Labels[key] = formatted;
        return formatted;
    }

    internal static void DrawLabelCentered(DrawingContext dc, string text, double centerX, double centerY, double size, Brush brush, bool bold = false, bool ui = false)
    {
        FormattedText label = Label(text, size, bold, ui);
        label.SetForegroundBrush(brush);
        dc.DrawText(label, new Point(centerX - (label.WidthIncludingTrailingWhitespace / 2), centerY - (label.Height / 2)));
    }

    internal static void DrawLabelTopLeft(DrawingContext dc, string text, double x, double y, double size, Brush brush, bool bold = false, bool ui = false)
    {
        FormattedText label = Label(text, size, bold, ui);
        label.SetForegroundBrush(brush);
        dc.DrawText(label, new Point(x, y));
    }
}
