using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Pretext.Wpf;

namespace Pretext.Wpf.Demo.Controls;

/// <summary>
/// Renders text laid out by <see cref="TextLayoutEngine"/>: shaping happens once per
/// (text, style) pair in <see cref="MeasureOverride"/>, and every resize afterwards is
/// pure arithmetic over the cached widths. WPF still paints the runs, so the visible
/// result shows exactly where the ported engine chose to break.
/// </summary>
public sealed class PretextTextSurface : Control
{
    public static readonly DependencyProperty TextProperty = DependencyProperty.Register(
        nameof(Text),
        typeof(string),
        typeof(PretextTextSurface),
        new FrameworkPropertyMetadata(
            string.Empty,
            FrameworkPropertyMetadataOptions.AffectsMeasure | FrameworkPropertyMetadataOptions.AffectsRender,
            OnPreparedInputChanged));

    public static readonly DependencyProperty LetterSpacingProperty = DependencyProperty.Register(
        nameof(LetterSpacing),
        typeof(double),
        typeof(PretextTextSurface),
        new FrameworkPropertyMetadata(
            0d,
            FrameworkPropertyMetadataOptions.AffectsMeasure | FrameworkPropertyMetadataOptions.AffectsRender,
            OnPreparedInputChanged));

    public static readonly DependencyProperty LineCountProperty = DependencyProperty.Register(
        nameof(LineCount),
        typeof(int),
        typeof(PretextTextSurface),
        new PropertyMetadata(0));

    private static readonly DependencyProperty[] StyleAffectingProperties =
    [
        FontFamilyProperty,
        FontSizeProperty,
        FontWeightProperty,
        FontStyleProperty,
        FontStretchProperty,
        FlowDirectionProperty,
    ];

    private PreparedTextWithSegments? prepared;
    private TextStyle? preparedStyle;
    private string preparedText = string.Empty;
    private double preparedLetterSpacing;

    static PretextTextSurface()
    {
        foreach (DependencyProperty property in StyleAffectingProperties)
        {
            property.OverrideMetadata(
                typeof(PretextTextSurface),
                new FrameworkPropertyMetadata(
                    property.DefaultMetadata.DefaultValue,
                    FrameworkPropertyMetadataOptions.AffectsMeasure | FrameworkPropertyMetadataOptions.AffectsRender,
                    OnPreparedInputChanged));
        }
    }

    public string Text
    {
        get => (string)GetValue(TextProperty);
        set => SetValue(TextProperty, value);
    }

    public double LetterSpacing
    {
        get => (double)GetValue(LetterSpacingProperty);
        set => SetValue(LetterSpacingProperty, value);
    }

    /// <summary>Lines produced by the most recent measure pass.</summary>
    public int LineCount
    {
        get => (int)GetValue(LineCountProperty);
        private set => SetValue(LineCountProperty, value);
    }

    protected override Size MeasureOverride(Size constraint)
    {
        PreparedTextWithSegments handle = GetPrepared();
        double lineHeight = GetLineHeight();
        double maxWidth = double.IsInfinity(constraint.Width)
            ? TextLayoutEngine.MeasureNaturalWidth(handle)
            : constraint.Width;

        LayoutResult result = TextLayoutEngine.Layout(handle, maxWidth, lineHeight);
        LineCount = result.LineCount;

        LineStats stats = TextLayoutEngine.MeasureLineStats(handle, maxWidth);
        return new Size(Math.Min(stats.MaxLineWidth, maxWidth), result.Height);
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        ArgumentNullException.ThrowIfNull(drawingContext);
        base.OnRender(drawingContext);

        PreparedTextWithSegments handle = GetPrepared();
        TextStyle style = preparedStyle!;
        double lineHeight = GetLineHeight();
        Typeface typeface = new(style.FontFamily, style.FontStyle, style.FontWeight, style.FontStretch);
        Brush brush = Foreground ?? Brushes.Black;
        double y = 0;

        LayoutLinesResult lines = TextLayoutEngine.LayoutWithLines(handle, ActualWidth, lineHeight);
        foreach (LayoutLine line in lines.Lines)
        {
            if (line.Text.Length > 0)
            {
                FormattedText formatted = new(
                    line.Text,
                    style.Culture,
                    style.FlowDirection,
                    typeface,
                    style.FontSize,
                    brush,
                    style.PixelsPerDip);
                drawingContext.DrawText(formatted, new Point(0, y));
            }

            y += lineHeight;
        }
    }

    private static void OnPreparedInputChanged(DependencyObject sender, DependencyPropertyChangedEventArgs args)
    {
        ((PretextTextSurface)sender).prepared = null;
    }

    private PreparedTextWithSegments GetPrepared()
    {
        TextStyle style = CreateStyle();
        if (prepared is not null
            && preparedStyle == style
            && string.Equals(preparedText, Text, StringComparison.Ordinal)
            && preparedLetterSpacing.Equals(LetterSpacing))
        {
            return prepared;
        }

        preparedStyle = style;
        preparedText = Text ?? string.Empty;
        preparedLetterSpacing = LetterSpacing;
        prepared = TextLayoutEngine.PrepareWithSegments(
            preparedText,
            style,
            new PrepareOptions(letterSpacing: preparedLetterSpacing));
        return prepared;
    }

    private TextStyle CreateStyle()
    {
        return new TextStyle(
            FontFamily,
            FontSize,
            FontWeight,
            FontStyle,
            FontStretch,
            CultureInfo.CurrentUICulture,
            FlowDirection,
            VisualTreeHelper.GetDpi(this).PixelsPerDip,
            TextOptions.GetTextFormattingMode(this));
    }

    private double GetLineHeight() => Math.Round(FontFamily.LineSpacing * FontSize, 2);
}
