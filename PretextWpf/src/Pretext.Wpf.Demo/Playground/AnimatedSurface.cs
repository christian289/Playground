using System.Windows;
using System.Windows.Input;
using System.Windows.Media;

namespace Pretext.Wpf.Demo.Playground;

/// <summary>
/// requestAnimationFrame equivalent: subscribes to CompositionTarget.Rendering while
/// loaded and visible, tracks elapsed/delta time (delta clamped to 50 ms like the
/// upstream loops), exposes the mouse position, and repaints every frame.
/// </summary>
internal abstract class AnimatedSurface : FrameworkElement
{
    private static readonly SolidColorBrush BackgroundBrush = CreateFrozen(0xFF, 0x0A, 0x0A, 0x0A);

    private bool running;
    private bool hasLastRenderingTime;
    private TimeSpan lastRenderingTime;
    private double statsTimer;
    private int statsFrames;
    private int fps;

    protected AnimatedSurface()
    {
        Loaded += (_, _) => UpdateRunning();
        Unloaded += (_, _) => UpdateRunning();
        IsVisibleChanged += (_, _) => UpdateRunning();
    }

    internal event EventHandler? StatsUpdated;

    /// <summary>Seconds since the surface started animating (the upstream scenes' <c>t</c>).</summary>
    protected double Time { get; private set; }

    protected Point Mouse { get; private set; } = new(double.NaN, double.NaN);

    protected bool IsPointerDown { get; private set; }

    internal int Fps => fps;

    protected double SurfaceWidth => ActualWidth;

    protected double SurfaceHeight => ActualHeight;

    protected Point MouseOrCenter =>
        double.IsNaN(Mouse.X) ? new Point(ActualWidth / 2, ActualHeight / 2) : Mouse;

    protected static SolidColorBrush CreateFrozen(byte a, byte r, byte g, byte b)
    {
        SolidColorBrush brush = new(Color.FromArgb(a, r, g, b));
        brush.Freeze();
        return brush;
    }

    protected abstract void Step(double dt);

    protected abstract void Draw(DrawingContext dc);

    protected virtual void OnPointerPressed()
    {
    }

    protected virtual void OnPointerReleased()
    {
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        ArgumentNullException.ThrowIfNull(drawingContext);
        base.OnRender(drawingContext);
        if (ActualWidth <= 0 || ActualHeight <= 0)
        {
            return;
        }

        Rect bounds = new(0, 0, ActualWidth, ActualHeight);
        drawingContext.PushClip(new RectangleGeometry(bounds));
        drawingContext.DrawRectangle(BackgroundBrush, null, bounds);
        Draw(drawingContext);
        drawingContext.Pop();
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        ArgumentNullException.ThrowIfNull(e);
        base.OnMouseMove(e);
        Mouse = e.GetPosition(this);
    }

    protected override void OnMouseDown(MouseButtonEventArgs e)
    {
        ArgumentNullException.ThrowIfNull(e);
        base.OnMouseDown(e);
        IsPointerDown = true;
        CaptureMouse();
        OnPointerPressed();
    }

    protected override void OnMouseUp(MouseButtonEventArgs e)
    {
        ArgumentNullException.ThrowIfNull(e);
        base.OnMouseUp(e);
        IsPointerDown = false;
        ReleaseMouseCapture();
        OnPointerReleased();
    }

    private void UpdateRunning()
    {
        bool shouldRun = IsLoaded && IsVisible;
        if (shouldRun == running)
        {
            return;
        }

        running = shouldRun;
        if (shouldRun)
        {
            hasLastRenderingTime = false;
            CompositionTarget.Rendering += OnRendering;
        }
        else
        {
            CompositionTarget.Rendering -= OnRendering;
            IsPointerDown = false;
        }
    }

    private void OnRendering(object? sender, EventArgs e)
    {
        TimeSpan renderingTime = ((RenderingEventArgs)e).RenderingTime;
        if (!hasLastRenderingTime)
        {
            hasLastRenderingTime = true;
            lastRenderingTime = renderingTime;
            return;
        }

        if (renderingTime == lastRenderingTime)
        {
            return;
        }

        double dt = Math.Min((renderingTime - lastRenderingTime).TotalSeconds, 0.05);
        lastRenderingTime = renderingTime;
        Time += dt;

        statsFrames++;
        statsTimer += dt;
        if (statsTimer >= 0.5)
        {
            fps = (int)Math.Round(statsFrames / statsTimer);
            statsFrames = 0;
            statsTimer = 0;
            StatsUpdated?.Invoke(this, EventArgs.Empty);
        }

        Step(dt);
        InvalidateVisual();
    }
}
