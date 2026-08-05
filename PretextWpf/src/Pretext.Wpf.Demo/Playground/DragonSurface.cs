using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using Pretext.Wpf.Demo.Rendering;

namespace Pretext.Wpf.Demo.Playground;

/// <summary>
/// Port of the playground's dragon scene (`dragon-JNptzR-R.js`): a typographic page
/// laid out by the pretext engine whose every character is a physics particle, plus
/// an ASCII dragon that follows the mouse, breathes fire on click-and-hold, enemies,
/// floating runes, a perspective text tunnel, and a drawn crosshair cursor.
/// </summary>
internal sealed class DragonSurface : AnimatedSurface
{
    private const int LetterCapacity = 2000;
    private const int EmberCapacity = 60;
    private const int FireCapacity = 150;
    private const double SegmentSpacing = 10;

    private static readonly Random Rng = new();

    // -- page text (verbatim from the upstream bundle) ------------------------------

    private enum ColumnKind
    {
        Left,
        Right,
        Center,
    }

    private sealed record BlockSpec(
        string Text,
        double FontSize,
        string Color,
        double Alpha,
        double YOffset,
        double MaxWidth,
        double LineHeight,
        bool PreWrap,
        ColumnKind Column);

    private static readonly BlockSpec[] Blocks =
    [
        new("PRETEXT", 120, "#222", 0.5, -20, 1200, 130, false, ColumnKind.Center),
        new("HERE BE DRAGONS", 54, "#f0f0f0", 1, 100, 900, 64, false, ColumnKind.Left),
        new(
            "Text measurement without DOM reflow — pure arithmetic, pure fire",
            18, "#999", 0.75, 175, 700, 26, false, ColumnKind.Left),
        new(
            "In the age of AI, text layout was the last and biggest bottleneck for unlocking much more " +
            "interesting UIs. No longer do we have to choose between the flashiness of a WebGL landing page " +
            "versus the practicality of a blog article. The engine is tiny, aware of browser quirks, and " +
            "supports every language you will ever need.",
            14, "#bbb", 0.65, 225, 500, 21, false, ColumnKind.Left),
        new(
            "春天到了 — 龍が目を覚ます。بدأت الرحلة الكبرى 🐉🔥 prepare() once, layout() forever. 每一个文字都是一个粒子。",
            16, "#ee9944", 0.8, 460, 520, 24, false, ColumnKind.Left),
        new(
            "import { prepare, layout } from '@chenglou/pretext'\n" +
            "const prepared = prepare(text, '16px Inter')\n" +
            "const { height } = layout(prepared, width, 20)\n" +
            "// ~0.0002ms per layout call. Pure math.",
            13, "#77cc77", 0.6, 550, 520, 18, true, ColumnKind.Left),
        new(
            "\"Fast, accurate and comprehensive userland text measurement algorithm in pure TypeScript, " +
            "usable for laying out entire web pages without CSS\"",
            14, "#cc9966", 0.65, 120, 380, 21, false, ColumnKind.Right),
        new(
            "Shrinkwrapped chat bubbles. Responsive magazine layouts. Variable font width ASCII art. " +
            "Canvas, SVG, WebGL — render anywhere. 120fps masonry with 100k items.",
            13, "#bbb", 0.6, 310, 380, 19, false, ColumnKind.Right),
        new(
            "✦ CJK per-character breaking\n✦ Arabic/Hebrew bidi\n✦ Emoji correction\n" +
            "✦ Soft hyphens & tab stops\n✦ overflow-wrap: break-word\n✦ Grapheme-level breaking",
            12, "#ff9955", 0.55, 470, 350, 17, true, ColumnKind.Right),
        new(
            "The serpent coils through canvas. Each scale a character. Each breath a particle. " +
            "The text scatters and reforms.",
            15, "#998877", 0.5, 680, 800, 22, false, ColumnKind.Center),
    ];

    private static readonly string[] BodyChars =
        [.. CanvasText.Graphemes("◆◆◇▼█▓▓▒╬╬╬╬╬╬╬╬╬╬╫╫╫╪╪╪╧╧╤╤╥╥║║││┃┃╎╎╏╏::····..")];

    private static readonly string[] FireChars = [.. CanvasText.Graphemes("*✦✧⁕❋✺◌•∘˚⋆·")];

    private static readonly string[] EmberChars = ["·", "•", "∘", "˚"];

    private static readonly Color[] EmberColors =
        [CanvasText.Hex("#ff6600"), CanvasText.Hex("#ffaa00"), CanvasText.Hex("#ff4400")];

    private static readonly string[] RuneChars = [.. CanvasText.Graphemes("龍火竜鱗焔ᚱᚦᛏ")];

    private static readonly string[] TunnelTexts =
    [
        "PRETEXT — pure text measurement",
        "春天到了 — テキストレイアウト革命",
        "prepare() → layout() → render",
        "بدأت الرحلة · Начало пути · 시작",
        "No DOM. No reflow. Pure math.",
        "CJK · Bidi · Emoji · Graphemes",
    ];

    private static readonly (string Char, string Color, int Hp, double Size, double Speed)[] EnemyKinds =
    [
        ("◈", "#ff4466", 1, 22, 1),
        ("⬢", "#ff6688", 3, 28, 0.5),
        ("◇", "#44ddff", 1, 16, 2.2),
        ("◌", "#aa88ff", 2, 20, 0.8),
    ];

    // -- letters (structure-of-arrays, capped like upstream) ------------------------

