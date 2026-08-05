using System.Globalization;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.TextFormatting;

namespace Pretext.Wpf;

/// <summary>
/// <see cref="TextRunProperties"/> built once from a <see cref="TextStyle"/> and reused across
/// every <see cref="TextFormatter.FormatLine(TextSource, int, double, TextParagraphProperties, TextLineBreak)"/>
/// call for that style. Measurement-only: foreground is a fixed opaque brush and there are no
/// decorations, effects, or background paint. Adapted from the WPF-Samples PerMonitorDPI sample's
/// GenericTextRunProperties (provenance tracked outside this file; no license header is added).
/// </summary>
internal sealed class PretextTextRunProperties : TextRunProperties
{
    private readonly Typeface typeface;
    private readonly double fontSize;
    private readonly CultureInfo culture;

    public PretextTextRunProperties(TextStyle style)
    {
        ArgumentNullException.ThrowIfNull(style);

        typeface = new Typeface(style.FontFamily, style.FontStyle, style.FontWeight, style.FontStretch);
        fontSize = style.FontSize;
        culture = style.Culture;

        // Concrete, non-virtual property on the base class; there is no override to write.
        PixelsPerDip = style.PixelsPerDip;
    }

    public override Typeface Typeface => typeface;

    public override double FontRenderingEmSize => fontSize;

    public override double FontHintingEmSize => fontSize;

    public override TextDecorationCollection? TextDecorations => null;

    public override Brush ForegroundBrush => Brushes.Black;

    public override Brush? BackgroundBrush => null;

    public override CultureInfo CultureInfo => culture;

    public override TextEffectCollection? TextEffects => null;
}

/// <summary>
/// <see cref="TextParagraphProperties"/> for single-line, unwrapped advance-width measurement.
/// Adapted from the WPF-Samples PerMonitorDPI sample's GenericTextParagraphProperties.
/// </summary>
internal sealed class PretextTextParagraphProperties : TextParagraphProperties
{
    private readonly FlowDirection flowDirection;
    private readonly TextRunProperties defaultTextRunProperties;
    private readonly TextWrapping textWrapping;

    public PretextTextParagraphProperties(
        FlowDirection flowDirection,
        TextRunProperties defaultTextRunProperties,
        TextWrapping textWrapping = TextWrapping.NoWrap)
    {
        ArgumentNullException.ThrowIfNull(defaultTextRunProperties);

        this.flowDirection = flowDirection;
        this.defaultTextRunProperties = defaultTextRunProperties;
        this.textWrapping = textWrapping;
    }

    public override FlowDirection FlowDirection => flowDirection;

    public override TextAlignment TextAlignment => TextAlignment.Left;

    public override double LineHeight => 0;

    public override bool FirstLineInParagraph => true;

    public override bool AlwaysCollapsible => false;

    public override TextRunProperties DefaultTextRunProperties => defaultTextRunProperties;

    public override TextWrapping TextWrapping => textWrapping;

    public override TextMarkerProperties? TextMarkerProperties => null;

    public override double Indent => 0;

    // DefaultIncrementalTab, ParagraphIndent, TextDecorations, and Tabs are left at the base
    // class's virtual defaults (4em incremental tab, 0 paragraph indent, no decorations, no
    // tab stops) — all sane for single-segment measurement.
}
