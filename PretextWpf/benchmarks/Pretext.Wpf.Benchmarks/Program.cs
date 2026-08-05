using System.Globalization;
using System.Windows;
using System.Windows.Media;
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;
using Pretext.Wpf;

namespace Pretext.Wpf.Benchmarks;

/// <summary>
/// The library's premise: pay shaping cost once in <c>Prepare</c>, then relayout at any
/// width with pure arithmetic. These benchmarks measure both halves, and the layout half
/// is expected to allocate zero bytes.
/// </summary>
[MemoryDiagnoser]
public class LayoutBenchmarks
{
    private const string Paragraph =
        "Just tried the new update and it's so much better. The performance improvements " +
        "are really noticeable, especially on older devices. The key insight is that you " +
        "can cache word measurements separately from layout results.";

    private const string MultiScript =
        "Hello مرحبا שלום 你好 こんにちは 안녕하세요 — a greeting in six scripts, plus 42.99 numerals.";

    private PreparedText prepared = null!;
    private PreparedTextWithSegments preparedWithSegments = null!;
    private PreparedTextWithSegments preparedMultiScript = null!;
    private PreparedRichInline preparedRichInline = null!;
    private TextStyle style = null!;

    [Params(240d, 480d, 960d)]
    public double MaxWidth { get; set; }

    /// <summary>
    /// Shaping runs on an STA thread because WPF's text formatter is apartment-threaded.
    /// Everything measured afterwards is arithmetic over the cached widths, so the
    /// benchmark methods themselves have no apartment requirement.
    /// </summary>
    [GlobalSetup]
    public void Setup()
    {
        RunOnStaThread(() =>
        {
            style = new TextStyle(
                new FontFamily("Segoe UI"),
                16,
                FontWeights.Normal,
                FontStyles.Normal,
                FontStretches.Normal,
                CultureInfo.GetCultureInfo("en-US"),
                FlowDirection.LeftToRight,
                1,
                TextFormattingMode.Ideal);

            prepared = TextLayoutEngine.Prepare(Paragraph, style);
            preparedWithSegments = TextLayoutEngine.PrepareWithSegments(Paragraph, style);
            preparedMultiScript = TextLayoutEngine.PrepareWithSegments(MultiScript, style);
            preparedRichInline = RichInlineLayoutEngine.Prepare(
            [
                new RichInlineItem("Assigned to ", style),
                new RichInlineItem("@christian289", style, RichInlineBreakMode.Never, extraWidth: 12),
                new RichInlineItem(" and shipped the layout port today", style),
            ]);
        });
    }

    /// <summary>The resize hot path: line count and height only.</summary>
    [Benchmark(Baseline = true)]
    public LayoutResult Layout() => TextLayoutEngine.Layout(prepared, MaxWidth, 19);

    /// <summary>Same break decisions, but tracking per-line ranges without materializing text.</summary>
    [Benchmark]
    public int WalkLineRanges()
    {
        int lines = 0;
        TextLayoutEngine.WalkLineRanges(preparedWithSegments, MaxWidth, (in LayoutLineRange _) => lines++);
        return lines;
    }

    /// <summary>Shrinkwrap input: widest line at the given constraint.</summary>
    [Benchmark]
    public LineStats MeasureLineStats() => TextLayoutEngine.MeasureLineStats(preparedWithSegments, MaxWidth);

    /// <summary>Rich rendering path: allocates the per-line text.</summary>
    [Benchmark]
    public LayoutLinesResult LayoutWithLines() =>
        TextLayoutEngine.LayoutWithLines(preparedWithSegments, MaxWidth, 19);

    /// <summary>Bidi + CJK + numerals exercise the slower non-fast-path walker.</summary>
    [Benchmark]
    public LayoutResult LayoutMultiScript() =>
        TextLayoutEngine.Layout(preparedMultiScript, MaxWidth, 19);

    [Benchmark]
    public RichInlineStats RichInlineStats() =>
        RichInlineLayoutEngine.MeasureStats(preparedRichInline, MaxWidth);

    internal static void RunOnStaThread(Action action)
    {
        Exception? failure = null;
        Thread thread = new(() =>
        {
            try
            {
                action();
            }
            catch (Exception ex)
            {
                failure = ex;
            }
        });

        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();

        if (failure is not null)
        {
            throw new InvalidOperationException("STA setup failed.", failure);
        }
    }
}

/// <summary>
/// Prepare-time cost: this is the price paid once per text block, and the reason the
/// layout benchmarks above can be pure arithmetic.
/// </summary>
[MemoryDiagnoser]
public class PrepareBenchmarks
{
    private const string Paragraph =
        "Performance is critical for this kind of library. If you can't measure hundreds " +
        "of text blocks per frame, it's not useful for real applications.";

    private TextStyle style = null!;

    [GlobalSetup]
    public void Setup()
    {
        LayoutBenchmarks.RunOnStaThread(() =>
        {
            style = new TextStyle(
                new FontFamily("Segoe UI"),
                16,
                FontWeights.Normal,
                FontStyles.Normal,
                FontStretches.Normal,
                CultureInfo.GetCultureInfo("en-US"),
                FlowDirection.LeftToRight,
                1,
                TextFormattingMode.Ideal);

            // Warm the measurer and analyzer caches so the benchmark reflects steady state.
            TextLayoutEngine.Prepare(Paragraph, style);
        });
    }

    /// <summary>Cache-warm prepare: analysis is cached, segment widths are cached.</summary>
    [Benchmark]
    public PreparedText PrepareWarm()
    {
        PreparedText? result = null;
        LayoutBenchmarks.RunOnStaThread(() => result = TextLayoutEngine.Prepare(Paragraph, style));
        return result!;
    }

    /// <summary>Cold prepare: clears both caches, so this shapes every segment again.</summary>
    [Benchmark]
    public PreparedText PrepareCold()
    {
        PreparedText? result = null;
        LayoutBenchmarks.RunOnStaThread(() =>
        {
            TextLayoutEngine.ClearCaches();
            result = TextLayoutEngine.Prepare(Paragraph, style);
        });
        return result!;
    }
}

internal static class Program
{
    private static void Main(string[] args) =>
        BenchmarkSwitcher.FromAssembly(typeof(Program).Assembly).Run(args);
}