    private readonly double[] homeX = new double[LetterCapacity];
    private readonly double[] homeY = new double[LetterCapacity];
    private readonly double[] posX = new double[LetterCapacity];
    private readonly double[] posY = new double[LetterCapacity];
    private readonly double[] velX = new double[LetterCapacity];
    private readonly double[] velY = new double[LetterCapacity];
    private readonly double[] rotation = new double[LetterCapacity];
    private readonly double[] rotationVel = new double[LetterCapacity];
    private readonly double[] advance = new double[LetterCapacity];
    private readonly double[] baseAlpha = new double[LetterCapacity];
    private readonly double[] letterSize = new double[LetterCapacity];
    private readonly double[] burn = new double[LetterCapacity];
    private readonly double[] letterScale = new double[LetterCapacity];
    private readonly double[] burnGravity = new double[LetterCapacity];
    private readonly string[] letterChar = new string[LetterCapacity];
    private readonly Color[] letterColor = new Color[LetterCapacity];
    private int letterCount;

    // -- dragon ----------------------------------------------------------------------

    private double[] segX = [];
    private double[] segY = [];
    private double[] segPrevX = [];
    private double[] segPrevY = [];
    private int segmentCount;

    // -- fire particles / embers ------------------------------------------------------

    private readonly double[] fireX = new double[FireCapacity];
    private readonly double[] fireY = new double[FireCapacity];
    private readonly double[] fireVx = new double[FireCapacity];
    private readonly double[] fireVy = new double[FireCapacity];
    private readonly double[] fireLife = new double[FireCapacity];
    private readonly double[] fireLifeMax = new double[FireCapacity];
    private readonly double[] fireSize = new double[FireCapacity];
    private readonly string[] fireChar = new string[FireCapacity];
    private int fireCount;

    private readonly double[] emberX = new double[EmberCapacity];
    private readonly double[] emberY = new double[EmberCapacity];
    private readonly double[] emberVx = new double[EmberCapacity];
    private readonly double[] emberVy = new double[EmberCapacity];
    private readonly double[] emberLife = new double[EmberCapacity];
    private readonly double[] emberSize = new double[EmberCapacity];
    private readonly string[] emberChar = new string[EmberCapacity];
    private readonly Color[] emberColor = new Color[EmberCapacity];
    private int emberCount;

    private double fireSpawnAccumulator;
    private double fireHoldTime;

    // -- enemies -----------------------------------------------------------------------

    private sealed class Enemy
    {
        public double X;
        public double Y;
        public double Vx;
        public double Vy;
        public int Hp;
        public string Glyph = "";
        public double Size;
        public Color Color;
        public double Phase;
        public bool Dying;
        public double DeathTimer;
        public int Kind;
    }

    private readonly List<Enemy> enemies = [];
    private int score;
    private double scoreFlash;

    // -- runes / tunnel / shake ----------------------------------------------------------

    private const int RuneCount = 8;
    private readonly double[] runeX = new double[RuneCount];
    private readonly double[] runeY = new double[RuneCount];
    private readonly double[] runeSpeed = new double[RuneCount];
    private readonly double[] runePhase = new double[RuneCount];
    private readonly double[] runeSize = new double[RuneCount];
    private readonly double[] runeAlpha = new double[RuneCount];
    private readonly string[] runeChar = new string[RuneCount];
    private bool runesInitialized;

    private const int TunnelCount = 12;
    private const double TunnelDepth = 1200;
    private readonly double[] tunnelZ = new double[TunnelCount];
    private readonly int[] tunnelDir = new int[TunnelCount];
    private readonly int[] tunnelText = new int[TunnelCount];

    private double shakeAmplitude;
    private double shakeX;
    private double shakeY;

    private static readonly Geometry CursorArcs = BuildCursorArcs();
    private static readonly Pen CursorArcPen = BuildPen("#ff8844", 0.25, 1);
    private static readonly Pen CursorCrossPen = BuildPen("#ff8844", 0.15, 0.5);

    public DragonSurface()
    {
        Cursor = Cursors.Cross;
        Config.SegmentsChanged += (_, _) => ResetDragon();
        SizeChanged += (_, _) => OnSurfaceResized();
        ResetDragon();
        ResetTunnel();
    }

    internal DragonConfig Config { get; } = new();

    internal int LetterCount => letterCount;

    internal int ParticleCount => fireCount + emberCount;

    // ================================ update =========================================

    protected override void Step(double dt)
    {
        if (SurfaceWidth <= 0 || SurfaceHeight <= 0)
        {
            return;
        }

        EnsureRunes();
        UpdateShake();
        UpdateTunnel();
        UpdateRunes();
        UpdateDragon();
        UpdateLetters(dt);
        UpdateFire(dt);
        UpdateParticles(dt);
        UpdateEnemies(dt);
    }

    private void OnSurfaceResized()
    {
        if (SurfaceWidth <= 0 || SurfaceHeight <= 0)
        {
            return;
        }

        RebuildLetters();
        ResetTunnel();
    }

