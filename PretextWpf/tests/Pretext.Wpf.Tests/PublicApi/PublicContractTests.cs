using System.Globalization;
using System.Windows;
using System.Windows.Media;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.PublicApi;

public sealed class PublicContractTests
{
    [Fact]
    [Trait("Category", "Error")]
    public void TextStyle_NullReferences_ThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => new TextStyle(
            null!,
            16,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            1,
            TextFormattingMode.Ideal));
        Assert.Throws<ArgumentNullException>(() => new TextStyle(
            new FontFamily("Segoe UI"),
            16,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            null!,
            FlowDirection.LeftToRight,
            1,
            TextFormattingMode.Ideal));
    }

    [Fact]
    [Trait("Category", "Error")]
    public void TextStyle_InvalidNumbers_ThrowsArgumentOutOfRangeException()
    {
        foreach (double invalid in new[] { 0, -1, double.NaN, double.PositiveInfinity, double.NegativeInfinity })
        {
            Assert.Throws<ArgumentOutOfRangeException>(() => CreateStyle(fontSize: invalid));
            Assert.Throws<ArgumentOutOfRangeException>(() => CreateStyle(pixelsPerDip: invalid));
        }
    }

    [Fact]
    [Trait("Category", "Error")]
    public void TextStyle_UndefinedEnums_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CreateStyle(flowDirection: (FlowDirection)int.MaxValue));
        Assert.Throws<ArgumentOutOfRangeException>(() => CreateStyle(formattingMode: (TextFormattingMode)int.MaxValue));
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void TextStyle_MutableCulture_StoresReadOnlyClone()
    {
        CultureInfo culture = new("en-US");
        TextStyle style = CreateStyle(culture: culture);
        string originalPattern = style.Culture.DateTimeFormat.ShortDatePattern;

        culture.DateTimeFormat.ShortDatePattern = "yyyy/MM/dd";

        Assert.NotSame(culture, style.Culture);
        Assert.True(style.Culture.IsReadOnly);
        Assert.Equal(originalPattern, style.Culture.DateTimeFormat.ShortDatePattern);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void TextStyle_NeutralAndInvariantCultures_PreservesCultureIdentity()
    {
        TextStyle neutral = CreateStyle(culture: new CultureInfo("en"));
        TextStyle invariant = CreateStyle(culture: CultureInfo.InvariantCulture);

        Assert.Equal("en", neutral.Culture.Name);
        Assert.True(neutral.Culture.IsNeutralCulture);
        Assert.Equal(string.Empty, invariant.Culture.Name);
    }

    [Fact]
    [Trait("Category", "Error")]
    public void PrepareOptions_InvalidValues_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new PrepareOptions((WhiteSpaceMode)int.MaxValue));
        Assert.Throws<ArgumentOutOfRangeException>(() => new PrepareOptions(wordBreak: (WordBreakMode)int.MaxValue));
        Assert.Throws<ArgumentOutOfRangeException>(() => new PrepareOptions(letterSpacing: double.NaN));
        Assert.Throws<ArgumentOutOfRangeException>(() => new PrepareOptions(letterSpacing: double.PositiveInfinity));
        Assert.Throws<ArgumentOutOfRangeException>(() => new PrepareOptions(letterSpacing: double.NegativeInfinity));

        Assert.Equal(-2, new PrepareOptions(letterSpacing: -2).LetterSpacing);
        Assert.Equal(0, default(PrepareOptions).LetterSpacing);
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void LayoutModels_ValueContracts_AreValueTypes()
    {
        Assert.True(typeof(LayoutCursor).IsValueType);
        Assert.True(typeof(LayoutResult).IsValueType);
        Assert.True(typeof(LineStats).IsValueType);
        Assert.True(typeof(LayoutLineRange).IsValueType);
        Assert.True(typeof(RichInlineCursor).IsValueType);
        Assert.True(typeof(RichInlineFragmentRange).IsValueType);
        Assert.True(typeof(RichInlineStats).IsValueType);
    }

    [Fact]
    [Trait("Category", "Error")]
    public void RichInlineItem_InvalidValues_ThrowsArgumentOutOfRangeException()
    {
        TextStyle style = CreateStyle();

        Assert.Throws<ArgumentNullException>(() => new RichInlineItem(null!, style));
        Assert.Throws<ArgumentNullException>(() => new RichInlineItem("text", null!));
        Assert.Throws<ArgumentOutOfRangeException>(() => new RichInlineItem("text", style, (RichInlineBreakMode)int.MaxValue));

        foreach (double invalid in new[] { -1, double.NaN, double.PositiveInfinity, double.NegativeInfinity })
        {
            Assert.Throws<ArgumentOutOfRangeException>(() => new RichInlineItem("text", style, extraWidth: invalid));
        }

        Assert.Throws<ArgumentOutOfRangeException>(() => new RichInlineItem("text", style, letterSpacing: double.NaN));
        Assert.Throws<ArgumentOutOfRangeException>(() => new RichInlineItem("text", style, letterSpacing: double.PositiveInfinity));
        Assert.Equal(-1, new RichInlineItem("text", style, letterSpacing: -1).LetterSpacing);
    }

    private static TextStyle CreateStyle(
        FontFamily? fontFamily = null,
        double fontSize = 16,
        CultureInfo? culture = null,
        FlowDirection flowDirection = FlowDirection.LeftToRight,
        double pixelsPerDip = 1,
        TextFormattingMode formattingMode = TextFormattingMode.Ideal)
    {
        return new TextStyle(
            fontFamily ?? new FontFamily("Segoe UI"),
            fontSize,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            culture ?? CultureInfo.GetCultureInfo("en-US"),
            flowDirection,
            pixelsPerDip,
            formattingMode);
    }
}
