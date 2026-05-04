using MicrosoftDevBlogsMcpServer.Services;
using MicrosoftDevBlogsMcpServer.Tools;

var builder = Host.CreateApplicationBuilder(args);

// Configure all logs to go to stderr (stdout is reserved for the MCP protocol).
builder.Logging.AddConsole(o => o.LogToStandardErrorThreshold = LogLevel.Trace);

builder.Services.AddHttpClient<DevBlogsFeedService>(client =>
{
    client.DefaultRequestHeaders.UserAgent.ParseAdd("MicrosoftDevBlogsMcpServer/0.2");
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithTools<DevBlogsTools>();

await builder.Build().RunAsync();