    /// <summary>Lays the page out through the pretext engine and turns every grapheme into a particle.</summary>
    private void RebuildLetters()
    {
        letterCount = 0;
        double w = SurfaceWidth;
        double marginX = Math.Max(50, w * 0.06);
        double marginY = Math.Max(60, SurfaceHeight * 0.06);
        double contentW = w - (marginX * 2);
        bool twoColumn = contentW > 700;
        double rightX = twoColumn ? marginX + (contentW * 0.56) : marginX;

        foreach (BlockSpec block in Blocks)
        {
            double x;
            double columnWidth;
            switch (block.Column)
            {
                case ColumnKind.Right:
                    x = twoColumn ? rightX : marginX;
                    columnWidth = Math.Min(block.MaxWidth, twoColumn ? contentW * 0.4 : contentW);
                    break;
                case ColumnKind.Center:
                    columnWidth = Math.Min(block.MaxWidth, contentW);
                    x = marginX + ((contentW - columnWidth) / 2);
                    break;
                default:
                    x = marginX;
                    columnWidth = Math.Min(block.MaxWidth, twoColumn ? contentW * 0.5 : contentW);
                    break;
            }

            double yTop = marginY + block.YOffset;
            PreparedTextWithSegments prepared = CanvasText.Prepare(block.Text, block.FontSize, block.PreWrap);
            LayoutLinesResult layout = TextLayoutEngine.LayoutWithLines(prepared, columnWidth, block.LineHeight);
            Color color = CanvasText.Hex(block.Color);

            for (int lineIndex = 0; lineIndex < layout.Lines.Count; lineIndex++)
            {
                double penX = x;
                double centerY = yTop + (lineIndex * block.LineHeight) + (block.LineHeight / 2);
                foreach (string grapheme in CanvasText.Graphemes(layout.Lines[lineIndex].Text))
                {
                    if (grapheme == "\n" || letterCount >= LetterCapacity)
                    {
                        continue;
                    }

                    double glyphAdvance = CanvasText.Mono.Advance(grapheme, block.FontSize);
                    int n = letterCount++;
                    homeX[n] = penX + (glyphAdvance / 2);
                    homeY[n] = centerY;
                    posX[n] = homeX[n];
                    posY[n] = homeY[n];
                    velX[n] = 0;
                    velY[n] = 0;
                    rotation[n] = 0;
                    rotationVel[n] = 0;
                    advance[n] = glyphAdvance;
                    baseAlpha[n] = block.Alpha;
                    letterSize[n] = block.FontSize;
                    burn[n] = 0;
                    letterScale[n] = 1;
                    burnGravity[n] = 0;
                    letterChar[n] = grapheme;
                    letterColor[n] = color;
                    penX += glyphAdvance;
                }
            }
        }
    }

    private void ResetDragon()
    {
        segmentCount = (int)Math.Round(Config.DragonSegments);
        segX = new double[segmentCount];
        segY = new double[segmentCount];
        segPrevX = new double[segmentCount];
        segPrevY = new double[segmentCount];
        double cx = Math.Max(SurfaceWidth / 2, 1);
        double cy = Math.Max(SurfaceHeight / 2, 1);
        for (int i = 0; i < segmentCount; i++)
        {
            segX[i] = cx;
            segY[i] = cy + (i * SegmentSpacing);
            segPrevX[i] = segX[i];
            segPrevY[i] = segY[i];
        }
    }

    private double SegmentRadius(int index)
    {
        if (index < 3)
        {
            return (2.5 - (index * 0.15)) * Config.DragonScale;
        }

        double t = (index - 3.0) / (segmentCount - 3.0);
        return ((2 * (1 - (t * t))) + 0.2) * Config.DragonScale;
    }

    private void UpdateDragon()
    {
        Point mouse = MouseOrCenter;
        for (int i = 0; i < segmentCount; i++)
        {
            segPrevX[i] = segX[i];
            segPrevY[i] = segY[i];
        }

        segX[0] += (mouse.X - segX[0]) * Config.DragonSpeed;
        segY[0] += (mouse.Y - segY[0]) * Config.DragonSpeed;
        for (int i = 1; i < segmentCount; i++)
        {
            double dx = segX[i] - segX[i - 1];
            double dy = segY[i] - segY[i - 1];
            double distance = Math.Sqrt((dx * dx) + (dy * dy));
            if (distance > SegmentSpacing)
            {
                double k = SegmentSpacing / distance;
                segX[i] = segX[i - 1] + (dx * k);
                segY[i] = segY[i - 1] + (dy * k);
            }
        }
    }

    private void UpdateLetters(double dt)
    {
        int influencers = Math.Min((int)Math.Round(segmentCount * 0.4), segmentCount);
        double damping = Config.Damping;
        double springStrength = Config.SpringStrength;
        double pushForce = Config.PushForce;
        double gravity = Config.BurnGravity;

        for (int n = 0; n < letterCount; n++)
        {
            double vx = velX[n];
            double vy = velY[n];
            double rv = rotationVel[n];
            double px = posX[n];
            double py = posY[n];
            double w = advance[n];

            for (int e = 0; e < influencers; e++)
            {
                double radius = SegmentRadius(e);
                double bodyReach = 14 * radius * 0.45;
                double dx = px - segX[e];
                double dy = py - segY[e];
                double d2 = (dx * dx) + (dy * dy);
                double reach = bodyReach + (w * 0.4) + 4;
                if (d2 < reach * reach && d2 > 0.01)
                {
                    double d = Math.Sqrt(d2);
                    double force = pushForce * ((reach - d) / reach) * radius;
                    double nx = dx / d;
                    double ny = dy / d;
                    vx += (nx * force) + ((segX[e] - segPrevX[e]) * 0.4);
                    vy += (ny * force) + ((segY[e] - segPrevY[e]) * 0.4);
                    rv += ((nx * 0.3) - (ny * 0.2)) * force * 0.12;
                }
            }

            for (int e = 5; e < segmentCount; e += 5)
            {
                double dx = px - segX[e];
                double dy = py - segY[e];
                double d2 = (dx * dx) + (dy * dy);
                if (d2 < 1600 && d2 > 100)
                {
                    double wake = (1 - (Math.Sqrt(d2) / 40)) * 0.12;
                    vx += (segX[e] - segPrevX[e]) * wake;
                    vy += (segY[e] - segPrevY[e]) * wake;
                }
            }

            if (burn[n] > 0)
            {
                burn[n] -= dt;
                letterScale[n] = 1 + (burn[n] * 0.4);
                burnGravity[n] = gravity;
                if (Rng.NextDouble() < dt * 2)
                {
                    SpawnEmber(px, py);
                }

                if (burn[n] <= 0)
                {
                    burn[n] = 0;
                    letterScale[n] = 1;
                    burnGravity[n] = 0;
                }
            }

            double hx = homeX[n] - px;
            double hy = homeY[n] - py;
            double homeDistance = Math.Sqrt((hx * hx) + (hy * hy));
            if (homeDistance > 0.5)
            {
                double k = springStrength * (1 + (homeDistance * 0.001));
                vx += hx * k;
                vy += hy * k;
                rv -= rotation[n] * 0.05;
            }
            else
            {
                rotation[n] *= 0.9;
            }

            vy += burnGravity[n];
            velX[n] = vx * damping;
            velY[n] = vy * damping;
            rotationVel[n] = rv * 0.91;
            posX[n] = px + velX[n];
            posY[n] = py + velY[n];
            rotation[n] += rotationVel[n];
        }
    }

