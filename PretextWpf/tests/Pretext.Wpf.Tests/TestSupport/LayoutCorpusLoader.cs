using System.IO;
using System.Text.Json;

namespace Pretext.Wpf.Tests;

/// <summary>One entry of <c>TestData/layout-corpus.json</c>'s <c>texts</c> array.</summary>
internal sealed record LayoutCorpusText(string Label, string Text);

/// <summary>Deserialized shape of <c>TestData/layout-corpus.json</c>.</summary>
internal sealed class LayoutCorpus
{
    public List<LayoutCorpusText> Texts { get; init; } = [];

    public List<int> Sizes { get; init; } = [];

    public List<int> Widths { get; init; } = [];
}

/// <summary>
/// Loads the shared Latin/Arabic/Hebrew/CJK/Thai/emoji/edge-case corpus (ported
/// from upstream pretext's <c>test-data.ts</c>) once per test run for LAY-003 and
/// the WPF oracle suite.
/// </summary>
internal static class LayoutCorpusLoader
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    private static readonly Lazy<LayoutCorpus> Cached = new(LoadFromDisk);

    internal static LayoutCorpus Load() => Cached.Value;

    private static LayoutCorpus LoadFromDisk()
    {
        string path = Path.Combine(AppContext.BaseDirectory, "TestData", "layout-corpus.json");
        string json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<LayoutCorpus>(json, Options)
            ?? throw new InvalidOperationException($"Failed to deserialize layout corpus at '{path}'.");
    }
}
