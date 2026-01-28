namespace WpfAutomationDemo.Controls;

/// <summary>
/// 별점 평가 컨트롤 (접근성 지원)
/// Star rating control with accessibility support
/// </summary>
public sealed class RatingControl : Control
{
    static RatingControl()
    {
        DefaultStyleKeyProperty.OverrideMetadata(
            typeof(RatingControl),
            new FrameworkPropertyMetadata(typeof(RatingControl)));
    }

    #region DependencyProperties

    /// <summary>
    /// 현재 평점 값
    /// Current rating value
    /// </summary>
    public static readonly DependencyProperty ValueProperty =
        DependencyProperty.Register(
            nameof(Value),
            typeof(double),
            typeof(RatingControl),
            new FrameworkPropertyMetadata(
                0.0,
                FrameworkPropertyMetadataOptions.BindsTwoWayByDefault,
                OnValueChanged,
                CoerceValue));

    public double Value
    {
        get => (double)GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }

    /// <summary>
    /// 최대 평점 값
    /// Maximum rating value
    /// </summary>
    public static readonly DependencyProperty MaxValueProperty =
        DependencyProperty.Register(
            nameof(MaxValue),
            typeof(double),
            typeof(RatingControl),
            new FrameworkPropertyMetadata(
                5.0,
                FrameworkPropertyMetadataOptions.AffectsRender,
                OnMaxValueChanged));

    public double MaxValue
    {
        get => (double)GetValue(MaxValueProperty);
        set => SetValue(MaxValueProperty, value);
    }

    #endregion

    #region Property Changed Callbacks

    private static void OnValueChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var control = (RatingControl)d;
        var oldValue = (double)e.OldValue;
        var newValue = (double)e.NewValue;

        // AutomationPeer에 값 변경 알림
        // Notify AutomationPeer of value change
        if (AutomationPeer.ListenerExists(AutomationEvents.PropertyChanged))
        {
            var peer = UIElementAutomationPeer.FromElement(control) as RatingControlAutomationPeer;
            peer?.RaiseValueChangedEvent(oldValue, newValue);
        }

        control.OnValueChanged(oldValue, newValue);
    }

    private static void OnMaxValueChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        d.CoerceValue(ValueProperty);
    }

    private static object CoerceValue(DependencyObject d, object baseValue)
    {
        var control = (RatingControl)d;
        var value = (double)baseValue;
        return Math.Clamp(value, 0.0, control.MaxValue);
    }

    #endregion

    #region Events

    /// <summary>
    /// 값 변경 시 발생
    /// Raised when value changes
    /// </summary>
    public event RoutedPropertyChangedEventHandler<double>? ValueChanged;

    private void OnValueChanged(double oldValue, double newValue)
    {
        ValueChanged?.Invoke(this, new RoutedPropertyChangedEventArgs<double>(oldValue, newValue));
    }

    #endregion

    #region Keyboard Navigation

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);

        double step = 1.0;

        switch (e.Key)
        {
            case Key.Left:
            case Key.Down:
                Value = Math.Max(0, Value - step);
                e.Handled = true;
                break;

            case Key.Right:
            case Key.Up:
                Value = Math.Min(MaxValue, Value + step);
                e.Handled = true;
                break;

            case Key.Home:
                Value = 0;
                e.Handled = true;
                break;

            case Key.End:
                Value = MaxValue;
                e.Handled = true;
                break;
        }
    }

    #endregion

    #region Mouse Interaction

    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        base.OnMouseLeftButtonDown(e);
        Focus();
        UpdateValueFromMouse(e);
        e.Handled = true;
    }

    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);

        if (e.LeftButton == MouseButtonState.Pressed)
        {
            UpdateValueFromMouse(e);
        }
    }

    private void UpdateValueFromMouse(MouseEventArgs e)
    {
        var position = e.GetPosition(this);
        var ratio = Math.Clamp(position.X / ActualWidth, 0, 1);
        Value = Math.Round(ratio * MaxValue);
    }

    #endregion

    #region Automation

    protected override AutomationPeer OnCreateAutomationPeer()
    {
        return new RatingControlAutomationPeer(this);
    }

    #endregion

    #region Converter

    /// <summary>
    /// Value >= ConverterParameter 비교 컨버터
    /// Converter for Value >= ConverterParameter comparison
    /// </summary>
    public static readonly IValueConverter GreaterOrEqualConverter = new GreaterOrEqualValueConverter();

    private sealed class GreaterOrEqualValueConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is double doubleValue && parameter is not null)
            {
                var threshold = System.Convert.ToDouble(parameter, CultureInfo.InvariantCulture);
                return doubleValue >= threshold;
            }
            return false;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotSupportedException();
        }
    }

    #endregion
}
