using System.Windows;

namespace BrowserWindow;

public partial class App : Application
{
    /// <summary>
    /// 시작 시 특정 호스트에 자동 dock하기 위한 인수
    /// --dockTo {pipeName} --tabId {tabId}
    /// </summary>
    public static string? DockToPipe { get; private set; }
    public static string? InitialTabId { get; private set; }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var args = e.Args;
        for (int i = 0; i < args.Length - 1; i++)
        {
            switch (args[i])
            {
                case "--dockTo":
                    DockToPipe = args[i + 1];
                    break;
                case "--tabId":
                    InitialTabId = args[i + 1];
                    break;
            }
        }
    }
}
