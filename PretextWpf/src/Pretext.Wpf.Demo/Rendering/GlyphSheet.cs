using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace Pretext.Wpf.Demo.Rendering;

/// <summary>
/// Canvas <c>fillText</c>/<c>measureText</c> stand-in for the playground scenes:
/// per-grapheme geometry is built once at a base em size (with system font fallback,
/// so CJK/Arabic/emoji resolve), frozen, and replayed with a per-draw matrix. That
/// keeps the dragon page's ~2000 independently rotated/scaled/tinted letters cheap.
/// </summary>
internal sealed class GlyphSheet
{
    private const double BaseEm = 100;

    private readonly Typeface typeface;
    private readonly Dictionary<string, Entry> entries = new(StringComparer.Ordinal);

    private sealed record Entry(Geometry? Geometry, double Advance, double Width, double Height);

    private static readonly Entry EmptyEntry = new(null, 0, 0, 0);

    internal GlyphSheet(string fontFamily, FontWeight weight)
    {
        typeface = new Typeface(new FontFamily(fontFamily), FontStyles.Normal, weight, FontStretches.Normal);
    }

    /// <summary>Advance width of one grapheme at the given font size (measureText equivalent).</summary>
    internal double Advance(string grapheme, double fontSize)
        => GetEntry(grapheme).Advance * (fontSize / BaseEm);

    /// <summary>Sum of grapheme advances for a run, mirroring the demos' per-char measurement loops.</summary>
    internal double MeasureRun(string text, double fontSize)
    {
        double total = 0;
        foreach (string grapheme in CanvasText.Graphemes(text))
        {
            total += Advance(grapheme, fontSize);
        }

        return total;
    }

    /// <summary>fillText with textAlign=center, textBaseline=middle, plus optional rotation/scale.</summary>
    internal void DrawCentered(
        DrawingContext dc,
        string grapheme,
        double centerX,
        double centerY,
        double fontSize,
        Brush brush,
        double rotationRadians = 0,
        double extraScale = 1)
    {
        Entry entry = GetEntry(grapheme);
        if (entry.Geometry is null)
        {
            return;
        }

        double scale = fontSize / BaseEm * extraScale;
        Matrix matrix = new(scale, 0, 0, scale, -entry.Width * scale / 2, -entry.Height * scale / 2);
        if (rotationRadians != 0)
        {
            matrix.Rotate(rotationRadians * (180 / Math.PI));
        }

        matrix.Translate(centerX, centerY);

        MatrixTransform transform = new(matrix);
        transform.Freeze();
        dc.PushTransform(transform);
        dc.DrawGeometry(brush, null, entry.Geometry);
        dc.Pop();
    }

    /// <summary>fillText with textAlign=left, textBaseline=top. Returns the advance consumed.</summary>
    internal double DrawTopLeft(
        DrawingContext dc,
        string grapheme,
        double x,
        double y,
        double fontSize,
        Brush brush)
    {
        Entry entry = GetEntry(grapheme);
        double scale = fontSize / BaseEm;
        if (entry.Geometry is not null)
        {
            Matrix matrix = new(scale, 0, 0, scale, x, y);
            MatrixTransform transform = new(matrix);
            transform.Freeze();
            dc.PushTransform(transform);
            dc.DrawGeometry(brush, null, entry.Geometry);
            dc.Pop();
        }

        return entry.Advance * scale;
    }

    private Entry GetEntry(string? grapheme)
    {
        grapheme ??= "";
        if (grapheme.Length == 0)
        {
            return EmptyEntry;
        }

        if (entries.TryGetValue(grapheme, out Entry? cached))
        {
            return cached;
        }

        FormattedText formatted = new(
            grapheme,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            typeface,
            BaseEm,
            Brushes.White,
            pixelsPerDip: 1.0);
        Geometry geometry = formatted.BuildGeometry(default);
        geometry.Freeze();

        Entry entry = new(
            geometry.IsEmpty() ? null : geometry,
            formatted.WidthIncludingTrailingWhitespace,
            formatted.WidthIncludingTrailingWhitespace,
            formatted.Height);
        entries[grapheme] = entry;
        return entry;
    }
}
