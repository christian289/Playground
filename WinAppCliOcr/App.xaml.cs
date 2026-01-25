using System.Windows;
using Velopack;

namespace WinAppCliOcr;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Velopack bootstrap - must be first
        VelopackApp.Build().Run();

        base.OnStartup(e);
    }
}
