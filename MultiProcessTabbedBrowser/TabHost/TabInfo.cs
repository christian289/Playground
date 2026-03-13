using System.Diagnostics;
using SharedLib;

namespace TabHost;

/// <summary>
/// 각 탭의 상태 정보를 관리하는 모델
/// </summary>
public class TabInfo : IDisposable
{
    public string TabId { get; set; } = string.Empty;
    public string Title { get; set; } = "New Tab";
    public string Url { get; set; } = "about:blank";
    public IntPtr ChildHwnd { get; set; }
    public int ChildPid { get; set; }
    public Process? ChildProcess { get; set; }
    public IpcPipeServer? PipeServer { get; set; }
    public bool IsReady { get; set; }
    public bool IsEmbedded { get; set; }

    public void Dispose()
    {
        PipeServer?.Dispose();

        try
        {
            if (ChildProcess is { HasExited: false })
            {
                ChildProcess.Kill();
            }
        }
        catch { }

        ChildProcess?.Dispose();
        GC.SuppressFinalize(this);
    }
}