    private void UpdateFire(double dt)
    {
        if (!IsPointerDown)
        {
            fireHoldTime = 0;
            return;
        }

        fireSpawnAccumulator += dt;
        fireHoldTime += dt;

        double headX = segX[0];
        double headY = segY[0];
        int reference = Math.Min(3, segmentCount - 1);
        double dirX = headX - segX[reference];
        double dirY = headY - segY[reference];
        double length = Math.Sqrt((dirX * dirX) + (dirY * dirY));
        if (length == 0)
        {
            length = 1;
        }

        dirX /= length;
        dirY /= length;
        double angle = Math.Atan2(dirY, dirX);

        if (Config.ShowParticles)
        {
            while (fireSpawnAccumulator > 0.025 && fireCount < FireCapacity)
            {
                fireSpawnAccumulator -= 0.025;
                for (int i = 0; i < 2 && fireCount < FireCapacity; i++)
                {
                    int n = fireCount++;
                    double spread = Rng.NextDouble() - 0.5;
                    double speed = 5 + (Rng.NextDouble() * 7);
                    fireX[n] = headX + (dirX * 15);
                    fireY[n] = headY + (dirY * 15);
                    fireVx[n] = Math.Cos(angle + spread) * speed;
                    fireVy[n] = (Math.Sin(angle + spread) * speed) - Rng.NextDouble();
                    fireLife[n] = 1;
                    fireLifeMax[n] = 0.3 + (Rng.NextDouble() * 0.4);
                    fireSize[n] = 6 + (Rng.NextDouble() * 12);
                    fireChar[n] = FireChars[Rng.Next(FireChars.Length)];
                }
            }
        }
        else
        {
            fireSpawnAccumulator = 0;
        }

        double mouthX = headX + (dirX * 50);
        double mouthY = headY + (dirY * 50);
        FireBlast(mouthX, mouthY, dirX, dirY);
        DamageEnemies(mouthX, mouthY);
        AddShake(Math.Min(1 + (fireHoldTime * 0.2), 3));
    }

    /// <summary>Ignites and blasts letters within the fire radius (upstream <c>je</c>).</summary>
    private void FireBlast(double x, double y, double dirX, double dirY)
    {
        double radius = Config.FireRadius;
        double radiusSq = radius * radius;
        double force = Config.FireForce;
        int hits = 0;

        for (int n = 0; n < letterCount; n++)
        {
            double dx = posX[n] - x;
            double dy = posY[n] - y;
            double d2 = (dx * dx) + (dy * dy);
            if (d2 < radiusSq && d2 > 0.01)
            {
                double d = Math.Sqrt(d2);
                double t = 1 - (d / radius);
                double blast = force * t * t;
                velX[n] += ((dx / d * 0.4) + (dirX * 0.6)) * blast;
                velY[n] += (((dy / d * 0.4) + (dirY * 0.6)) * blast) - (blast * 0.2);
                rotationVel[n] += (Rng.NextDouble() - 0.5) * blast * 0.3;
                burn[n] = Math.Max(burn[n], 0.5 + (Rng.NextDouble() * 1.2));
                hits++;
            }
        }

        if (hits > 3)
        {
            AddShake(Math.Min(hits * 0.4, 6));
            for (int i = 0; i < Math.Min(hits, 4); i++)
            {
                SpawnEmber(x, y);
            }
        }
    }

    private void UpdateParticles(double dt)
    {
        for (int i = fireCount - 1; i >= 0; i--)
        {
            fireX[i] += fireVx[i];
            fireY[i] += fireVy[i];
            fireVy[i] -= 0.25;
            fireVx[i] *= 0.97;
            fireLife[i] -= dt / fireLifeMax[i];
            if (fireLife[i] <= 0)
            {
                fireCount--;
                fireX[i] = fireX[fireCount];
                fireY[i] = fireY[fireCount];
                fireVx[i] = fireVx[fireCount];
                fireVy[i] = fireVy[fireCount];
                fireLife[i] = fireLife[fireCount];
                fireLifeMax[i] = fireLifeMax[fireCount];
                fireSize[i] = fireSize[fireCount];
                fireChar[i] = fireChar[fireCount];
            }
        }

        for (int i = emberCount - 1; i >= 0; i--)
        {
            emberX[i] += emberVx[i];
            emberY[i] += emberVy[i];
            emberVy[i] += 0.15;
            emberVx[i] *= 0.97;
            emberLife[i] -= dt;
            if (emberLife[i] <= 0)
            {
                emberCount--;
                emberX[i] = emberX[emberCount];
                emberY[i] = emberY[emberCount];
                emberVx[i] = emberVx[emberCount];
                emberVy[i] = emberVy[emberCount];
                emberLife[i] = emberLife[emberCount];
                emberSize[i] = emberSize[emberCount];
                emberChar[i] = emberChar[emberCount];
                emberColor[i] = emberColor[emberCount];
            }
        }
    }

