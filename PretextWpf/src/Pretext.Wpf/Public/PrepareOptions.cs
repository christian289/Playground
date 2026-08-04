namespace Pretext.Wpf;

public enum WhiteSpaceMode
{
    Normal,
    PreWrap,
}

public enum WordBreakMode
{
    Normal,
    KeepAll,
}

public readonly record struct PrepareOptions
{
    public PrepareOptions(
        WhiteSpaceMode whiteSpace = WhiteSpaceMode.Normal,
        WordBreakMode wordBreak = WordBreakMode.Normal,
        double letterSpacing = 0)
    {
        WhiteSpace = Guard.DefinedEnum(whiteSpace, nameof(whiteSpace));
        WordBreak = Guard.DefinedEnum(wordBreak, nameof(wordBreak));
        LetterSpacing = Guard.Finite(letterSpacing, nameof(letterSpacing));
    }

    public WhiteSpaceMode WhiteSpace { get; }

    public WordBreakMode WordBreak { get; }

    public double LetterSpacing { get; }
}
