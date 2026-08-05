using System.Windows.Media;
using Pretext.Wpf.Demo.Rendering;

namespace Pretext.Wpf.Demo.Playground.Scenes;

/// <summary>
/// Five multilingual lines positioned from per-grapheme measured advances, displaced
/// by a sine wave, pulsing in scale, and lifting toward the pointer.
/// </summary>
internal sealed class TextWaveScene : IAsciiScene
{
    private sealed record WaveLine(string Text, double FontSize, string Color, double YFraction);

    private static readonly WaveLine[] Lines =
    [
        new("The quick brown fox jumps over the lazy dog", 24, "#ff8844", 0.2),
        new("春天到了 — テキストレイアウトの革命が始まる", 22, "#44aaff", 0.35),
        new("prepare() measures, layout() computes, you render", 20, "#66dd66", 0.5),
        new("بدأت الرحلة الكبرى في عالم النص 🚀✨🎨", 20, "#ddaa44", 0.65),
        new("0.0002ms per layout — 500x faster than DOM", 22, "#ff66aa", 0.8),
    ];

    public string Name => "Text Wave";

    public string Hint => "Each character positioned using Pretext-measured widths, then displaced by a sine wave";

    public void Init(in SceneFrame frame)
    {
    }

    public void Draw(DrawingContext dc, in SceneFrame frame)
    {
        double w = frame.Width;
        double h = frame.Height;
        double t = frame.Time;

        foreach (WaveLine line in Lines)
        {
            double y = h * line.YFraction;
            double total = CanvasText.Mono.MeasureRun(line.Text, line.FontSize);
            double penX = (w - total) / 2;
            Color baseColor = CanvasText.Hex(line.Color);

            int i = 0;
            foreach (string grapheme in CanvasText.Graphemes(line.Text))
            {
                double glyphAdvance = CanvasText.Mono.Advance(grapheme, line.FontSize);
                double wave = Math.Sin((t * 3) + (penX * 0.015) + (i * 0.1)) * 25;
                double pulse = 1 + (Math.Sin((t * 2) + (i * 0.2)) * 0.15);
                double dx = penX + (glyphAdvance / 2) - frame.Mouse.X;
                double dy = y + wave - frame.Mouse.Y;
                double distance = Math.Sqrt((dx * dx) + (dy * dy));
                double near = double.IsNaN(distance) ? 0 : Math.Max(0, 1 - (distance / 150));
                double lift = near * -30;
                double glow = near * 0.4;

                Color color = baseColor;
                color.A = CanvasText.ToByte(Math.Clamp(0.6 + glow, 0, 1) * 255);
                CanvasText.Mono.DrawCentered(
                    dc, grapheme,
                    penX + (glyphAdvance / 2),
                    y + wave + lift,
                    line.FontSize,
                    CanvasText.Brush(color),
                    Math.Sin((t * 4) + (i * 0.15)) * 0.05,
                    pulse + (near * 0.3));

                penX += glyphAdvance;
                i++;
            }
        }
    }
}
