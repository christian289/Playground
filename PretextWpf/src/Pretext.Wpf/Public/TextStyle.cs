using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace Pretext.Wpf;

public sealed record TextStyle
{
    public TextStyle(
        FontFamily fontFamily,
        double fontSize,
        FontWeight fontWeight,
        FontStyle fontStyle,
        FontStretch fontStretch,
        CultureInfo culture,
        FlowDirection flowDirection,
        double pixelsPerDip,
        TextFormattingMode formattingMode)
    {
        ArgumentNullException.ThrowIfNull(fontFamily);
        ArgumentNullException.ThrowIfNull(culture);

        FontFamily = fontFamily;
        FontSize = Guard.PositiveFinite(fontSize, nameof(fontSize));
        FontWeight = fontWeight;
        FontStyle = fontStyle;
        FontStretch = fontStretch;
        Culture = CultureInfo.ReadOnly((CultureInfo)culture.Clone());
        FlowDirection = Guard.DefinedEnum(flowDirection, nameof(flowDirection));
        PixelsPerDip = Guard.PositiveFinite(pixelsPerDip, nameof(pixelsPerDip));
        FormattingMode = Guard.DefinedEnum(formattingMode, nameof(formattingMode));
    }

    public FontFamily FontFamily { get; }

    public double FontSize { get; }

    public FontWeight FontWeight { get; }

    public FontStyle FontStyle { get; }

    public FontStretch FontStretch { get; }

    public CultureInfo Culture { get; }

    public FlowDirection FlowDirection { get; }

    public double PixelsPerDip { get; }

    public TextFormattingMode FormattingMode { get; }
}
