using System.Windows;
using System.Windows.Media;

namespace Pretext.Wpf.Demo.Playground.Scenes;

/// <summary>Frame context handed to each ASCII scene (canvas size, clock, pointer).</summary>
internal readonly record struct SceneFrame(
    double Width,
    double Height,
    double Time,
    double Dt,
    Point Mouse);

/// <summary>
/// One tab of the "ASCII Animations" page. <see cref="Init"/> runs when the scene is
/// (re)activated; <see cref="Draw"/> runs every frame and owns both update and paint,
/// mirroring the upstream scene objects.
/// </summary>
internal interface IAsciiScene
{
    string Name { get; }

    string Hint { get; }

    void Init(in SceneFrame frame);

    void Draw(DrawingContext dc, in SceneFrame frame);
}
