using System.Windows.Media;
using Pretext.Wpf.Demo.Rendering;

namespace Pretext.Wpf.Demo.Playground.Scenes;

/// <summary>
/// Deterministic matrix rain: every column/glyph derives from a column seed and the
/// clock, while the center overlay is laid out by the pretext engine each frame.
/// </summary>
internal sealed class MatrixRainScene : IAsciiScene
{
    private static readonly string[] Charset =
    [
        .. CanvasText.Graphemes(
            "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン" +
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" +
            "春夏秋冬龍鳳虎亀" +
            "بدأتالرحلة" +
            "@#$%^&*(){}[]|/<>~"),
    ];

    public string Name => "Matrix Rain";

    public string Hint => "Pretext measures every glyph width — CJK, Arabic, emoji all fall at correct spacing";

    public void Init(in SceneFrame frame)
    {
    }

    public void Draw(DrawingContext dc, in SceneFrame frame)
    {
        double w = frame.Width;
        double h = frame.Height;
        double t = frame.Time;
        int columns = (int)Math.Ceiling(w / 18);

        for (int column = 0; column < columns; column++)
        {
            int seed = column * 7919;
            double head = (((t * (40 + (seed % 60))) + (seed % 500)) % (h + 300)) - 100;
            int trail = 8 + (seed % 20);
            for (int i = 0; i < trail; i++)
            {
                double y = head - (i * 18);
                if (y < -20 || y > h + 20)
                {
                    continue;
                }

                string glyph = Charset[(seed + (i * 31) + (int)(t * 2)) % Charset.Length];
                double brightness = i == 0 ? 1 : Math.Max(0, 1 - ((double)i / trail));
                Color color = i == 0
                    ? Colors.White
                    : Color.FromRgb(
                        CanvasText.ToByte(brightness * 80),
                        CanvasText.ToByte(brightness * 255),
                        CanvasText.ToByte(brightness * 80));
                color.A = CanvasText.ToByte(brightness * 0.8 * 255);
                CanvasText.Mono.DrawCentered(dc, glyph, (column * 18) + 9, y, 15, CanvasText.Brush(color));
            }
        }

        PreparedTextWithSegments prepared = CanvasText.Prepare("PURE TEXT MEASUREMENT", 36);
        LayoutLinesResult layout = TextLayoutEngine.LayoutWithLines(prepared, w - 100, 44);
        double alpha = 0.15 + (Math.Sin(t * 2) * 0.05);
        Brush overlay = CanvasText.Brush(CanvasText.Hex("#00ff00", alpha));
        foreach (LayoutLine line in layout.Lines)
        {
            CanvasText.DrawLabelCentered(dc, line.Text, w / 2, h / 2, 36, overlay);
        }
    }
}
