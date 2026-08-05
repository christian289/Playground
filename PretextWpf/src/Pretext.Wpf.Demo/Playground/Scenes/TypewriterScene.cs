using System.Globalization;
using System.Windows;
using System.Windows.Media;
using Pretext.Wpf.Demo.Rendering;

namespace Pretext.Wpf.Demo.Playground.Scenes;

/// <summary>
/// The pretext engine re-breaks lines every frame while text is "typed", with a
/// blinking caret, per-line highlights, live layout stats, and the shrinkwrap width
/// measured through <see cref="TextLayoutEngine.WalkLineRanges"/>.
/// </summary>
internal sealed class TypewriterScene : IAsciiScene
{
    private const string FullText =
        "In the age of AI, text layout was the last and biggest bottleneck for unlocking much more " +
        "interesting UIs. Pretext solves this with pure TypeScript — canvas-based measurement, pure " +
        "arithmetic layout. 春天到了. بدأت الرحلة 🚀 No longer do we have to choose between flashy WebGL " +
        "and practical blog articles. prepare() once, layout() on every resize. ~0.0002ms per call. " +
        "CJK, Arabic, emoji, bidi — all handled. npm install @chenglou/pretext";

    private const double FontSize = 16;
    private const double LineHeight = 24;
    private const int CycleUnits = 493;
    private const int HoldUnits = 433;

    private static readonly Pen ShrinkwrapPen = BuildShrinkwrapPen();

    public string Name => "Typewriter";

    public string Hint => "Pretext computes line breaks in real-time as characters are \"typed\" — watch the lines reflow";

    public void Init(in SceneFrame frame)
    {
    }

    public void Draw(DrawingContext dc, in SceneFrame frame)
    {
        double w = frame.Width;
        double h = frame.Height;
        double t = frame.Time;

        int typed = (int)(t * 30 % CycleUnits);
        int visibleUnits = Math.Min(Math.Min(typed, HoldUnits), FullText.Length);
        if (visibleUnits > 0
            && char.IsHighSurrogate(FullText[visibleUnits - 1]))
        {
            visibleUnits++;
        }

        string text = FullText[..visibleUnits];
        double maxWidth = Math.Min(600, w - 100);
        double x = (w - maxWidth) / 2;
        double yTop = h * 0.15;

        PreparedTextWithSegments prepared = CanvasText.Prepare(text, FontSize);
        LayoutLinesResult layout = TextLayoutEngine.LayoutWithLines(prepared, maxWidth, LineHeight);

        Brush highlight = CanvasText.Brush(CanvasText.Hex("#ff8844", 0.06));
        int consumed = 0;
        for (int lineIndex = 0; lineIndex < layout.Lines.Count; lineIndex++)
        {
            LayoutLine line = layout.Lines[lineIndex];
            double lineY = yTop + (lineIndex * LineHeight);
            double penX = x;
            int column = 0;
            foreach (string grapheme in CanvasText.Graphemes(line.Text))
            {
                int sinceTyped = typed - column - consumed;
                bool fresh = sinceTyped >= 0 && sinceTyped < 3;
                double jitter = fresh ? Math.Sin(t * 20) * 2 : 0;
                Brush ink = CanvasText.Brush(fresh
                    ? Color.FromArgb(204, 255, 255, 255)
                    : Color.FromArgb(204, 204, 204, 204));
                penX += CanvasText.Mono.DrawTopLeft(dc, grapheme, penX, lineY + jitter, FontSize, ink);
                column++;
            }

            consumed += column;
            dc.DrawRectangle(highlight, null, new Rect(x, lineY, Math.Max(line.Width, 0), LineHeight));
        }

        if (visibleUnits < HoldUnits && Math.Sin(t * 6) > 0)
        {
            double caretX = x + (layout.Lines.Count > 0 ? layout.Lines[^1].Width : 0);
            double caretY = yTop + (Math.Max(layout.Lines.Count, 1) - 1) * LineHeight;
            dc.DrawRectangle(CanvasText.Brush(CanvasText.Hex("#ff8844")), null, new Rect(caretX + 2, caretY, 2, 20));
        }

        string stats = string.Create(
            CultureInfo.InvariantCulture,
            $"{text.Length} chars | {layout.LineCount} lines | height: {layout.Height:0.##}px | max-width: {maxWidth:0}px");
        CanvasText.DrawLabelTopLeft(
            dc, stats, x, yTop + layout.Height + 20, 11,
            CanvasText.Brush(CanvasText.Hex("#888", 0.35)));

        double shrinkwrap = 0;
        TextLayoutEngine.WalkLineRanges(prepared, maxWidth, (in LayoutLineRange line) =>
        {
            if (line.Width > shrinkwrap)
            {
                shrinkwrap = line.Width;
            }
        });

        dc.DrawRectangle(
            null, ShrinkwrapPen,
            new Rect(x - 1, yTop - 1, Math.Max(shrinkwrap + 2, 0), Math.Max(layout.Height + 2, 0)));
        CanvasText.DrawLabelTopLeft(
            dc,
            string.Create(CultureInfo.InvariantCulture, $"shrinkwrap: {Math.Round(shrinkwrap)}px"),
            x, yTop + layout.Height + 40, 10,
            CanvasText.Brush(CanvasText.Hex("#ff8844", 0.25)));
    }

    private static Pen BuildShrinkwrapPen()
    {
        Pen pen = new(CanvasText.Brush(CanvasText.Hex("#ff8844", 0.15)), 1)
        {
            DashStyle = new DashStyle([4, 4], 0),
        };
        pen.Freeze();
        return pen;
    }
}
