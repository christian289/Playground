using CommunityToolkit.Mvvm.ComponentModel;

namespace Pretext.Wpf.Demo.Playground;

/// <summary>
/// The dragon scene's tunables and presets, ported verbatim from the upstream
/// bundle's <c>cfg</c> object. Bound two-way to the settings panel; editing any
/// value clears the active preset highlight, exactly like the web original.
/// </summary>
internal sealed partial class DragonConfig : ObservableObject
{
    private bool applyingPreset;

    [ObservableProperty]
    private double dragonSegments = 60;

    [ObservableProperty]
    private double dragonSpeed = 0.18;

    [ObservableProperty]
    private double dragonScale = 1;

    [ObservableProperty]
    private bool showWings = true;

    [ObservableProperty]
    private bool showSpines = true;

    [ObservableProperty]
    private double pushForce = 6;

    [ObservableProperty]
    private double springStrength = 0.015;

    [ObservableProperty]
    private double damping = 0.93;

    [ObservableProperty]
    private double burnGravity = 0.8;

    [ObservableProperty]
    private double fireRadius = 120;

    [ObservableProperty]
    private double fireForce = 25;

    [ObservableProperty]
    private bool screenShake = true;

    [ObservableProperty]
    private bool showEmbers = true;

    [ObservableProperty]
    private bool showParticles = true;

    [ObservableProperty]
    private bool showRunes = true;

    [ObservableProperty]
    private bool showCursor = true;

    [ObservableProperty]
    private double textOpacity = 1;

    [ObservableProperty]
    private bool showEnemies = true;

    [ObservableProperty]
    private double enemyCount = 8;

    [ObservableProperty]
    private double enemySpeed = 0.6;

    [ObservableProperty]
    private string? activePreset;

    internal static IReadOnlyList<string> PresetNames { get; } =
        ["Default", "Gentle", "Chaos", "Zen", "Tiny", "Leviathan"];

    internal event EventHandler? SegmentsChanged;

    internal void ApplyPreset(string name)
    {
        applyingPreset = true;
        try
        {
            Reset();
            switch (name)
            {
                case "Gentle":
                    DragonSpeed = 0.1;
                    PushForce = 5;
                    FireForce = 10;
                    FireRadius = 60;
                    ScreenShake = false;
                    BurnGravity = 0.2;
                    SpringStrength = 0.03;
                    break;
                case "Chaos":
                    PushForce = 25;
                    FireForce = 50;
                    FireRadius = 200;
                    BurnGravity = 2.5;
                    SpringStrength = 0.005;
                    Damping = 0.96;
                    ScreenShake = true;
                    break;
                case "Zen":
                    ShowParticles = false;
                    ShowEmbers = false;
                    ScreenShake = false;
                    ShowRunes = false;
                    PushForce = 4;
                    FireForce = 8;
                    SpringStrength = 0.04;
                    BurnGravity = 0;
                    break;
                case "Tiny":
                    DragonSegments = 20;
                    DragonScale = 0.6;
                    FireRadius = 50;
                    PushForce = 6;
                    break;
                case "Leviathan":
                    DragonSegments = 80;
                    DragonScale = 2;
                    DragonSpeed = 0.08;
                    PushForce = 20;
                    FireRadius = 180;
                    break;
                default:
                    break;
            }

            ActivePreset = name;
        }
        finally
        {
            applyingPreset = false;
        }

        SegmentsChanged?.Invoke(this, EventArgs.Empty);
    }

    protected override void OnPropertyChanged(System.ComponentModel.PropertyChangedEventArgs e)
    {
        ArgumentNullException.ThrowIfNull(e);
        base.OnPropertyChanged(e);
        if (applyingPreset || e.PropertyName == nameof(ActivePreset))
        {
            return;
        }

        ActivePreset = null;
        if (e.PropertyName == nameof(DragonSegments))
        {
            SegmentsChanged?.Invoke(this, EventArgs.Empty);
        }
    }

    private void Reset()
    {
        DragonSegments = 60;
        DragonSpeed = 0.18;
        DragonScale = 1;
        ShowWings = true;
        ShowSpines = true;
        PushForce = 6;
        SpringStrength = 0.015;
        Damping = 0.93;
        BurnGravity = 0.8;
        FireRadius = 120;
        FireForce = 25;
        ScreenShake = true;
        ShowEmbers = true;
        ShowParticles = true;
        ShowRunes = true;
        ShowCursor = true;
        TextOpacity = 1;
        ShowEnemies = true;
        EnemyCount = 8;
        EnemySpeed = 0.6;
    }
}
