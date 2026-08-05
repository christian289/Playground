namespace Pretext.Wpf;

public enum RichInlineBreakMode
{
    Normal,
    Never,
}

public sealed record RichInlineItem
{
    public RichInlineItem(
        string text,
        TextStyle style,
        RichInlineBreakMode breakMode = RichInlineBreakMode.Normal,
        double extraWidth = 0,
        double letterSpacing = 0)
    {
        ArgumentNullException.ThrowIfNull(text);
        ArgumentNullException.ThrowIfNull(style);

        Text = text;
        Style = style;
        BreakMode = Guard.DefinedEnum(breakMode, nameof(breakMode));
        ExtraWidth = Guard.NonNegativeFinite(extraWidth, nameof(extraWidth));
        LetterSpacing = Guard.Finite(letterSpacing, nameof(letterSpacing));
    }

    public string Text { get; }

    public TextStyle Style { get; }

    public RichInlineBreakMode BreakMode { get; }

    public double ExtraWidth { get; }

    public double LetterSpacing { get; }
}

public readonly record struct RichInlineCursor(
    int ItemIndex,
    int SegmentIndex,
    int GraphemeIndex);

public readonly record struct RichInlineFragmentRange(
    int ItemIndex,
    double GapBefore,
    double OccupiedWidth,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record RichInlineLineRange(
    IReadOnlyList<RichInlineFragmentRange> Fragments,
    double Width,
    RichInlineCursor End);

public sealed record RichInlineFragment(
    int ItemIndex,
    string Text,
    double GapBefore,
    double OccupiedWidth,
    LayoutCursor Start,
    LayoutCursor End);

public sealed record RichInlineLine(
    IReadOnlyList<RichInlineFragment> Fragments,
    double Width,
    RichInlineCursor End);

public readonly record struct RichInlineStats(
    int LineCount,
    double MaxLineWidth);

public delegate void RichInlineLineRangeVisitor(RichInlineLineRange line);
