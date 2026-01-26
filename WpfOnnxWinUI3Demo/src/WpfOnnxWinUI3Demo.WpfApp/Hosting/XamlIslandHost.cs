using System.Runtime.InteropServices;
using System.Windows.Interop;
using Microsoft.UI.Content;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Hosting;
using WpfOnnxWinUI3Demo.ViewModels;
using WpfOnnxWinUI3Demo.WpfApp.Controls;

namespace WpfOnnxWinUI3Demo.WpfApp.Hosting;

/// <summary>
/// HwndHost implementation for hosting WinUI 3 content in WPF via XAML Islands.
/// XAML Islands를 통해 WPF에서 WinUI 3 콘텐츠를 호스팅하기 위한 HwndHost 구현입니다.
/// </summary>
public sealed class XamlIslandHost : HwndHost
{
    private DesktopWindowXamlSource? _xamlSource;
    private DesktopChildSiteBridge? _bridge;
    private ImageClassifierControl? _control;
    private IntPtr _hwndHost;
    private readonly MainViewModel _viewModel;

    private static DispatcherQueueController? _dispatcherQueueController;
    private static WindowsXamlManager? _xamlManager;

    public XamlIslandHost(MainViewModel viewModel)
    {
        _viewModel = viewModel;
    }

    /// <summary>
    /// Initializes the WinUI 3 XAML hosting infrastructure.
    /// WinUI 3 XAML 호스팅 인프라를 초기화합니다.
    /// </summary>
    public static void InitializeXamlIslands()
    {
        // Create DispatcherQueue for Win32 thread
        // Win32 스레드용 DispatcherQueue 생성
        if (_dispatcherQueueController is null)
        {
            var options = new DispatcherQueueOptions
            {
                dwSize = Marshal.SizeOf<DispatcherQueueOptions>(),
                threadType = DISPATCHERQUEUE_THREAD_TYPE.DQTYPE_THREAD_CURRENT,
                apartmentType = DISPATCHERQUEUE_THREAD_APARTMENTTYPE.DQTAT_COM_STA
            };

            CreateDispatcherQueueController(options, out var controller);
            _dispatcherQueueController = controller;
        }

        // Initialize WindowsXamlManager
        // WindowsXamlManager 초기화
        _xamlManager ??= WindowsXamlManager.InitializeForCurrentThread();
    }

    protected override HandleRef BuildWindowCore(HandleRef hwndParent)
    {
        // Create host window
        // 호스트 윈도우 생성
        _hwndHost = CreateWindowEx(
            0,
            "static",
            string.Empty,
            WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0,
            hwndParent.Handle,
            IntPtr.Zero,
            IntPtr.Zero,
            IntPtr.Zero);

        // Create XAML source and bridge
        // XAML 소스 및 브릿지 생성
        _xamlSource = new DesktopWindowXamlSource();
        _bridge = _xamlSource.SiteBridge;

        // Connect to parent window
        // 부모 윈도우에 연결
        var parentWindowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hwndParent.Handle);
        _bridge?.MoveAndResize(new Windows.Graphics.RectInt32(0, 0, (int)ActualWidth, (int)ActualHeight));

        // Create and set WinUI 3 control
        // WinUI 3 컨트롤 생성 및 설정
        _control = new ImageClassifierControl();
        _control.SetWindowHandle(hwndParent.Handle);
        _control.SetViewModel(_viewModel);

        _xamlSource.Content = _control;

        return new HandleRef(this, _hwndHost);
    }

    protected override void DestroyWindowCore(HandleRef hwnd)
    {
        _xamlSource?.Dispose();
        _xamlSource = null;

        if (_hwndHost != IntPtr.Zero)
        {
            DestroyWindow(_hwndHost);
            _hwndHost = IntPtr.Zero;
        }
    }

    protected override IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        const int WM_SIZE = 0x0005;

        if (msg == WM_SIZE && _bridge is not null)
        {
            int width = (int)(lParam.ToInt64() & 0xFFFF);
            int height = (int)((lParam.ToInt64() >> 16) & 0xFFFF);

            _bridge.MoveAndResize(new Windows.Graphics.RectInt32(0, 0, width, height));
            handled = true;
        }

        return base.WndProc(hwnd, msg, wParam, lParam, ref handled);
    }

    #region Native Methods

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr CreateWindowEx(
        int dwExStyle, string lpClassName, string lpWindowName, int dwStyle,
        int x, int y, int nWidth, int nHeight,
        IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll")]
    private static extern bool DestroyWindow(IntPtr hwnd);

    [DllImport("CoreMessaging.dll")]
    private static extern int CreateDispatcherQueueController(
        DispatcherQueueOptions options,
        out DispatcherQueueController dispatcherQueueController);

    private const int WS_CHILD = 0x40000000;
    private const int WS_VISIBLE = 0x10000000;

    [StructLayout(LayoutKind.Sequential)]
    private struct DispatcherQueueOptions
    {
        public int dwSize;
        public DISPATCHERQUEUE_THREAD_TYPE threadType;
        public DISPATCHERQUEUE_THREAD_APARTMENTTYPE apartmentType;
    }

    private enum DISPATCHERQUEUE_THREAD_TYPE
    {
        DQTYPE_THREAD_DEDICATED = 1,
        DQTYPE_THREAD_CURRENT = 2
    }

    private enum DISPATCHERQUEUE_THREAD_APARTMENTTYPE
    {
        DQTAT_COM_NONE = 0,
        DQTAT_COM_ASTA = 1,
        DQTAT_COM_STA = 2
    }

    #endregion
}
