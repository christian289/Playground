using System.Windows;

namespace TabChild;

public partial class App : Application
{
    public static string? PipeName { get; private set; }
    public static string? TabId { get; private set; }
    public static int? HostPid { get; private set; }
    public static bool IsHosted => PipeName != null;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var args = e.Args;
        for (int i = 0; i < args.Length - 1; i++)
        {
            switch (args[i])
            {
                case "--pipe":
                    PipeName = args[i + 1];
                    break;
                case "--tabId":
                    TabId = args[i + 1];
                    break;
                case "--hostPid":
                    if (int.TryParse(args[i + 1], out var pid))
                        HostPid = pid;
                    break;
            }
        }
    }
}
