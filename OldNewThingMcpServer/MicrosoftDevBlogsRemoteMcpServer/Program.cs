using MicrosoftDevBlogsRemoteMcpServer.Services;
using MicrosoftDevBlogsRemoteMcpServer.Tools;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient<DevBlogsFeedService>(c =>
{
    c.DefaultRequestHeaders.UserAgent.ParseAdd("MicrosoftDevBlogsRemoteMcpServer/0.2");
    c.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services
    .AddMcpServer()
    .WithHttpTransport(options => options.Stateless = true)
    .WithTools<DevBlogsTools>();

var app = builder.Build();
app.MapMcp();
app.Run();
