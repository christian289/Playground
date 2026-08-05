using System.Windows.Media;
using Pretext.Wpf.Demo.Rendering;

namespace Pretext.Wpf.Demo.Playground.Scenes;

/// <summary>
/// Characters interpolate between the measured layouts of successive phrases,
/// scattering mid-transition with per-character hues.
/// </summary>
internal sealed class TextMorphScene : IAsciiScene
{
    private const double PhaseSeconds = 2.5;

    private static readonly string[] Phrases =
        ["PRETEXT", "準備 + 配置", "MEASURE", "بدون DOM", "LAYOUT", "0.0002ms", "RENDER", "120 FPS"];

    private readonly struct PlacedGlyph
    {
        internal PlacedGlyph(string grapheme, double centerX)
        {
            Grapheme = grapheme;
            CenterX = centerX;
        }

        internal string Grapheme { get; }

        internal double CenterX { get; }
    }

    public string Name => "Text Morph";

    public string Hint => "Characters interpolate between Pretext-measured positions of different phrases";

    public void Init(in SceneFrame frame)
    {
    }

    public void Draw(DrawingContext dc, in SceneFrame frame)
    {
        double w = frame.Width;
        double h = frame.Height;
        double t = frame.Time;

        double cycle = t % (Phrases.Length * PhaseSeconds);
        int fromIndex = (int)(cycle / PhaseSeconds);
        int toIndex = (fromIndex + 1) % Phrases.Length;
        double linear = (cycle % PhaseSeconds) / PhaseSeconds;
        double eased = linear < 0.5
            ? 2 * linear * linear
            : 1 - (Math.Pow((-2 * linear) + 2, 2) / 2);

        double fontSize = Math.Min(80, w * 0.08);
        List<PlacedGlyph> from = PlaceGlyphs(Phrases[fromIndex], fontSize, w);
        List<PlacedGlyph> to = PlaceGlyphs(Phrases[toIndex], fontSize, w);
        int glyphCount = Math.Max(from.Count, to.Count);

        for (int i = 0; i < glyphCount; i++)
        {
            PlacedGlyph source = from[Math.Min(i, from.Count - 1)];
            PlacedGlyph target = to[Math.Min(i, to.Count - 1)];
            bool inSource = i < from.Count;
            bool inTarget = i < to.Count;
            double x = source.CenterX + ((target.CenterX - source.CenterX) * eased);
            double y = h / 2;
            string grapheme = eased < 0.5
                ? (inSource ? source.Grapheme : "")
                : (inTarget ? target.Grapheme : "");
            double alpha = eased < 0.5
                ? (inSource ? 1 - (eased * 2 * 0.5) : 0)
                : (inTarget ? ((eased - 0.5) * 2 * 0.5) + 0.5 : 0);
            if (grapheme.Length == 0)
            {
                continue;
            }

            double scatter = Math.Sin(eased * Math.PI) * 40;
            double offsetY = Math.Sin((t * 5) + (i * 0.8)) * scatter;
            double offsetX = Math.Cos((t * 3) + (i * 1.2)) * scatter * 0.5;
            double rotationRad = Math.Sin(eased * Math.PI) * Math.Sin(i * 2.5) * 0.5;
            double hue = ((double)i / glyphCount * 40) + 15;

            CanvasText.MonoBold.DrawCentered(
                dc, grapheme, x + offsetX, y + offsetY, fontSize,
                CanvasText.Brush(CanvasText.Hsl(hue, 0.8, 0.65, alpha)), rotationRad);
        }

        CanvasText.DrawLabelCentered(
            dc,
            $"{Phrases[fromIndex]}  →  {Phrases[toIndex]}",
            w / 2, (h / 2) + 80, 13,
            CanvasText.Brush(CanvasText.Hex("#888", 0.3)));
    }

    private static List<PlacedGlyph> PlaceGlyphs(string phrase, double fontSize, double surfaceWidth)
    {
        double total = CanvasText.Mono.MeasureRun(phrase, fontSize);
        double penX = (surfaceWidth - total) / 2;
        List<PlacedGlyph> glyphs = [];
        foreach (string grapheme in CanvasText.Graphemes(phrase))
        {
            double glyphAdvance = CanvasText.Mono.Advance(grapheme, fontSize);
            glyphs.Add(new PlacedGlyph(grapheme, penX + (glyphAdvance / 2)));
            penX += glyphAdvance;
        }

        return glyphs;
    }
}
