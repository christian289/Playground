using System.Windows;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Bidi;

public sealed class BidiLevelResolverTests
{
    [Fact]
    [Trait("Category", "Happy")]
    public void ComputeSegmentLevels_PureLatinLtr_ReturnsNullOptimization()
    {
        Assert.Null(BidiLevelResolver.ComputeSegmentLevels("plain text", [0, 5], FlowDirection.LeftToRight));
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void ComputeSegmentLevels_PureLatinRtl_ReturnsExplicitLevels()
    {
        sbyte[]? levels = BidiLevelResolver.ComputeSegmentLevels("plain text", [0, 5], FlowDirection.RightToLeft);

        Assert.NotNull(levels);
        Assert.Equal(2, levels.Length);
        Assert.All(levels, level => Assert.True(level >= 1));
    }

    [Theory]
    [InlineData(FlowDirection.LeftToRight)]
    [InlineData(FlowDirection.RightToLeft)]
    [Trait("Category", "Boundary")]
    public void ComputeSegmentLevels_MixedHebrew_ReturnsOddLevelForHebrewSegment(FlowDirection direction)
    {
        sbyte[]? levels = BidiLevelResolver.ComputeSegmentLevels("hello שלום", [0, 5, 6], direction);

        Assert.NotNull(levels);
        Assert.True((levels[2] & 1) == 1);
        Assert.True((levels[0] & 1) == 0);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void ComputeSegmentLevels_ArabicNumbers_ResolvesArabicContext()
    {
        sbyte[]? levels = BidiLevelResolver.ComputeSegmentLevels("مرحبا 123", [0, 5, 6], FlowDirection.RightToLeft);

        Assert.NotNull(levels);
        Assert.True((levels[0] & 1) == 1);
        Assert.True((levels[2] & 1) == 0);
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void ComputeSegmentLevels_BracketsAndEmoji_PreservesUtf16Offsets()
    {
        sbyte[]? brackets = BidiLevelResolver.ComputeSegmentLevels(
            "abc (שלום) 42",
            [0, 4, 5, 9, 11],
            FlowDirection.LeftToRight);
        sbyte[]? astral = BidiLevelResolver.ComputeSegmentLevels(
            "א😀b",
            [0, 1, 3],
            FlowDirection.RightToLeft);

        Assert.NotNull(brackets);
        Assert.Equal(5, brackets.Length);
        Assert.True((brackets[2] & 1) == 1);
        Assert.NotNull(astral);
        Assert.Equal(3, astral.Length);
        Assert.True((astral[0] & 1) == 1);
        Assert.True((astral[2] & 1) == 0);
    }

    [Fact]
    [Trait("Category", "Error")]
    public void ComputeSegmentLevels_InvalidOffsets_ThrowsArgumentOutOfRangeException()
    {
        Assert.Throws<ArgumentNullException>(() => BidiLevelResolver.ComputeSegmentLevels(null!, [], FlowDirection.LeftToRight));
        Assert.Throws<ArgumentNullException>(() => BidiLevelResolver.ComputeSegmentLevels("text", null!, FlowDirection.LeftToRight));
        Assert.Throws<ArgumentOutOfRangeException>(() => BidiLevelResolver.ComputeSegmentLevels("text", [-1], FlowDirection.LeftToRight));
        Assert.Throws<ArgumentOutOfRangeException>(() => BidiLevelResolver.ComputeSegmentLevels("text", [5], FlowDirection.LeftToRight));
        Assert.Throws<ArgumentException>(() => BidiLevelResolver.ComputeSegmentLevels("text", [2, 1], FlowDirection.LeftToRight));
        Assert.Throws<ArgumentOutOfRangeException>(() => BidiLevelResolver.ComputeSegmentLevels("text", [0], (FlowDirection)int.MaxValue));
    }

    [Fact]
    [Trait("Category", "Happy")]
    public void GeneratedData_CheckedInTables_PreserveSourceShape()
    {
        Assert.Equal(256, BidiData.Latin1BidiTypes.Length);
        Assert.NotEmpty(BidiData.NonLatin1BidiRanges);
        Assert.All(BidiData.NonLatin1BidiRanges, range => Assert.True(range.Start <= range.End));
        for (int index = 1; index < BidiData.NonLatin1BidiRanges.Length; index++)
        {
            Assert.True(BidiData.NonLatin1BidiRanges[index - 1].End < BidiData.NonLatin1BidiRanges[index].Start);
        }
    }
}