    private void SpawnEmber(double x, double y)
    {
        if (!Config.ShowEmbers || emberCount >= EmberCapacity)
        {
            return;
        }

        int n = emberCount++;
        double angle = Rng.NextDouble() * Math.PI * 2;
        double speed = 1 + (Rng.NextDouble() * 3);
        emberX[n] = x;
        emberY[n] = y;
        emberVx[n] = Math.Cos(angle) * speed;
        emberVy[n] = (Math.Sin(angle) * speed) - 2;
        emberLife[n] = 0.3 + (Rng.NextDouble() * 0.6);
        emberSize[n] = 4 + (Rng.NextDouble() * 7);
        emberChar[n] = EmberChars[Rng.Next(EmberChars.Length)];
        emberColor[n] = EmberColors[Rng.Next(EmberColors.Length)];
    }

    private void UpdateEnemies(double dt)
    {
        if (!Config.ShowEnemies)
        {
            return;
        }

        double w = SurfaceWidth;
        double h = SurfaceHeight;
        int alive = 0;
        foreach (Enemy enemy in enemies)
        {
            if (!enemy.Dying)
            {
                alive++;
            }
        }

        while (alive < (int)Math.Round(Config.EnemyCount))
        {
            SpawnEnemy(w, h);
            alive++;
        }

        double speed = Config.EnemySpeed;
        for (int i = enemies.Count - 1; i >= 0; i--)
        {
            Enemy enemy = enemies[i];
            if (enemy.Dying)
            {
                enemy.DeathTimer -= dt;
                enemy.X += enemy.Vx;
                enemy.Y += enemy.Vy;
                enemy.Vx *= 0.95;
                enemy.Vy *= 0.95;
                if (enemy.DeathTimer <= 0)
                {
                    enemies[i] = enemies[^1];
                    enemies.RemoveAt(enemies.Count - 1);
                }

                continue;
            }

            if (enemy.Kind == 3)
            {
                enemy.X += Math.Sin((Time * 1.5) + enemy.Phase) * speed * 1.2;
                enemy.Y += Math.Cos((Time * 1.2) + (enemy.Phase * 1.3)) * speed * 0.8;
            }
            else if (enemy.Kind == 2)
            {
                enemy.X += enemy.Vx * speed;
                enemy.Y += enemy.Vy * speed;
                if (Rng.NextDouble() < dt * 0.5)
                {
                    enemy.Vx += (Rng.NextDouble() - 0.5) * 3;
                    enemy.Vy += (Rng.NextDouble() - 0.5) * 3;
                }

                enemy.Vx *= 0.99;
                enemy.Vy *= 0.99;
            }
            else
            {
                enemy.Vx += ((w / 2) - enemy.X) * 1e-4 + ((Rng.NextDouble() - 0.5) * 0.1);
                enemy.Vy += ((h / 2) - enemy.Y) * 1e-4 + ((Rng.NextDouble() - 0.5) * 0.1);
                enemy.Vx *= 0.995;
                enemy.Vy *= 0.995;
                enemy.X += enemy.Vx * speed;
                enemy.Y += enemy.Vy * speed;
            }

            if (enemy.X < -50)
            {
                enemy.X = w + 40;
            }

            if (enemy.X > w + 50)
            {
                enemy.X = -40;
            }

            if (enemy.Y < -50)
            {
                enemy.Y = h + 40;
            }

            if (enemy.Y > h + 50)
            {
                enemy.Y = -40;
            }

            double dx = enemy.X - segX[0];
            double dy = enemy.Y - segY[0];
            double d2 = (dx * dx) + (dy * dy);
            if (d2 < 15000)
            {
                double d = Math.Sqrt(d2);
                if (d == 0)
                {
                    d = 1;
                }

                double avoid = 1.5 * (1 - (d / 122));
                enemy.Vx += dx / d * avoid;
                enemy.Vy += dy / d * avoid;
            }
        }

        if (scoreFlash > 0)
        {
            scoreFlash -= dt * 3;
        }
    }

    private void SpawnEnemy(double w, double h)
    {
        int kind = Rng.Next(EnemyKinds.Length);
        (string glyph, string color, int hp, double size, double speed) = EnemyKinds[kind];
        int edge = Rng.Next(4);
        double x;
        double y;
        switch (edge)
        {
            case 0:
                x = -30;
                y = Rng.NextDouble() * h;
                break;
            case 1:
                x = w + 30;
                y = Rng.NextDouble() * h;
                break;
            case 2:
                x = Rng.NextDouble() * w;
                y = -30;
                break;
            default:
                x = Rng.NextDouble() * w;
                y = h + 30;
                break;
        }

        enemies.Add(new Enemy
        {
            X = x,
            Y = y,
            Vx = (Rng.NextDouble() - 0.5) * speed * 2,
            Vy = (Rng.NextDouble() - 0.5) * speed * 2,
            Hp = hp,
            Glyph = glyph,
            Size = size,
            Color = CanvasText.Hex(color),
            Phase = Rng.NextDouble() * Math.PI * 2,
            Kind = kind,
        });
    }

    /// <summary>Fire vs. enemies (upstream <c>Ye</c>): knockback, kills, score.</summary>
    private void DamageEnemies(double x, double y)
    {
        if (!Config.ShowEnemies)
        {
            return;
        }

        double radius = Config.FireRadius * 0.6;
        double radiusSq = radius * radius;
        foreach (Enemy enemy in enemies)
        {
            if (enemy.Dying)
            {
                continue;
            }

            double dx = enemy.X - x;
            double dy = enemy.Y - y;
            double d2 = (dx * dx) + (dy * dy);
            if (d2 >= radiusSq)
            {
                continue;
            }

            double d = Math.Sqrt(d2);
            if (d == 0)
            {
                d = 1;
            }

            enemy.Hp--;
            enemy.Vx += dx / d * 5;
            enemy.Vy += dy / d * 5;
            if (enemy.Hp <= 0)
            {
                enemy.Dying = true;
                enemy.DeathTimer = 0.5;
                enemy.Vx = dx / d * 8;
                enemy.Vy = (dy / d * 8) - 3;
                score += enemy.Kind switch
                {
                    1 => 30,
                    2 => 20,
                    3 => 25,
                    _ => 10,
                };
                scoreFlash = 1;
                for (int i = 0; i < 3; i++)
                {
                    SpawnEmber(enemy.X, enemy.Y);
                }
            }
        }
    }

