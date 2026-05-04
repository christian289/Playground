namespace MicrosoftDevBlogsMcpServer.Services;

public sealed record SitemapEntry(string Loc, DateTimeOffset LastMod);

public sealed record SitemapUrl(string Loc, DateTimeOffset LastMod);

public sealed class DevBlogsFeedService(HttpClient http)
{
    public const string BaseUrl = "https://devblogs.microsoft.com";

    private static readonly XNamespace SitemapNs = "http://www.sitemaps.org/schemas/sitemap/0.9";

    public async Task<IReadOnlyList<SyndicationItem>> FetchFeedAsync(string blog, CancellationToken ct)
    {
        var feedUrl = $"{BaseUrl}/{Uri.EscapeDataString(blog)}/feed";
        using var response = await http.GetAsync(feedUrl, HttpCompletionOption.ResponseHeadersRead, ct);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var reader = XmlReader.Create(stream, new XmlReaderSettings { DtdProcessing = DtdProcessing.Ignore });

        var feed = SyndicationFeed.Load(reader);
        return [.. feed.Items];
    }

    public Task<string> FetchHtmlAsync(string url, CancellationToken ct)
        => http.GetStringAsync(url, ct);

    public async Task<IReadOnlyList<SitemapEntry>> FetchSitemapIndexAsync(string blog, CancellationToken ct)
    {
        var url = $"{BaseUrl}/{Uri.EscapeDataString(blog)}/sitemap_index.xml";
        await using var stream = await http.GetStreamAsync(url, ct);
        var doc = await XDocument.LoadAsync(stream, LoadOptions.None, ct);
        return [.. doc.Root!.Elements(SitemapNs + "sitemap")
            .Select(el => new SitemapEntry(
                Loc: (string)el.Element(SitemapNs + "loc")!,
                LastMod: DateTimeOffset.Parse((string)el.Element(SitemapNs + "lastmod")!)))];
    }

    public async Task<IReadOnlyList<SitemapUrl>> FetchSitemapUrlsAsync(string sitemapUrl, CancellationToken ct)
    {
        await using var stream = await http.GetStreamAsync(sitemapUrl, ct);
        var doc = await XDocument.LoadAsync(stream, LoadOptions.None, ct);
        return [.. doc.Root!.Elements(SitemapNs + "url")
            .Select(el => new SitemapUrl(
                Loc: (string?)el.Element(SitemapNs + "loc") ?? string.Empty,
                LastMod: DateTimeOffset.TryParse((string?)el.Element(SitemapNs + "lastmod"), out var lm) ? lm : default))
            .Where(u => !string.IsNullOrEmpty(u.Loc))];
    }
}
