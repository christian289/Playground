using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Windows;
using System.Windows.Media;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Parity;

public sealed record ParityLine(string Text, double Width);

public sealed record ParityOptions(string? WhiteSpace, string? WordBreak, double? LetterSpacing);

public sealed record ParityCase(
    string Label,
    string Text,
    double Size,
    double Width,
    ParityOptions? Options,
    IReadOnlyList<ParityLine> Lines);

public sealed record RichParityItem(
    string Text,
    double Size,
    double? LetterSpacing,
    [property: JsonPropertyName("break")] string? Break,
    double? ExtraWidth);

public sealed record RichParityFragment(int ItemIndex, string Text, double GapBefore, double OccupiedWidth);

public sealed record RichParityLine(double Width, IReadOnlyList<RichParityFragment> Fragments);

public sealed record RichParityCase(
    string Label,
    IReadOnlyList<RichParityItem> Items,
    double Width,
    int LineCount,
    double MaxLineWidth,
    IReadOnlyList<RichParityLine> Lines);

/// <summary>
/// Differential regression against upstream pretext. The fixtures are the real output of
/// upstream's TypeScript engine over its own corpus, captured with the deterministic fake
/// canvas backend (regenerate with <c>tools/parity/generate.ts</c>). Both sides measure
/// identically, so any mismatch here is a line-breaking divergence introduced by the port.
/// </summary>
public sealed class UpstreamParityTests
{
    private const double WidthTolerance = 1e-6;

    private static readonly JsonSerializerOptions FixtureJson = new() { PropertyNameCaseInsensitive = true };

