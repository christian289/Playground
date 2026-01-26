using System.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using WpfOnnxWinUI3Demo.Core.Services;
using WpfOnnxWinUI3Demo.ViewModels;

namespace WpfOnnxWinUI3Demo.WpfApp;

/// <summary>
/// WPF Application entry point with DI configuration.
/// DI 구성을 포함한 WPF 애플리케이션 진입점입니다.
/// </summary>
public partial class App : Application
{
    private readonly IHost _host;

    public App()
    {
        _host = Host.CreateDefaultBuilder()
            .ConfigureServices(ConfigureServices)
            .Build();
    }

    private static void ConfigureServices(HostBuilderContext context, IServiceCollection services)
    {
        // Register services
        // 서비스 등록
        services.AddSingleton<OnnxInferenceService>();
        services.AddSingleton<MainViewModel>();
        services.AddSingleton<MainWindow>();
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        mainWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _host.Dispose();
        base.OnExit(e);
    }
}
