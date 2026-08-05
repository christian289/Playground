using System.Globalization;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Layout;

/// <summary>
/// Ports a curated subset of upstream pretext's <c>layout.test.ts</c> "prepare
/// invariants" (and a couple of "layout invariants") cases as data-driven pins
/// against the ported <see cref="TextAnalyzer"/>/<see cref="TextLayoutEngine"/>.
/// Each case's expectations were derived by reading the current C# analyzer
/// pipeline (not copied blindly from upstream): where the ported analyzer is an
/// intentional adaptation rather than a literal <c>Intl.Segmenter</c> port, the
/// "upstream" field records the delta. See <c>TestData/upstream-regressions.json</c>
/// for the full case list and the ported-vs-skipped rationale in the task report.
/// </summary>
public sealed class UpstreamRegressionTests
{
    private static readonly CultureInfo Culture = CultureInfo.InvariantCulture;

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    public static IEnumerable<object[]> Cases()
    {
        foreach (RegressionCase testCase in LoadCases())
        {
            yield return [testCase];
        }
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public void Regression_PortedUpstreamCase_MatchesAnalyzerBehavior(RegressionCase testCase)
    {
        WhiteSpaceMode whiteSpace = testCase.Options?.WhiteSpace ?? WhiteSpaceMode.Normal;
        WordBreakMode wordBreak = testCase.Options?.WordBreak ?? WordBreakMode.Normal;
        RegressionExpect expect = testCase.Expect;

        TextAnalysis analysis = TextAnalyzer.Analyze(testCase.Text, Culture, whiteSpace, wordBreak);

        if (expect.Normalized is not null)
        {
            Assert.Equal(expect.Normalized, analysis.Normalized);
        }

        if (expect.Segments is not null)
        {
            Assert.Equal(expect.Segments, analysis.Texts);
        }

        if (expect.Kinds is not null)
        {
            SegmentBreakKind[] expectedKinds = [.. expect.Kinds.Select(name => Enum.Parse<SegmentBreakKind>(name, ignoreCase: true))];
            Assert.Equal(expectedKinds, analysis.Kinds);
        }

        if (expect.Layout is { } layout)
        {
            double letterSpacing = testCase.Options?.LetterSpacing ?? 0;
            PrepareOptions options = new(whiteSpace, wordBreak, letterSpacing);
            PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments(
                testCase.Text, TextLayoutEngineTests.FakeMeasurer.Instance, Culture, options);
            LayoutResult result = TextLayoutEngine.Layout(prepared, layout.MaxWidth, layout.LineHeight);
            Assert.Equal(layout.LineCount, result.LineCount);
        }
    }

    private static List<RegressionCase> LoadCases()
    {
        string path = Path.Combine(AppContext.BaseDirectory, "TestData", "upstream-regressions.json");
        string json = File.ReadAllText(path);
        RegressionFile? file = JsonSerializer.Deserialize<RegressionFile>(json, JsonOptions);
        return file?.Cases ?? throw new InvalidOperationException($"Failed to deserialize regression corpus at '{path}'.");
    }

    private sealed class RegressionFile
    {
        public string Measurer { get; init; } = "";

        public List<RegressionCase> Cases { get; init; } = [];
    }

    public sealed class RegressionCase
    {
        public string Id { get; init; } = "";

        public string Text { get; init; } = "";

        public RegressionOptions? Options { get; init; }

        public RegressionExpect Expect { get; init; } = new();

        public string Upstream { get; init; } = "";

        public override string ToString() => Id;
    }

    public sealed class RegressionOptions
    {
        public WhiteSpaceMode WhiteSpace { get; init; } = WhiteSpaceMode.Normal;

        public WordBreakMode WordBreak { get; init; } = WordBreakMode.Normal;

        public double LetterSpacing { get; init; }
    }

    public sealed class RegressionExpect
    {
        public string? Normalized { get; init; }

        public List<string>? Segments { get; init; }

        public List<string>? Kinds { get; init; }

        public RegressionLayoutExpect? Layout { get; init; }
    }

    public sealed class RegressionLayoutExpect
    {
        public double MaxWidth { get; init; }

        public double LineHeight { get; init; } = 19;

        public int LineCount { get; init; }
    }
}
