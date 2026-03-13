using System.Windows;

namespace TabChild;

public partial class App : Application
{
    /// <summary>
    /// 명령줄 인수로 전달된 파이프 이름
    /// </summary>
    public static string? PipeName { get; private set; }

    /// <summary>
    /// 명령줄 인수로 전달된 탭 ID
    /// </summary>
    public static string? TabId { get; private set; }

    /// <summary>
    /// Host에서 실행된 것인지 독립 실행인지 구분
    /// </summary>
    public static bool IsHosted => PipeName != null;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 명령줄 인수 파싱: --pipe <pipeName> --tabId <tabId>
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
            }
        }
    }
}
