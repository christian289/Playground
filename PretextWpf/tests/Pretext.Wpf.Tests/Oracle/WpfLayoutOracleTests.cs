using System.Globalization;
using System.Runtime.ExceptionServices;
using System.Text;
using System.Threading;
using System.Windows;
using System.Windows.Media;
using Pretext.Wpf;

namespace Pretext.Wpf.Tests.Oracle;

/// <summary>
/// Oracle tests that drive the real <see cref="TextLayoutEngine"/> public API
/// (real WPF measurement, not the deterministic fake) against the shared
/// Unicode corpus and assert structural invariants rather than exact pixel
/// values, since real glyph metrics are WPF/font-version dependent. STA-only:
/// WPF's text formatter is apartment-threaded, so these only execute on
/// Windows, but the file must compile everywhere.
/// </summary>
public sealed class WpfLayoutOracleTests
{
    private const double LineHeight = 19;

    [Fact]
    [Trait("Category", "Happy")]
    public void Oracle_RepresentativeCorpus_MatchesWpfLayout()
    {
        StaThread.Run(() =>
        {
            LayoutCorpus corpus = LayoutCorpusLoader.Load();
            List<LayoutCorpusText> latinTexts = [.. corpus.Texts.Where(entry => entry.Label.StartsWith("Latin", StringComparison.Ordinal))];
            Assert.Equal(6, latinTexts.Count);

            (double size, double width)[] combos =
            [
                (corpus.Sizes[0], corpus.Widths[1]),
                (corpus.Sizes[4], corpus.Widths[5]),
            ];

            foreach (LayoutCorpusText entry in latinTexts)
            {
                foreach ((double size, double width) in combos)
                {
                    AssertOracleInvariants(entry.Text, size, width);
                }

                AssertMonotonicLineCounts(entry.Text, corpus.Sizes[0], corpus.Widths);
            }
        });
    }

    [Fact]
    [Trait("Category", "Boundary")]
    public void Oracle_UnicodeCorpus_MatchesWpfLayout()
    {
        StaThread.Run(() =>
        {
            LayoutCorpus corpus = LayoutCorpusLoader.Load();
            (double size, double width)[] combos =
            [
                (corpus.Sizes[0], corpus.Widths[1]),
                (corpus.Sizes[3], corpus.Widths[4]),
            ];

            foreach (LayoutCorpusText entry in corpus.Texts)
            {
                foreach ((double size, double width) in combos)
                {
                    AssertOracleInvariants(entry.Text, size, width);
                }

                AssertMonotonicLineCounts(entry.Text, corpus.Sizes[3], corpus.Widths);
            }
        });
    }

    private static void AssertOracleInvariants(string text, double fontSize, double maxWidth)
    {
        TextStyle style = CreateStyle(fontSize);
        PreparedTextWithSegments prepared = TextLayoutEngine.PrepareWithSegments(text, style);

        LayoutLinesResult lines = TextLayoutEngine.LayoutWithLines(prepared, maxWidth, LineHeight);
        LayoutResult plain = TextLayoutEngine.Layout(prepared, maxWidth, LineHeight);
        int walkedCount = TextLayoutEngine.WalkLineRanges(prepared, maxWidth, static (in LayoutLineRange _) => { });

        // (c) line count agrees across every counting API.
        Assert.Equal(plain.LineCount, lines.LineCount);
        Assert.Equal(plain.LineCount, walkedCount);

        TextAnalysis analysis = TextAnalyzer.Analyze(text, style.Culture, WhiteSpaceMode.Normal, WordBreakMode.Normal);
        StringBuilder reconstructed = new();

        for (int index = 0; index < lines.Lines.Count; index++)
        {
            LayoutLine line = lines.Lines[index];
            bool isLastLine = index == lines.Lines.Count - 1;

            // (a) every non-forced line fits, or is a single grapheme/segment that
            // could not have been split any further (legitimate overflow).
            Assert.True(
                line.Width <= maxWidth + 0.01 || IsSingleUnbreakableUnit(line),
                $"line '{line.Text}' (width {line.Width}) exceeds maxWidth {maxWidth} at size {fontSize} and is not a single unbreakable unit.");

            string lineText = line.Text.TrimEnd(' ');
            if (!isLastLine && lineText.Length > 0 && lineText[^1] == '-')
            {
                lineText = lineText[..^1];
            }

            reconstructed.Append(lineText);
        }

        // (b) reconstructing every line (soft-hyphen '-' removed, hanging trailing
        // spaces trimmed) reproduces the normalized source text.
        Assert.Equal(analysis.Normalized, reconstructed.ToString());
    }

    private static void AssertMonotonicLineCounts(string text, double fontSize, IReadOnlyList<int> widths)
    {
        TextStyle style = CreateStyle(fontSize);
        PreparedText prepared = TextLayoutEngine.Prepare(text, style);

        int previousLineCount = int.MaxValue;
        foreach (int width in widths)
        {
            int lineCount = TextLayoutEngine.Layout(prepared, width, LineHeight).LineCount;

            // (d) line count is non-increasing as width grows, for the same size.
            Assert.True(
                lineCount <= previousLineCount,
                $"line count grew from {previousLineCount} to {lineCount} as width increased to {width} at size {fontSize}.");
            previousLineCount = lineCount;
        }
    }

    private static bool IsSingleUnbreakableUnit(LayoutLine line)
    {
        LayoutCursor start = line.Start;
        LayoutCursor end = line.End;
        if (start.SegmentIndex == end.SegmentIndex)
        {
            return end.GraphemeIndex - start.GraphemeIndex <= 1;
        }

        return end.SegmentIndex - start.SegmentIndex == 1 && start.GraphemeIndex == 0 && end.GraphemeIndex == 0;
    }

    private static TextStyle CreateStyle(double fontSize) => new(
        new FontFamily("Segoe UI"),
        fontSize,
        FontWeights.Normal,
        FontStyles.Normal,
        FontStretches.Normal,
        CultureInfo.GetCultureInfo("en-US"),
        FlowDirection.LeftToRight,
        pixelsPerDip: 1,
        TextFormattingMode.Ideal);

    /// <summary>
    /// Mirrors <c>WpfTextMeasurerTests.StaThread</c>: WPF's text formatter is
    /// apartment-threaded, so real-measurement tests cannot run inline on the
    /// ambient xunit worker thread.
    /// </summary>
    private static class StaThread
    {
        internal static void Run(Action action)
        {
            ExceptionDispatchInfo? capturedException = null;
            Thread thread = new(() =>
            {
                try
                {
                    action();
                }
                catch (Exception exception)
                {
                    capturedException = ExceptionDispatchInfo.Capture(exception);
                }
            });
            thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
            thread.Join();
            capturedException?.Throw();
        }
    }
}
