using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using SharedLib;

namespace TabChild;

public partial class MainWindow : Window
{
    private IpcPipeClient? _ipcClient;
    private string _tabId = string.Empty;
    private string _currentUrl = "about:blank";
    private IntPtr _hwnd;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
        SizeChanged += MainWindow_SizeChanged;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        // 윈도우 핸들 획득
        _hwnd = new WindowInteropHelper(this).Handle;
        _tabId = App.TabId ?? Guid.NewGuid().ToString("N")[..8];

        // 프로세스 정보 표시
        var process = Process.GetCurrentProcess();
        ProcessIdText.Text = $"PID: {process.Id}";
        ProcessInfo.Text = $"Process ID: {process.Id}\n" +
                           $"Tab ID: {_tabId}\n" +
                           $"Window Handle: 0x{_hwnd:X}\n" +
                           $"Thread ID: {Environment.CurrentManagedThreadId}\n" +
                           $"Working Set: {process.WorkingSet64 / 1024 / 1024} MB\n" +
                           $"Hosted: {App.IsHosted}";

        // Host 프로세스와 연결 (Hosted 모드일 때)
        if (App.IsHosted && App.PipeName != null)
        {
            await ConnectToHost();
        }
    }

    private async Task ConnectToHost()
    {
        try
        {
            _ipcClient = new IpcPipeClient(App.PipeName!);
            _ipcClient.MessageReceived += OnHostMessage;
            _ipcClient.Disconnected += OnHostDisconnected;

            StatusText.Text = "Connecting to host...";
            await _ipcClient.ConnectAsync();

            ConnectionStatus.Text = "Connected";
            ConnectionStatus.Foreground = System.Windows.Media.Brushes.LimeGreen;
            StatusText.Text = "Connected to host process";

            // Host에게 윈도우 핸들 전달
            await _ipcClient.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.WindowHandleReady,
                TabId = _tabId,
                Data = new Dictionary<string, string>
                {
                    ["hwnd"] = _hwnd.ToString(),
                    ["pid"] = Process.GetCurrentProcess().Id.ToString(),
                    ["title"] = Title,
                }
            });

            // 준비 완료 알림
            await _ipcClient.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.ChildReady,
                TabId = _tabId,
            });
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Connection failed: {ex.Message}";
            ConnectionStatus.Text = "Standalone";
            ConnectionStatus.Foreground = System.Windows.Media.Brushes.Orange;
        }
    }

    private void OnHostMessage(IpcMessage msg)
    {
        Dispatcher.Invoke(() =>
        {
            switch (msg.Type)
            {
                case IpcMessageType.Navigate:
                    if (msg.Data.TryGetValue("url", out var url))
                        NavigateTo(url);
                    break;

                case IpcMessageType.SetTitle:
                    if (msg.Data.TryGetValue("title", out var title))
                    {
                        Title = title;
                        PageTitle.Text = title;
                    }
                    break;

                case IpcMessageType.RequestDetach:
                    HandleDetach();
                    break;

                case IpcMessageType.CloseTab:
                    Close();
                    break;

                case IpcMessageType.Ping:
                    _ = _ipcClient?.SendAsync(new IpcMessage
                    {
                        Type = IpcMessageType.Pong,
                        TabId = _tabId,
                    });
                    break;
            }
        });
    }

    private void OnHostDisconnected()
    {
        Dispatcher.Invoke(() =>
        {
            ConnectionStatus.Text = "Disconnected";
            ConnectionStatus.Foreground = System.Windows.Media.Brushes.Orange;
            StatusText.Text = "Host disconnected - running standalone";

            // 분리되어 독립 실행으로 전환
            HandleDetach();
        });
    }

    private void HandleDetach()
    {
        // Win32 API로 윈도우 분리
        Win32Api.DetachWindow(_hwnd);

        // 윈도우를 마우스 커널 위치로 이동
        Win32Api.GetCursorPos(out var cursorPos);
        Left = cursorPos.X - 100;
        Top = cursorPos.Y - 20;
        Width = 900;
        Height = 600;

        ConnectionStatus.Text = "Detached";
        ConnectionStatus.Foreground = System.Windows.Media.Brushes.Yellow;
        StatusText.Text = "Detached from host - running independently";

        // Host에 분리 완료 알림
        _ = _ipcClient?.SendAsync(new IpcMessage
        {
            Type = IpcMessageType.DetachCompleted,
            TabId = _tabId,
            Data = new Dictionary<string, string>
            {
                ["hwnd"] = _hwnd.ToString(),
            }
        });
    }

    private void NavigateTo(string url)
    {
        _currentUrl = url;
        AddressBar.Text = url;
        StatusText.Text = $"Loading {url}...";

        // 간단한 페이지 시뮬레이션
        if (url.StartsWith("about:"))
        {
            PageTitle.Text = "New Tab";
            PageContent.Text = "Navigate to a URL to get started.";
        }
        else if (url.Contains("settings"))
        {
            PageTitle.Text = "Settings";
            PageContent.Text = "Browser settings would appear here.\n\n" +
                               "- General\n- Privacy & Security\n- Appearance\n" +
                               "- Search Engine\n- Extensions";
        }
        else
        {
            var uri = url.Replace("http://", "").Replace("https://", "");
            PageTitle.Text = $"Page: {uri}";
            PageContent.Text = $"Content of {url}\n\n" +
                               $"This is a simulated page rendered by process {Process.GetCurrentProcess().Id}.\n" +
                               $"Each tab runs in its own independent process for isolation and stability.\n\n" +
                               $"If one tab crashes, other tabs remain unaffected.";
        }

        // 프로세스 정보 갱신
        var process = Process.GetCurrentProcess();
        ProcessInfo.Text = $"Process ID: {process.Id}\n" +
                           $"Tab ID: {_tabId}\n" +
                           $"Window Handle: 0x{_hwnd:X}\n" +
                           $"URL: {_currentUrl}\n" +
                           $"Working Set: {process.WorkingSet64 / 1024 / 1024} MB\n" +
                           $"Hosted: {App.IsHosted}";

        StatusText.Text = $"Loaded: {url}";
        Title = PageTitle.Text;

        // Host에 제목 변경 알림
        _ = _ipcClient?.SendAsync(new IpcMessage
        {
            Type = IpcMessageType.TitleChanged,
            TabId = _tabId,
            Data = new Dictionary<string, string>
            {
                ["title"] = PageTitle.Text,
                ["url"] = url,
            }
        });
    }

    private void AddressBar_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            NavigateTo(AddressBar.Text.Trim());
        }
    }

    private void GoButton_Click(object sender, RoutedEventArgs e)
    {
        NavigateTo(AddressBar.Text.Trim());
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        StatusText.Text = "Back navigation (simulated)";
    }

    private void ForwardButton_Click(object sender, RoutedEventArgs e)
    {
        StatusText.Text = "Forward navigation (simulated)";
    }

    private void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        NavigateTo(_currentUrl);
    }

    private void QuickLink_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string url)
        {
            NavigateTo(url);
        }
    }

    private void MainWindow_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        // 크기 변경 시 프로세스 정보 갱신
    }

    private async void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (_ipcClient != null)
        {
            await _ipcClient.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.CloseRequested,
                TabId = _tabId,
            });
            _ipcClient.Dispose();
        }
    }
}
