namespace WpfAutomationDemo.Controls;

/// <summary>
/// RatingControl용 AutomationPeer (IRangeValueProvider 구현)
/// AutomationPeer for RatingControl implementing IRangeValueProvider
/// </summary>
public sealed class RatingControlAutomationPeer : FrameworkElementAutomationPeer, IRangeValueProvider
{
    public RatingControlAutomationPeer(RatingControl owner) : base(owner)
    {
    }

    private RatingControl RatingControl => (RatingControl)Owner;

    #region AutomationPeer Overrides

    protected override string GetClassNameCore() => nameof(RatingControl);

    protected override AutomationControlType GetAutomationControlTypeCore()
    {
        return AutomationControlType.Slider;
    }

    protected override string GetNameCore()
    {
        // 스크린 리더가 읽을 이름
        // Name to be read by screen reader
        var customName = AutomationProperties.GetName(RatingControl);
        if (!string.IsNullOrEmpty(customName))
        {
            return customName;
        }

        return $"Rating: {RatingControl.Value} of {RatingControl.MaxValue} stars";
    }

    protected override string GetHelpTextCore()
    {
        var customHelp = AutomationProperties.GetHelpText(RatingControl);
        if (!string.IsNullOrEmpty(customHelp))
        {
            return customHelp;
        }

        return "Use arrow keys to change rating. Left/Down to decrease, Right/Up to increase.";
    }

    public override object GetPattern(PatternInterface patternInterface)
    {
        if (patternInterface == PatternInterface.RangeValue)
        {
            return this;
        }

        return base.GetPattern(patternInterface)!;
    }

    protected override bool IsKeyboardFocusableCore() => true;

    #endregion

    #region IRangeValueProvider Implementation

    public double Value => RatingControl.Value;

    public double Minimum => 0;

    public double Maximum => RatingControl.MaxValue;

    public double SmallChange => 1;

    public double LargeChange => 1;

    public bool IsReadOnly => !RatingControl.IsEnabled;

    public void SetValue(double value)
    {
        if (IsReadOnly)
        {
            throw new ElementNotEnabledException();
        }

        if (value < Minimum || value > Maximum)
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        RatingControl.Value = value;
    }

    #endregion

    #region Event Raising

    /// <summary>
    /// 값 변경 이벤트를 UI Automation에 알림
    /// Raises value changed event to UI Automation
    /// </summary>
    public void RaiseValueChangedEvent(double oldValue, double newValue)
    {
        RaisePropertyChangedEvent(
            RangeValuePatternIdentifiers.ValueProperty,
            oldValue,
            newValue);

        // 이름도 함께 업데이트 (스크린 리더용)
        // Also update name (for screen readers)
        var oldName = $"Rating: {oldValue} of {RatingControl.MaxValue} stars";
        var newName = $"Rating: {newValue} of {RatingControl.MaxValue} stars";

        RaisePropertyChangedEvent(
            AutomationElementIdentifiers.NameProperty,
            oldName,
            newName);
    }

    #endregion
}
