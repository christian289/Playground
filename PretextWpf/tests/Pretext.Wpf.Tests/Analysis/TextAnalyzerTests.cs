using System.Globalization;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Analysis;

public sealed class TextAnalyzerTests
{
    [Theory]
    [InlineData("  hello\t\n world  ", "hello world")]
    [InlineData("a   b", "a b")]
    [Trait("Category", "Happy")]
    public void Analyze_NormalWhitespace_CollapsesLikeCss(string input, string expected)
    {
        TextAnalysis result = Analyze(input);

        Assert.Equal(expected, result.Normalized);
        Assert.Equal(expected, string.Concat(result.Texts));
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Analyze_PreWrap_PreservesSpacesTabsAndHardBreaks()
    {
        TextAnalysis result = TextAnalyzer.Analyze(
            " a  b\r\nc\ta ",
            CultureInfo.GetCultureInfo("en-US"),
            WhiteSpaceMode.PreWrap,
            WordBreakMode.Normal);

        Assert.Equal(" a  b\nc\ta ", result.Normalized);
        Assert.Contains(SegmentBreakKind.PreservedSpace, result.Kinds);
        Assert.Contains(SegmentBreakKind.HardBreak, result.Kinds);
        Assert.Contains(SegmentBreakKind.Tab, result.Kinds);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Analyze_SpecialBreakCharacters_PreservesKinds()
    {
        TextAnalysis result = Analyze("foo\u200Bbar extra\u00ADordinary");

        Assert.Contains(SegmentBreakKind.ZeroWidthBreak, result.Kinds);
        Assert.Contains(SegmentBreakKind.SoftHyphen, result.Kinds);
        Assert.Equal(result.Normalized, string.Concat(result.Texts));
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Analyze_CjkLatinAndNumbers_PreservesOrderedSegments()
    {
        TextAnalysis result = Analyze("你好，world 42");

        Assert.Equal(result.Normalized, string.Concat(result.Texts));
        Assert.Contains(result.Texts, text => text.Contains('你'));
        Assert.Contains(result.Texts, text => text.Contains('好'));
        Assert.Contains(result.Texts, text => text.Contains("world", StringComparison.Ordinal));
        Assert.Contains(result.Texts, text => text.Contains("42", StringComparison.Ordinal));
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Analyze_ThaiText_MarksNativeWordBreakRun()
    {
        TextAnalysis result = TextAnalyzer.Analyze(
            "ภาษาไทย",
            CultureInfo.GetCultureInfo("th-TH"),
            WhiteSpaceMode.Normal,
            WordBreakMode.Normal);

        NativeWordBreakRun run = Assert.Single(result.NativeWordBreakRuns);
        Assert.Equal(0, run.Start);
        Assert.Equal(result.Normalized.Length, run.Length);
        Assert.True(new GraphemeMap(result.Normalized).Count > 1);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Analyze_KeepAllHangul_DoesNotSplitHangulRun()
    {
        TextAnalysis result = TextAnalyzer.Analyze(
            "한글 ABC 123",
            CultureInfo.GetCultureInfo("ko-KR"),
            WhiteSpaceMode.Normal,
            WordBreakMode.KeepAll);

        Assert.Contains("한글", result.Texts);
        Assert.DoesNotContain("한", result.Texts);
        Assert.DoesNotContain("글", result.Texts);
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void GraphemeMap_CombiningAndZwjSequences_DoesNotSplitClusters()
    {
        GraphemeMap map = new("A\u0301👨‍👩‍👧‍👦");

        Assert.Equal(2, map.Count);
        Assert.Equal("A\u0301", map.GetTextElement(0));
        Assert.Equal("👨‍👩‍👧‍👦", map.GetTextElement(1));
        Assert.Equal("A\u0301", map.GetPrefixText(1));
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void Analyze_RepeatedRequest_UsesImmutableCacheUntilClear()
    {
        CultureInfo culture = CultureInfo.GetCultureInfo("en-US");
        TextAnalysis first = TextAnalyzer.Analyze("cache me", culture, WhiteSpaceMode.Normal, WordBreakMode.Normal);
        TextAnalysis second = TextAnalyzer.Analyze("cache me", culture, WhiteSpaceMode.Normal, WordBreakMode.Normal);

        Assert.Same(first, second);

        TextAnalyzer.ClearCache();
        TextAnalysis afterClear = TextAnalyzer.Analyze("cache me", culture, WhiteSpaceMode.Normal, WordBreakMode.Normal);
        Assert.NotSame(first, afterClear);
    }

    private static TextAnalysis Analyze(string text)
    {
        return TextAnalyzer.Analyze(
            text,
            CultureInfo.GetCultureInfo("en-US"),
            WhiteSpaceMode.Normal,
            WordBreakMode.Normal);
    }
}
