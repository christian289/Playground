using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media.Animation;

namespace Pretext.Wpf.Demo.Views;

/// <summary>
/// Dragon page chrome: hint that fades after six seconds, fps/letters/particles
/// stats, and the settings panel with presets (toggled by the gear button, P, Esc).
/// </summary>
public partial class DragonView : UserControl
{
    private Window? hookedWindow;
    private bool hintFaded;

    public DragonView()
    {
        InitializeComponent();
        PresetList.ItemsSource = Playground.DragonConfig.PresetNames;
        SettingsPanel.DataContext = Surface.Config;
        Surface.StatsUpdated += OnStatsUpdated;
        Surface.Config.PropertyChanged += (_, args) =>
        {
            if (args.PropertyName == nameof(Playground.DragonConfig.ActivePreset)
                && Surface.Config.ActivePreset is null)
            {
                PresetList.SelectedIndex = -1;
            }
        };
        Loaded += OnViewLoaded;
        Unloaded += OnViewUnloaded;
    }

    private void OnViewLoaded(object sender, RoutedEventArgs e)
    {
        hookedWindow = Window.GetWindow(this);
        if (hookedWindow is not null)
        {
            hookedWindow.PreviewKeyDown += OnWindowKeyDown;
        }

        if (!hintFaded)
        {
            DispatcherTimer(6, () =>
            {
                hintFaded = true;
                DoubleAnimation fade = new(0, TimeSpan.FromSeconds(0.8));
                Hint.BeginAnimation(OpacityProperty, fade);
            });
        }
    }

    private void OnViewUnloaded(object sender, RoutedEventArgs e)
    {
        if (hookedWindow is not null)
        {
            hookedWindow.PreviewKeyDown -= OnWindowKeyDown;
            hookedWindow = null;
        }
    }

    private void OnWindowKeyDown(object sender, KeyEventArgs e)
    {
        if (!IsVisible || e.OriginalSource is TextBoxBase)
        {
            return;
        }

        if (e.Key == Key.P)
        {
            SetPanelOpen(SettingsPanel.Visibility != Visibility.Visible);
            e.Handled = true;
        }
        else if (e.Key == Key.Escape && SettingsPanel.Visibility == Visibility.Visible)
        {
            SetPanelOpen(false);
            e.Handled = true;
        }
    }

    private void OnPanelToggleClick(object sender, RoutedEventArgs e) => SetPanelOpen(true);

    private void OnPanelCloseClick(object sender, RoutedEventArgs e) => SetPanelOpen(false);

    private void SetPanelOpen(bool open)
    {
        SettingsPanel.Visibility = open ? Visibility.Visible : Visibility.Collapsed;
        PanelToggle.Visibility = open ? Visibility.Collapsed : Visibility.Visible;
    }

    private void OnPresetSelected(object sender, SelectionChangedEventArgs e)
    {
        if (PresetList.SelectedItem is string name
            && name != Surface.Config.ActivePreset)
        {
            Surface.Config.ApplyPreset(name);
        }
    }

    private void OnStatsUpdated(object? sender, EventArgs e)
    {
        Stats.Text = string.Create(
            CultureInfo.InvariantCulture,
            $"{Surface.Fps} fps · {Surface.LetterCount} letters · {Surface.ParticleCount} particles");
    }

    private static void DispatcherTimer(double seconds, Action action)
    {
        System.Windows.Threading.DispatcherTimer timer = new()
        {
            Interval = TimeSpan.FromSeconds(seconds),
        };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            action();
        };
        timer.Start();
    }
}