    private void EnsureRunes()
    {
        if (runesInitialized)
        {
            return;
        }

        runesInitialized = true;
        for (int i = 0; i < RuneCount; i++)
        {
            runeX[i] = Rng.NextDouble() * SurfaceWidth;
            runeY[i] = Rng.NextDouble() * SurfaceHeight;
            runeSpeed[i] = 0.1 + (Rng.NextDouble() * 0.4);
            runePhase[i] = Rng.NextDouble() * Math.PI * 2;
            runeSize[i] = 14 + (Rng.NextDouble() * 14);
            runeAlpha[i] = 0.02 + (Rng.NextDouble() * 0.04);
            runeChar[i] = RuneChars[Rng.Next(RuneChars.Length)];
        }
    }

    private void UpdateRunes()
    {
        if (!Config.ShowRunes)
        {
            return;
        }

        for (int i = 0; i < RuneCount; i++)
        {
            runeY[i] -= runeSpeed[i];
            if (runeY[i] < -30)
            {
                runeY[i] = SurfaceHeight + 30;
                runeX[i] = Rng.NextDouble() * SurfaceWidth;
            }
        }
    }

    private void ResetTunnel()
    {
        for (int i = 0; i < TunnelCount; i++)
        {
            tunnelZ[i] = (double)i / TunnelCount * TunnelDepth;
            tunnelDir[i] = i % 4;
            tunnelText[i] = i % TunnelTexts.Length;
        }
    }

    private void UpdateTunnel()
    {
        for (int i = 0; i < TunnelCount; i++)
        {
            tunnelZ[i] -= 0.67;
            if (tunnelZ[i] < 10)
            {
                tunnelZ[i] += TunnelDepth;
                tunnelDir[i] = (tunnelDir[i] + 1) % 4;
                tunnelText[i] = Rng.Next(TunnelTexts.Length);
            }
        }
    }

    private void AddShake(double amount)
    {
        if (Config.ScreenShake)
        {
            shakeAmplitude = Math.Max(shakeAmplitude, Math.Min(amount, 8));
        }
    }

    private void UpdateShake()
    {
        if (shakeAmplitude > 0.1)
        {
            shakeX = (Rng.NextDouble() - 0.5) * shakeAmplitude;
            shakeY = (Rng.NextDouble() - 0.5) * shakeAmplitude;
            shakeAmplitude *= 0.85;
        }
        else
        {
            shakeX = 0;
            shakeY = 0;
            shakeAmplitude = 0;
        }
    }

    // ================================ draw ===========================================

    protected override void Draw(DrawingContext dc)
    {
        if (segmentCount == 0)
        {
            return;
        }

        bool shaking = shakeX != 0 || shakeY != 0;
        if (shaking)
        {
            TranslateTransform shake = new(shakeX, shakeY);
            shake.Freeze();
            dc.PushTransform(shake);
        }

        DrawTunnel(dc);
        DrawRunes(dc);
        DrawLetters(dc);
        DrawEnemies(dc);
        DrawDragon(dc);
        DrawFireAndEmbers(dc);
        DrawCursor(dc);

        if (shaking)
        {
            dc.Pop();
        }
    }

    private void DrawTunnel(DrawingContext dc)
    {
        double cx = SurfaceWidth * 0.5;
        double cy = SurfaceHeight * 0.5;
        for (int i = 0; i < TunnelCount; i++)
        {
            double perspective = 400 / (400 + tunnelZ[i]);
            double alpha = Math.Clamp((0.08 * perspective) - 0.01, 0, 0.06);
            if (alpha < 0.003)
            {
                continue;
            }

            double distance = 350 * perspective;
            double x = cx;
            double y = cy;
            switch (tunnelDir[i])
            {
                case 0:
                    y = cy - distance;
                    break;
                case 1:
                    x = cx + distance;
                    break;
                case 2:
                    y = cy + distance;
                    break;
                default:
                    x = cx - distance;
                    break;
            }

            CanvasText.DrawLabelCentered(
                dc, TunnelTexts[tunnelText[i]], x, y, 13, CanvasText.Brush(CanvasText.Hex("#ff8844", alpha)));
        }
    }

    private void DrawRunes(DrawingContext dc)
    {
        if (!Config.ShowRunes || !runesInitialized)
        {
            return;
        }

        for (int i = 0; i < RuneCount; i++)
        {
            double alpha = runeAlpha[i] * (0.5 + (Math.Sin((Time * 0.4) + runePhase[i]) * 0.5));
            double x = runeX[i] + (Math.Sin((Time * 0.7) + runePhase[i]) * 12);
            CanvasText.Mono.DrawCentered(
                dc, runeChar[i], x, runeY[i], runeSize[i],
                CanvasText.Brush(CanvasText.Hex("#ff6600", alpha)));
        }
    }

