using System.Windows.Controls;

namespace Pretext.Wpf.Demo.Views;

/// <summary>
/// The original smoke surface, now one tab of the playground shell: type or resize
/// and watch the ported engine relayout from cached measurements.
/// </summary>
public partial class LayoutLabView : UserControl
{
    private const string SampleText =
        "Just tried the new update and it's so much better. The performance improvements " +
        "are really noticeable, especially on older devices.\n\n" +
        "Hello مرحبا שלום 你好 こんにちは 안녕하세요 สวัสดี — a greeting in seven scripts! " +
        "The price is $42.99 (approximately ٤٢٫٩٩ ريال or ₪158.50) including tax. " +
        "Superlongwordwithoutanyspacesthatshouldjustoverflowthelineandkeepgoing";

    public LayoutLabView()
    {
        InitializeComponent();
        SourceText.Text = SampleText;
    }
}
