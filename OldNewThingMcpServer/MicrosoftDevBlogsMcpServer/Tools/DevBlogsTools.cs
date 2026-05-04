using MicrosoftDevBlogsMcpServer.Services;

namespace MicrosoftDevBlogsMcpServer.Tools;

[McpServerToolType]
public sealed partial class DevBlogsTools(DevBlogsFeedService feed)
{
    [GeneratedRegex(@"[ \t]*\r?\n[ \t]*(\r?\n[ \t]*)+")]
    private static partial Regex CollapseWhitespace();

    [GeneratedRegex(@"[ \t]+")]
    private static partial Regex TrimSpaces();

    [GeneratedRegex(@"/(?<y>\d{4})(?<m>\d{2})(?<d>\d{2})-\d+/?")]
    private static partial Regex ArchiveUrlPattern();

    public sealed record PostSummary(
        string Title,
        string Link,
        string PublishedAt,
        string Summary);

    public sealed record ArchivedPost(string Url, string Date);

    public sealed record PostHeadline(string Url, string Title, string Date);

    public sealed record BlogInfo(string Slug, string Name, string Description);

    private static readonly BlogInfo[] KnownBlogs =
    [
        new("oldnewthing", "The Old New Thing", "Raymond Chen's blog on Windows history, Win32 internals, and deep technical stories."),
        new("dotnet", ".NET Blog", "Official .NET team blog: language, runtime, library releases, performance, and ecosystem news."),
        new("visualstudio", "Visual Studio Blog", "Visual Studio IDE updates, features, productivity, and platform changes."),
        new("cppblog", "C++ Team Blog", "C++ language, MSVC toolchain, Standard Library, and C++ ecosystem."),
        new("typescript", "TypeScript Blog", "TypeScript language releases, design notes, and feature explainers."),
        new("azure-sdk", "Azure SDK Blog", "Azure SDK team updates across client languages."),
        new("powershell", "PowerShell Blog", "PowerShell team announcements, language releases, and deep dives."),
        new("python", "Microsoft Python Blog", "Python at Microsoft: VS Code Python extension, Pylance, data tooling."),
        new("commandline", "Windows Command Line", "Windows Terminal, console host, WSL, and command-line UX."),
        new("directx", "DirectX Developer Blog", "DirectX APIs, graphics programming, and Direct3D features."),
        new("pix", "PIX Blog", "PIX for Windows — GPU/CPU performance tuning tool."),
        new("devops", "Azure DevOps Blog", "Azure DevOps services, boards, repos, pipelines."),
        new("nativeaot", "Native AOT Blog", "Ahead-of-time compilation for .NET."),
        new("performance", "Performance Blog", "Performance engineering across Microsoft products."),
        new("ifdef", "#ifdef Windows", "Windows development deep dives."),
        new("landingpage", "DevBlogs Landing", "Top-level devblogs.microsoft.com landing content."),
    ];

    [McpServerTool(Name = "list_blogs")]
    [Description(
        "Returns a curated list of well-known devblogs.microsoft.com team blogs with their " +
        "slug (used as the 'blog' parameter in other tools), display name, and a short " +
        "description. Use this to discover which blog slug to pass to get_latest_posts, " +
        "search_posts, or list_archived_posts. Additional blogs may exist on " +
        "devblogs.microsoft.com beyond this curated list — the 'blog' parameter in other " +
        "tools accepts any valid slug.")]
    public static IReadOnlyList<BlogInfo> ListBlogs() => KnownBlogs;

    [McpServerTool(Name = "get_latest_posts")]
    [Description(
        "Returns the most recent posts from a devblogs.microsoft.com team blog's RSS feed. " +
        "Each post includes title, link, ISO-8601 publication date, and a plain-text summary. " +
        "Use list_blogs to discover valid blog slugs. Defaults to 'oldnewthing'.")]
    public async Task<IReadOnlyList<PostSummary>> GetLatestPostsAsync(
        [Description("Blog slug on devblogs.microsoft.com (e.g. 'oldnewthing', 'dotnet', 'visualstudio').")] string blog = "oldnewthing",
        [Description("Maximum number of posts to return (1-25). Defaults to 10.")] int count = 10,
        CancellationToken ct = default)
    {
        count = Math.Clamp(count, 1, 25);
        var items = await feed.FetchFeedAsync(blog, ct);
        return items.Take(count).Select(ToSummary).ToList();
    }