    private void DrawLetters(DrawingContext dc)
    {
        double opacity = Config.TextOpacity;
        for (int n = 0; n < letterCount; n++)
        {
            bool burning = burn[n] > 0;
            double alpha = baseAlpha[n] * opacity;
            Color color = letterColor[n];
            if (burning)
            {
                double heat = Math.Min(1, burn[n]);
                color = Color.FromRgb(
                    255,
                    CanvasText.ToByte(80 + (heat * 175)),
                    CanvasText.ToByte(heat * 60));
                alpha = Math.Min(1, alpha + 0.5);
            }

            alpha = Math.Clamp(alpha, 0, 1);
            if (alpha <= 0)
            {
                continue;
            }

            color.A = CanvasText.ToByte(alpha * 255);
            CanvasText.Mono.DrawCentered(
                dc, letterChar[n], posX[n], posY[n], letterSize[n],
                CanvasText.Brush(color), rotation[n], letterScale[n]);

            if (burning && burn[n] > 0.3)
            {
                CanvasText.Mono.DrawCentered(
                    dc, letterChar[n], posX[n], posY[n], letterSize[n],
                    CanvasText.Brush(CanvasText.Hex("#ffaa00", burn[n] * 0.2)), rotation[n], letterScale[n]);
            }
        }
    }

    private void DrawEnemies(DrawingContext dc)
    {
        if (!Config.ShowEnemies)
        {
            return;
        }

        foreach (Enemy enemy in enemies)
        {
            if (enemy.Dying)
            {
                double t = enemy.DeathTimer / 0.5;
                CanvasText.Mono.DrawCentered(
                    dc, enemy.Glyph, enemy.X, enemy.Y, enemy.Size,
                    CanvasText.Brush(CanvasText.Hex("#ffaa00", t * 0.8)),
                    Time * 15, t);
            }
            else
            {
                double bob = Math.Sin((Time * 2.5) + enemy.Phase) * 4;
                double alpha = enemy.Kind == 3
                    ? 0.4 + (Math.Sin((Time * 3) + enemy.Phase) * 0.2)
                    : 0.75;
                Color color = enemy.Color;
                color.A = CanvasText.ToByte(alpha * 255);
                CanvasText.Mono.DrawCentered(dc, enemy.Glyph, enemy.X, enemy.Y + bob, enemy.Size, CanvasText.Brush(color));
            }
        }

        if (score > 0)
        {
            double alpha = 0.3 + (Math.Max(scoreFlash, 0) * 0.4);
            Color color = scoreFlash > 0 ? CanvasText.Hex("#ffaa33", alpha) : CanvasText.Hex("#666", alpha);
            CanvasText.DrawLabelTopLeft(
                dc,
                string.Create(System.Globalization.CultureInfo.InvariantCulture, $"SCORE {score}"),
                20, 20, 14, CanvasText.Brush(color), bold: true, ui: true);
        }
    }

    private void DrawDragon(DrawingContext dc)
    {
        Point mouse = MouseOrCenter;
        bool firing = IsPointerDown;

        for (int t = segmentCount - 1; t >= 0; t--)
        {
            double radius = SegmentRadius(t);
            int charIndex = Math.Min(t, BodyChars.Length - 1);
            double size = 14 * radius;
            double depth = (double)t / segmentCount;
            double shimmer = Math.Sin((Time * 3) + (t * 0.3)) * 0.12;

            Color color;
            if (t < 3)
            {
                color = Color.FromRgb(
                    255,
                    CanvasText.ToByte(180 + (shimmer * 60)),
                    CanvasText.ToByte(40 + (shimmer * 30)));
            }
            else
            {
                double pulse = Math.Sin((Time * 2) - (t * 0.15)) * 0.15;
                color = Color.FromArgb(
                    CanvasText.ToByte((1 - (depth * 0.45)) * 255),
                    CanvasText.ToByte((255 * (1 - (depth * 0.5))) + (shimmer * 20)),
                    CanvasText.ToByte((140 * (1 - (depth * 0.8))) + (pulse * 60)),
                    CanvasText.ToByte((30 * (1 - depth)) + (pulse * 20)));
            }

            double heading = t == 0
                ? Math.Atan2(mouse.Y - segY[0], mouse.X - segX[0])
                : Math.Atan2(segY[t - 1] - segY[t], segX[t - 1] - segX[t]);

            if (t < 4)
            {
                double glowAlpha = 0.06 * (firing ? 2 : 1);
                dc.DrawEllipse(
                    CanvasText.Brush(CanvasText.Hex("#ff6600", glowAlpha)), null,
                    new Point(segX[t], segY[t]), size * 1.1, size * 1.1);
            }

            Brush bodyBrush = CanvasText.Brush(color);

            if (Config.ShowSpines && t >= 4 && t <= 30 && t % 3 == 0)
            {
                double normal = heading + (Math.PI / 2);
                double spineSize = size * (0.6 + (Math.Sin((Time * 3) + t) * 0.15));
                Color spineColor = color;
                spineColor.A = CanvasText.ToByte(0.35 * 255);
                CanvasText.Mono.DrawCentered(
                    dc, "▴",
                    segX[t] + (Math.Cos(normal) * size * 0.35),
                    segY[t] + (Math.Sin(normal) * size * 0.35),
                    spineSize, CanvasText.Brush(spineColor));
            }

            if (Config.ShowWings && t >= 7 && t <= 16 && t % 2 == 0)
            {
                double flap = Math.Sin((Time * 3.5) + (t * 0.4)) * 0.5;
                double wingSize = size * (1.8 - (Math.Abs(t - 11.5) * 0.12));
                double wingDistance = size * 1.4;
                double left = heading + (Math.PI / 2) + flap;
                double right = heading - (Math.PI / 2) - flap;
                Color wingColor = color;
                wingColor.A = CanvasText.ToByte(0.4 * 255);
                Brush wingBrush = CanvasText.Brush(wingColor);
                CanvasText.Mono.DrawCentered(
                    dc, "≺",
                    segX[t] + (Math.Cos(left) * wingDistance),
                    segY[t] + (Math.Sin(left) * wingDistance),
                    wingSize, wingBrush);
                CanvasText.Mono.DrawCentered(
                    dc, "≻",
                    segX[t] + (Math.Cos(right) * wingDistance),
                    segY[t] + (Math.Sin(right) * wingDistance),
                    wingSize, wingBrush);
            }

            double bob = Math.Sin((Time * 5) + (t * 0.35)) * 1.5;
            double bobX = -Math.Sin(heading) * bob;
            double bobY = Math.Cos(heading) * bob;
            CanvasText.MonoBold.DrawCentered(
                dc, BodyChars[charIndex], segX[t] + bobX, segY[t] + bobY, size, bodyBrush, heading);
            if (firing && t < 3)
            {
                CanvasText.MonoBold.DrawCentered(
                    dc, BodyChars[charIndex], segX[t] + bobX, segY[t] + bobY, size,
                    CanvasText.Brush(CanvasText.Hex("#ffcc00", 0.3)), heading);
            }
        }

        double eyeAngle = Math.Atan2(mouse.Y - segY[0], mouse.X - segX[0]);
        double eyeX = segX[0] + (Math.Cos(eyeAngle + 0.5) * 10);
        double eyeY = segY[0] + (Math.Sin(eyeAngle + 0.5) * 10);
        dc.DrawEllipse(
            CanvasText.Brush(CanvasText.Hex("#ff8800", firing ? 0.2 : 0.1)), null,
            new Point(eyeX, eyeY), firing ? 18 : 12, firing ? 18 : 12);
        string eye = Time % 5 > 4.7 ? "—" : (firing ? "◉" : "⊙");
        CanvasText.Mono.DrawCentered(
            dc, eye, eyeX, eyeY, 16,
            CanvasText.Brush(firing ? Colors.White : CanvasText.Hex("#ffcc00")));
    }

