using System.Globalization;
using System.Windows.Controls;

namespace Pretext.Wpf.Demo.Views;

/// <summary>ASCII animations page chrome: scene tabs, the per-scene hint, and fps stats.</summary>
public partial class AsciiView : UserControl
{
    public AsciiView()
    {
        InitializeComponent();
        SceneTabs.ItemsSource = Surface.Scenes.Select(scene => scene.Name).ToList();
        SceneTabs.SelectedIndex = 0;
        SceneHint.Text = Surface.ActiveScene.Hint;
        Surface.SceneChanged += (_, _) => SceneHint.Text = Surface.ActiveScene.Hint;
        Surface.StatsUpdated += (_, _) =>
            Stats.Text = string.Create(CultureInfo.InvariantCulture, $"{Surface.Fps} fps");
    }

    private void OnSceneSelected(object sender, SelectionChangedEventArgs e)
    {
        if (SceneTabs.SelectedIndex >= 0 && SceneTabs.SelectedIndex != Surface.SceneIndex)
        {
            Surface.SelectScene(SceneTabs.SelectedIndex);
        }
    }
}
