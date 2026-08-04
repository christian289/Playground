using System.Windows.Media.TextFormatting;

namespace Pretext.Wpf;

/// <summary>
/// <see cref="TextSource"/> over a single, unstyled string: the entire span shares one
/// <see cref="TextRunProperties"/> instance. Adapted from the WPF-Samples PerMonitorDPI sample's
/// CustomTextSource, simplified for measurement (no live-editable text, no per-run styling).
/// Cheap to construct — a fresh instance is created per <c>MeasureSegment</c> call rather than
/// mutated and reused, which keeps it trivially correct under concurrent callers.
/// </summary>
internal sealed class PlainTextSource : TextSource
{
    private readonly string text;
    private readonly TextRunProperties runProperties;

    public PlainTextSource(string text, TextRunProperties runProperties)
    {
        ArgumentNullException.ThrowIfNull(text);
        ArgumentNullException.ThrowIfNull(runProperties);

        this.text = text;
        this.runProperties = runProperties;
        PixelsPerDip = runProperties.PixelsPerDip;
    }

    public override TextRun GetTextRun(int textSourceCharacterIndex)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(textSourceCharacterIndex);

        if (textSourceCharacterIndex >= text.Length)
        {
            return new TextEndOfParagraph(1);
        }

        return new TextCharacters(text, textSourceCharacterIndex, text.Length - textSourceCharacterIndex, runProperties);
    }

    public override TextSpan<CultureSpecificCharacterBufferRange> GetPrecedingText(int textSourceCharacterIndexLimit)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(textSourceCharacterIndexLimit);

        int limit = Math.Min(textSourceCharacterIndexLimit, text.Length);
        CharacterBufferRange range = new(text, 0, limit);
        return new TextSpan<CultureSpecificCharacterBufferRange>(
            limit,
            new CultureSpecificCharacterBufferRange(runProperties.CultureInfo, range));
    }

    public override int GetTextEffectCharacterIndexFromTextSourceCharacterIndex(int textSourceCharacterIndex)
    {
        // No text-effect index space distinct from the source: identity mapping is the minimal
        // correct implementation when GetTextRun never emits a TextEffectCollection.
        return textSourceCharacterIndex;
    }
}