    [McpServerTool(Name = "search_posts")]
    [Description(
        "Searches the posts currently present in a blog's RSS feed for a case-insensitive " +
        "keyword in the title or summary. Note: the RSS feed only exposes recent posts " +
        "(typically ~20), not the full archive — use list_archived_posts to access older " +
        "posts. Defaults to the 'oldnewthing' blog.")]
    public async Task<IReadOnlyList<PostSummary>> SearchPostsAsync(
        [Description("Case-insensitive keyword to match against post title and summary.")] string keyword,
        [Description("Blog slug on devblogs.microsoft.com. Defaults to 'oldnewthing'.")] string blog = "oldnewthing",
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(keyword))
            return [];

        var items = await feed.FetchFeedAsync(blog, ct);
        return items
            .Select(ToSummary)
            .Where(p =>
                p.Title.Contains(keyword, StringComparison.OrdinalIgnoreCase) ||
                p.Summary.Contains(keyword, StringComparison.OrdinalIgnoreCase))
            .ToList();
    }

    [McpServerTool(Name = "get_post_content")]
    [Description(
        "Fetches the full post at the given URL on devblogs.microsoft.com and returns " +
        "the main article body as plain text. Works across all sub-blogs.")]
    public async Task<string> GetPostContentAsync(
        [Description("Absolute URL of a post on devblogs.microsoft.com.")] string url,
        CancellationToken ct = default)
    {
        if (!IsValidDevBlogsUrl(url, out var uri))
            throw new ArgumentException(
                "URL must be an absolute https://devblogs.microsoft.com/... address.",
                nameof(url));

        var html = await feed.FetchHtmlAsync(uri.ToString(), ct);
        var doc = new HtmlDocument();
        doc.LoadHtml(html);

        var article = doc.DocumentNode.SelectSingleNode("//div[contains(@class,'entry-content')]")
                      ?? doc.DocumentNode.SelectSingleNode("//article");

        return article is null
            ? throw new InvalidOperationException("Could not locate post content in the HTML.")
            : NormalizeText(article.InnerText);
    }

    [McpServerTool(Name = "list_archived_posts")]
    [Description(
        "Lists post URLs and publication dates for a given year (and optionally month) by " +
        "reading the blog's sitemap. Covers the full archive, not just the recent RSS " +
        "window. Dates are extracted from URL slugs where they include a YYYYMMDD prefix " +
        "(e.g. Old New Thing), or fall back to the sitemap's <lastmod> value. Pipe URLs " +
        "through get_post_titles for a cheap title scan, or get_post_content for full text. " +
        "Defaults to the 'oldnewthing' blog.")]
    public async Task<IReadOnlyList<ArchivedPost>> ListArchivedPostsAsync(
        [Description("Four-digit year, e.g. 2025. Valid range: 2003 to current year.")] int year,
        [Description("Optional month (1-12). Omit to return the entire year.")] int? month = null,
        [Description("Blog slug on devblogs.microsoft.com. Defaults to 'oldnewthing'.")] string blog = "oldnewthing",
        CancellationToken ct = default)
    {
        var currentYear = DateTime.UtcNow.Year;
        if (year < 2003 || year > currentYear)
            throw new ArgumentOutOfRangeException(nameof(year), $"Year must be 2003..{currentYear}.");
        if (month is not null && (month < 1 || month > 12))
            throw new ArgumentOutOfRangeException(nameof(month), "Month must be 1..12.");

        var index = await feed.FetchSitemapIndexAsync(blog, ct);
        var postSitemaps = index
            .Where(s => s.Loc.Contains("/post-sitemap", StringComparison.OrdinalIgnoreCase))
            .ToList();

        // Yoast SEO reports the same blog-wide lastmod for every sitemap in the index,
        // so it cannot be used to pick the right sitemap for a given year. Fetch them
        // all in parallel and filter by URL slug (falling back to lastmod) instead.
        var urlLists = await Task.WhenAll(
            postSitemaps.Select(s => feed.FetchSitemapUrlsAsync(s.Loc, ct)));

        var datePrefix = month is null
            ? $"{year:D4}-"
            : $"{year:D4}-{month:D2}-";

        var results = new List<ArchivedPost>();
        foreach (var urls in urlLists)
        {
            foreach (var entry in urls)
            {
                var parsed = TryParseArchivedPost(entry);
                if (parsed is not null && parsed.Date.StartsWith(datePrefix, StringComparison.Ordinal))
                    results.Add(parsed);
            }
        }

        return [.. results
            .DistinctBy(p => p.Url)
            .OrderByDescending(p => p.Date)];
    }

    [McpServerTool(Name = "get_post_titles")]
    [Description(
        "Fetches titles for multiple devblogs.microsoft.com post URLs in parallel. Returns " +
        "URL, title (from the HTML <title> tag, with common site suffixes like " +
        "'- The Old New Thing' or '- .NET Blog' trimmed), and publication date (extracted " +
        "from the URL slug when available). Use this to triage a large set of URLs — " +
        "typically from list_archived_posts — without paying the cost of full article " +
        "text via get_post_content. Parallelized up to 8 concurrent; max 100 URLs per call.")]
    public async Task<IReadOnlyList<PostHeadline>> GetPostTitlesAsync(
        [Description("Absolute post URLs on devblogs.microsoft.com. Up to 100.")] IReadOnlyList<string> urls,
        CancellationToken ct = default)
    {
        if (urls is null || urls.Count == 0) return [];
        if (urls.Count > 100)
            throw new ArgumentException("Pass at most 100 URLs per call.", nameof(urls));

        var results = new ConcurrentBag<PostHeadline>();
        await Parallel.ForEachAsync(
            urls,
            new ParallelOptions { MaxDegreeOfParallelism = 8, CancellationToken = ct },
            async (url, token) =>
            {
                var headline = await FetchHeadlineAsync(url, token);
                if (headline is not null) results.Add(headline);
            });

        return [.. results.OrderByDescending(r => r.Date)];
    }

    private async Task<PostHeadline?> FetchHeadlineAsync(string url, CancellationToken ct)
    {
        if (!IsValidDevBlogsUrl(url, out var uri)) return null;

        var html = await feed.FetchHtmlAsync(uri.ToString(), ct);
        var doc = new HtmlDocument();
        doc.LoadHtml(html);

        var titleNode = doc.DocumentNode.SelectSingleNode("//head/title")
                        ?? doc.DocumentNode.SelectSingleNode("//title");
        if (titleNode is null) return null;

        var title = CleanTitle(System.Net.WebUtility.HtmlDecode(titleNode.InnerText).Trim());
        var date = TryExtractDateFromSlug(uri.ToString()) ?? string.Empty;
        return new PostHeadline(uri.ToString(), title, date);
    }

    private static bool IsValidDevBlogsUrl(string url, out Uri uri)
    {
        uri = null!;
        if (!Uri.TryCreate(url, UriKind.Absolute, out var parsed)) return false;
        if (parsed.Scheme != Uri.UriSchemeHttps) return false;
        if (!parsed.Host.Equals("devblogs.microsoft.com", StringComparison.OrdinalIgnoreCase)) return false;
        uri = parsed;
        return true;
    }

    private static ArchivedPost? TryParseArchivedPost(SitemapUrl entry)
    {
        var dateFromSlug = TryExtractDateFromSlug(entry.Loc);
        var date = dateFromSlug
                   ?? (entry.LastMod != default
                       ? entry.LastMod.UtcDateTime.ToString("yyyy-MM-dd")
                       : null);
        return date is null ? null : new ArchivedPost(entry.Loc, date);
    }

    private static string? TryExtractDateFromSlug(string url)
    {
        var match = ArchiveUrlPattern().Match(url);
        return match.Success
            ? $"{match.Groups["y"].Value}-{match.Groups["m"].Value}-{match.Groups["d"].Value}"
            : null;
    }

    private static string CleanTitle(string title)
    {
        // Strip common site/brand suffixes (" - The Old New Thing", " - .NET Blog", etc.)
        var dash = title.LastIndexOf(" - ", StringComparison.Ordinal);
        if (dash > 0 && title.Length - dash <= 40)
            return title[..dash].Trim();
        var pipe = title.LastIndexOf(" | ", StringComparison.Ordinal);
        if (pipe > 0 && title.Length - pipe <= 40)
            return title[..pipe].Trim();
        return title.Trim();
    }

    private static PostSummary ToSummary(SyndicationItem item)
    {
        var link = item.Links.FirstOrDefault()?.Uri?.ToString() ?? string.Empty;
        var summary = StripHtml(item.Summary?.Text ?? string.Empty);
        var published = item.PublishDate == default
            ? string.Empty
            : item.PublishDate.UtcDateTime.ToString("O");

        return new PostSummary(
            Title: item.Title?.Text ?? string.Empty,
            Link: link,
            PublishedAt: published,
            Summary: summary);
    }

    private static string StripHtml(string html)
    {
        if (string.IsNullOrEmpty(html)) return string.Empty;
        var decoded = System.Net.WebUtility.HtmlDecode(html);
        var doc = new HtmlDocument();
        doc.LoadHtml(decoded);
        return NormalizeText(doc.DocumentNode.InnerText);
    }

    private static string NormalizeText(string text)
    {
        var decoded = System.Net.WebUtility.HtmlDecode(text);
        var collapsed = CollapseWhitespace().Replace(decoded, "\n\n");
        var spaced = TrimSpaces().Replace(collapsed, " ");
        return spaced.Trim();
    }
}
