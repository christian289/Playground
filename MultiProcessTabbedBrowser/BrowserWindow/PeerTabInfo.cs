using System.Diagnostics;
using SharedLib;

namespace BrowserWindow;

/// <summary>
/// 호스트 역할일 때, 임베딩된 각 피어(탭)의 정보
/// </summary>
public class PeerTabInfo : IDisposable
{
    public string TabId { get; set; } = string.Empty;
    public string Title { get; set; } = "New Window";
    public IntPtr PeerHwnd { get; set; }
    public int PeerPid { get; set; }
    public Process? PeerProcess { get; set; }
    public IpcPipeServer? PipeServer { get; set; }
    public bool IsReady { get; set; }
    public bool IsEmbedded { get; set; }

    public void Dispose()
    {
        PipeServer?.Dispose();

        try
        {
            if (PeerProcess is { HasExited: false })
            {
                PeerProcess.Kill();
            }
        }
        catch { }

        PeerProcess?.Dispose();
        GC.SuppressFinalize(this);
    }
}