    private void DrawFireAndEmbers(DrawingContext dc)
    {
        if (Config.ShowEmbers)
        {
            for (int i = 0; i < emberCount; i++)
            {
                Color color = emberColor[i];
                color.A = CanvasText.ToByte(Math.Min(1, emberLife[i] * 2) * 255);
                CanvasText.Mono.DrawCentered(
                    dc, emberChar[i], emberX[i], emberY[i], emberSize[i], CanvasText.Brush(color));
            }
        }

        if (Config.ShowParticles)
        {
            for (int i = 0; i < fireCount; i++)
            {
                double t = 1 - fireLife[i];
                byte r;
                byte g;
                byte b;
                if (t < 0.15)
                {
                    r = 255;
                    g = 255;
                    b = CanvasText.ToByte(255 * (1 - (t * 6.67)));
                }
                else if (t < 0.4)
                {
                    r = 255;
                    g = CanvasText.ToByte(255 * (1 - ((t - 0.15) * 3.2)));
                    b = 0;
                }
                else
                {
                    double cool = (t - 0.4) * 1.67;
                    r = CanvasText.ToByte(255 * (1 - (cool * 0.6)));
                    g = CanvasText.ToByte(80 * (1 - cool));
                    b = 0;
                }

                double size = fireSize[i] * (0.4 + (fireLife[i] * 0.6));
                CanvasText.Mono.DrawCentered(
                    dc, fireChar[i], fireX[i], fireY[i], size,
                    CanvasText.Brush(Color.FromArgb(CanvasText.ToByte(fireLife[i] * 0.85 * 255), r, g, b)));
            }
        }
    }

    private void DrawCursor(DrawingContext dc)
    {
        if (!Config.ShowCursor || double.IsNaN(Mouse.X))
        {
            return;
        }

        bool firing = IsPointerDown;
        double x = Mouse.X;
        double y = Mouse.Y;

        Matrix rotate = Matrix.Identity;
        rotate.Rotate(Time * 0.4 * (180 / Math.PI));
        rotate.Translate(x, y);
        MatrixTransform transform = new(rotate);
        transform.Freeze();
        dc.PushTransform(transform);
        dc.DrawGeometry(null, CursorArcPen, CursorArcs);
        dc.Pop();

        dc.DrawEllipse(
            CanvasText.Brush(CanvasText.Hex(firing ? "#ffaa33" : "#ff8844", firing ? 0.8 : 0.5)), null,
            new Point(x, y), firing ? 3 : 2, firing ? 3 : 2);

        dc.DrawLine(CursorCrossPen, new Point(x - 24, y), new Point(x - 8, y));
        dc.DrawLine(CursorCrossPen, new Point(x + 8, y), new Point(x + 24, y));
        dc.DrawLine(CursorCrossPen, new Point(x, y - 24), new Point(x, y - 8));
        dc.DrawLine(CursorCrossPen, new Point(x, y + 8), new Point(x, y + 24));
    }

    private static StreamGeometry BuildCursorArcs()
    {
        StreamGeometry geometry = new();
        using (StreamGeometryContext ctx = geometry.Open())
        {
            ctx.BeginFigure(new Point(16, 0), isFilled: false, isClosed: false);
            ctx.ArcTo(new Point(0, 16), new Size(16, 16), 0, false, SweepDirection.Clockwise, true, false);
            ctx.BeginFigure(new Point(-16, 0), isFilled: false, isClosed: false);
            ctx.ArcTo(new Point(0, -16), new Size(16, 16), 0, false, SweepDirection.Clockwise, true, false);
        }

        geometry.Freeze();
        return geometry;
    }

    private static Pen BuildPen(string hex, double alpha, double thickness)
    {
        Pen pen = new(CanvasText.Brush(CanvasText.Hex(hex, alpha)), thickness);
        pen.Freeze();
        return pen;
    }
}
