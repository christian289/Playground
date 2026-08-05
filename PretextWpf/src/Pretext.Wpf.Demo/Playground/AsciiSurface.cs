using System.Windows.Media;
using Pretext.Wpf.Demo.Playground.Scenes;

namespace Pretext.Wpf.Demo.Playground;

/// <summary>
/// Host for the "ASCII Animations" page: owns the five scenes, forwards the frame
/// clock/pointer to the active one, and re-inits a scene when it is activated.
/// </summary>
internal sealed class AsciiSurface : AnimatedSurface
{
    private int sceneIndex;
    private bool initialized;
    private double lastDt;

    internal IReadOnlyList<IAsciiScene> Scenes { get; } =
    [
        new MatrixRainScene(),
        new TextWaveScene(),
        new TextMorphScene(),
        new ParticleTextScene(),
        new TypewriterScene(),
    ];

    internal event EventHandler? SceneChanged;

    internal int SceneIndex => sceneIndex;

    internal IAsciiScene ActiveScene => Scenes[sceneIndex];

    internal void SelectScene(int index)
    {
        if (index < 0 || index >= Scenes.Count)
        {
            return;
        }

        sceneIndex = index;
        Scenes[index].Init(CurrentFrame(0));
        SceneChanged?.Invoke(this, EventArgs.Empty);
    }

    protected override void Step(double dt)
    {
        lastDt = dt;
        if (!initialized && SurfaceWidth > 0 && SurfaceHeight > 0)
        {
            initialized = true;
            ActiveScene.Init(CurrentFrame(0));
        }
    }

    protected override void Draw(DrawingContext dc)
    {
        if (!initialized)
        {
            return;
        }

        ActiveScene.Draw(dc, CurrentFrame(lastDt));
    }

    private SceneFrame CurrentFrame(double dt)
        => new(SurfaceWidth, SurfaceHeight, Time, dt, MouseOrCenter);
}
