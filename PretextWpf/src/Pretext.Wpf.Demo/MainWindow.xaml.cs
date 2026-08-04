using System.Windows;

namespace Pretext.Wpf.Demo;

/// <summary>
/// Smoke surface for the ported layout engine: type or resize and watch the engine
/// relayout from cached measurements. The demo gallery (accordion, bubbles, masonry,
/// editorial, markdown chat…) is a separate milestone; this window exists so the
/// library can be exercised interactively on Windows today.
/// </summary>
public partial class MainWindow : Window
{
    private const string SampleText =
        "Just tried the new update and it's so much better. The performance improvements " +
        "are really noticeable, especially on older devices.\n\n" +
        "Hello مرحبا שלום 你好 こんにちは 안녕하세요 สวัสดี — a greeting in seven scripts! " +
        "The price is $42.99 (approximately ٤٢٫٩٩ ريال or ₪158.50) including tax. " +
        "Superlongwordwithoutanyspacesthatshouldjustoverflowthelineandkeepgoing";

    public MainWindow()
    {
        InitializeComponent();
        SourceText.Text = SampleText;
    }
}
