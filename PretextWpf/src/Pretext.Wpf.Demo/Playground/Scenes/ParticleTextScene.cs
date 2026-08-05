using System.Windows.Media;
using Pretext.Wpf.Demo.Rendering;

namespace Pretext.Wpf.Demo.Playground.Scenes;

/// <summary>
/// Lines are broken by the pretext engine, then every character becomes a
/// mouse-reactive particle springing back to its measured home position. Short
/// ghost trails stand in for the canvas motion-blur overlay of the original.
/// </summary>
internal sealed class ParticleTextScene : IAsciiScene
{
    private const int TrailLength = 3;

    private static readonly Random Rng = new();

    private sealed record SourceLine(string Text, double FontSize, string Color, double YFraction);

    private static readonly SourceLine[] Sources =
    [
        new("@chenglou/pretext", 28, "#ff8844", 0.3),
        new("npm install", 20, "#66dd66", 0.45),
        new("テキスト測定エンジン", 24, "#44aaff", 0.6),
        new("No reflow. Pure math.", 22, "#ddaa44", 0.75),
    ];

    private sealed class Particle
    {
        public double HomeX;
        public double HomeY;
        public double X;
        public double Y;
        public double Vx;
        public double Vy;
        public string Grapheme = "";
        public Color Color;
        public readonly double[] TrailX = new double[TrailLength];
        public readonly double[] TrailY = new double[TrailLength];
    }

    private readonly List<Particle> particles = [];

    public string Name => "Particle Text";

    public string Hint => "Characters are positioned by Pretext, then become mouse-reactive particles";

    public void Init(in SceneFrame frame)
    {
        particles.Clear();
        double w = frame.Width;
        double h = frame.Height;
        if (w <= 0 || h <= 0)
        {
            return;
        }

        foreach (SourceLine source in Sources)
        {
            PreparedTextWithSegments prepared = CanvasText.Prepare(source.Text, source.FontSize);
            LayoutLinesResult layout = TextLayoutEngine.LayoutWithLines(prepared, w - 100, 30);
            Color color = CanvasText.Hex(source.Color);
            foreach (LayoutLine line in layout.Lines)
            {
                double total = CanvasText.Mono.MeasureRun(line.Text, source.FontSize);
                double penX = (w - total) / 2;
                foreach (string grapheme in CanvasText.Graphemes(line.Text))
                {
                    double glyphAdvance = CanvasText.Mono.Advance(grapheme, source.FontSize);
                    if (grapheme != " ")
                    {
                        Particle particle = new()
                        {
                            HomeX = penX + (glyphAdvance / 2),
                            HomeY = h * source.YFraction,
                            X = Rng.NextDouble() * w,
                            Y = Rng.NextDouble() * h,
                            Grapheme = grapheme,
                            Color = color,
                        };
                        for (int i = 0; i < TrailLength; i++)
                        {
                            particle.TrailX[i] = particle.X;
                            particle.TrailY[i] = particle.Y;
                        }

                        particles.Add(particle);
                    }

                    penX += glyphAdvance;
                }
            }
        }
    }

    public void Draw(DrawingContext dc, in SceneFrame frame)
    {
        double dt = frame.Dt;
        foreach (Particle particle in particles)
        {
            double dx = particle.X - frame.Mouse.X;
            double dy = particle.Y - frame.Mouse.Y;
            double distance = Math.Sqrt((dx * dx) + (dy * dy));
            if (!double.IsNaN(distance) && distance < 120 && distance > 1)
            {
                double repel = (1 - (distance / 120)) * 800 * dt;
                particle.Vx += dx / distance * repel;
                particle.Vy += dy / distance * repel;
            }

            particle.Vx += (particle.HomeX - particle.X) * 2 * dt;
            particle.Vy += (particle.HomeY - particle.Y) * 2 * dt;
            particle.Vx *= 0.92;
            particle.Vy *= 0.92;

            for (int i = TrailLength - 1; i > 0; i--)
            {
                particle.TrailX[i] = particle.TrailX[i - 1];
                particle.TrailY[i] = particle.TrailY[i - 1];
            }

            particle.TrailX[0] = particle.X;
            particle.TrailY[0] = particle.Y;
            particle.X += particle.Vx;
            particle.Y += particle.Vy;

            double hx = particle.X - particle.HomeX;
            double hy = particle.Y - particle.HomeY;
            double displacement = Math.Sqrt((hx * hx) + (hy * hy));
            double alpha = Math.Min(0.9, 0.5 + (displacement * 0.005));
            Color color = displacement > 20 ? CanvasText.Hex("#ff6644") : particle.Color;

            if (displacement > 2)
            {
                for (int i = TrailLength - 1; i >= 0; i--)
                {
                    Color ghost = color;
                    ghost.A = CanvasText.ToByte(alpha * 0.18 / (i + 1) * 255);
                    CanvasText.Mono.DrawCentered(
                        dc, particle.Grapheme, particle.TrailX[i], particle.TrailY[i], 22, CanvasText.Brush(ghost));
                }
            }

            color.A = CanvasText.ToByte(alpha * 255);
            CanvasText.Mono.DrawCentered(
                dc, particle.Grapheme, particle.X, particle.Y, 22, CanvasText.Brush(color));
        }
    }
}