    [Fact]
    [Trait("Category", "Boundary")]
    public void Layout_UpstreamCorpus_MatchesUpstreamLineBreaking()
    {
        IReadOnlyList<ParityCase> cases = Load<List<ParityCase>>("upstream-parity-corpus.json");
        Assert.NotEmpty(cases);

        StringBuilder failures = new();
        foreach (ParityCase expected in cases)
        {
            PrepareOptions options = new(
                expected.Options?.WhiteSpace == "pre-wrap" ? WhiteSpaceMode.PreWrap : WhiteSpaceMode.Normal,
                expected.Options?.WordBreak == "keep-all" ? WordBreakMode.KeepAll : WordBreakMode.Normal,
                expected.Options?.LetterSpacing ?? 0);

            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments(
                expected.Text,
                new CanvasParityMeasurer(expected.Size),
                CultureInfo.InvariantCulture,
                options);
            LayoutLinesResult actual = TextLayoutEngine.LayoutWithLines(prepared, expected.Width, expected.Size * 1.2);

            string context = $"{expected.Label} @ {expected.Size}px / {expected.Width}px";
            if (actual.LineCount != expected.Lines.Count || actual.Lines.Count != expected.Lines.Count)
            {
                failures.AppendLine(CultureInfo.InvariantCulture,
                    $"{context}: expected {expected.Lines.Count} lines, got {actual.LineCount}");
                continue;
            }

            for (int index = 0; index < expected.Lines.Count; index++)
            {
                ParityLine expectedLine = expected.Lines[index];
                LayoutLine actualLine = actual.Lines[index];
                if (!string.Equals(actualLine.Text, expectedLine.Text, StringComparison.Ordinal))
                {
                    failures.AppendLine(CultureInfo.InvariantCulture,
                        $"{context} line {index}: expected '{expectedLine.Text}', got '{actualLine.Text}'");
                }
                else if (Math.Abs(actualLine.Width - expectedLine.Width) > WidthTolerance)
                {
                    failures.AppendLine(CultureInfo.InvariantCulture,
                        $"{context} line {index}: expected width {expectedLine.Width}, got {actualLine.Width}");
                }
            }
        }

        Assert.Equal(string.Empty, failures.ToString());
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void RichInline_UpstreamCorpus_MatchesUpstreamFragments()
    {
        IReadOnlyList<RichParityCase> cases = Load<List<RichParityCase>>("upstream-rich-corpus.json");
        Assert.NotEmpty(cases);

        StringBuilder failures = new();
        foreach (RichParityCase expected in cases)
        {
            List<RichInlineItem> items = new(expected.Items.Count);
            foreach (RichParityItem item in expected.Items)
            {
                items.Add(new RichInlineItem(
                    item.Text,
                    CreateStyle(item.Size),
                    item.Break == "never" ? RichInlineBreakMode.Never : RichInlineBreakMode.Normal,
                    item.ExtraWidth ?? 0,
                    item.LetterSpacing ?? 0));
            }

            PreparedRichInline prepared = RichInlineLayoutEngine.Prepare(
                items,
                style => new CanvasParityMeasurer(style.FontSize));

            List<RichInlineLine> actualLines = [];
            int lineCount = RichInlineLayoutEngine.WalkLineRanges(
                prepared,
                expected.Width,
                range => actualLines.Add(RichInlineLayoutEngine.MaterializeLineRange(prepared, range)));
            RichInlineStats stats = RichInlineLayoutEngine.MeasureStats(prepared, expected.Width);

            string context = $"{expected.Label} @ {expected.Width}px";
            if (lineCount != expected.LineCount || actualLines.Count != expected.Lines.Count)
            {
                failures.AppendLine(CultureInfo.InvariantCulture,
                    $"{context}: expected {expected.LineCount} lines, got {lineCount}");
                continue;
            }

            if (stats.LineCount != expected.LineCount
                || Math.Abs(stats.MaxLineWidth - expected.MaxLineWidth) > WidthTolerance)
            {
                failures.AppendLine(CultureInfo.InvariantCulture,
                    $"{context}: stats mismatch, expected {expected.LineCount} lines / max {expected.MaxLineWidth}, got {stats.LineCount} / {stats.MaxLineWidth}");
            }

            for (int index = 0; index < expected.Lines.Count; index++)
            {
                RichParityLine expectedLine = expected.Lines[index];
                RichInlineLine actualLine = actualLines[index];
                if (Math.Abs(actualLine.Width - expectedLine.Width) > WidthTolerance
                    || actualLine.Fragments.Count != expectedLine.Fragments.Count)
                {
                    failures.AppendLine(CultureInfo.InvariantCulture,
                        $"{context} line {index}: expected width {expectedLine.Width} with {expectedLine.Fragments.Count} fragments, got {actualLine.Width} with {actualLine.Fragments.Count}");
                    continue;
                }

                for (int f = 0; f < expectedLine.Fragments.Count; f++)
                {
                    RichParityFragment expectedFragment = expectedLine.Fragments[f];
                    RichInlineFragment actualFragment = actualLine.Fragments[f];
                    if (actualFragment.ItemIndex != expectedFragment.ItemIndex
                        || !string.Equals(actualFragment.Text, expectedFragment.Text, StringComparison.Ordinal)
                        || Math.Abs(actualFragment.GapBefore - expectedFragment.GapBefore) > WidthTolerance
                        || Math.Abs(actualFragment.OccupiedWidth - expectedFragment.OccupiedWidth) > WidthTolerance)
                    {
                        failures.AppendLine(CultureInfo.InvariantCulture,
                            $"{context} line {index} fragment {f}: expected #{expectedFragment.ItemIndex} '{expectedFragment.Text}' gap {expectedFragment.GapBefore} width {expectedFragment.OccupiedWidth}, got #{actualFragment.ItemIndex} '{actualFragment.Text}' gap {actualFragment.GapBefore} width {actualFragment.OccupiedWidth}");
                    }
                }
            }
        }

        Assert.Equal(string.Empty, failures.ToString());
    }

    private static TextStyle CreateStyle(double fontSize)
    {
        return new TextStyle(
            new FontFamily("Segoe UI"),
            fontSize,
            FontWeights.Normal,
            FontStyles.Normal,
            FontStretches.Normal,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            1,
            TextFormattingMode.Ideal);
    }

    private static T Load<T>(string fileName)
    {
        return JsonSerializer.Deserialize<T>(
            File.ReadAllText(TestDataPaths.Resolve(fileName)),
            FixtureJson)!;
    }
}
