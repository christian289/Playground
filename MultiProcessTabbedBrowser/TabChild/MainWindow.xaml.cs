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
    private int? _lastHostPid;
    private bool _isEmbedded;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        _hwnd = new WindowInteropHelper(this).Handle;
        _tabId = App.TabId ?? Guid.NewGuid().ToString("N")[..8];
        _lastHostPid = App.HostPid;

        UpdateProcessInfo();

        if (App.IsHosted && App.PipeName != null)
        {
            await ConnectToHost(App.PipeName);
        }
        else
        {
            ShowStandaloneUI();
        }
    }

    private void UpdateProcessInfo()
    {
        var process = Process.GetCurrentProcess();
        ProcessIdText.Text = $"PID: {process.Id}";
        ProcessInfo.Text = $"Process ID: {process.Id}\n" +
                           $"Tab ID: {_tabId}\n" +
                           $"Window Handle: 0x{_hwnd:X}\n" +
                           $"Thread ID: {Environment.CurrentManagedThreadId}\n" +
                           $"Working Set: {process.WorkingSet64 / 1024 / 1024} MB\n" +
                           $"Embedded: {_isEmbedded}\n" +
                           $"URL: {_currentUrl}";
    }

    private void ShowStandaloneUI()
    {
        AttachPanel.Visibility = Visibility.Visible;
        ConnectionStatus.Text = "Standalone";
        ConnectionStatus.Foreground = System.Windows.Media.Brushes.Orange;

        if (_lastHostPid != null)
        {
            HostPidInput.Text = _lastHostPid.ToString();
        }
    }

    #region Host Connection

    private async Task ConnectToHost(string pipeName)
    {
        try
        {
            _ipcClient?.Dispose();
            _ipcClient = new IpcPipeClient(pipeName);
            _ipcClient.MessageReceived += OnHostMessage;
            _ipcClient.Disconnected += OnHostDisconnected;

            StatusText.Text = "Connecting to host...";
            await _ipcClient.ConnectAsync();

            _isEmbedded = true;
            AttachPanel.Visibility = Visibility.Collapsed;
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
                    ["title"] = string.IsNullOrEmpty(_currentUrl) || _currentUrl == "about:blank"
                        ? "New Tab"
                        : Title,
                }
            });

            await _ipcClient.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.ChildReady,
                TabId = _tabId,
            });

            UpdateProcessInfo();
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Connection failed: {ex.Message}";
            _isEmbedded = false;
            ShowStandaloneUI();
        }
    }

    /// <summary>
    /// Standalone 모드에서 Host에 attach 요청
    /// </summary>
    private async Task AttachToHostAsync(int hostPid)
    {
        try
        {
            var attachPipeName = $"MultiProcessBrowser_Attach_{hostPid}";
            StatusText.Text = $"Requesting attach to host (PID: {hostPid})...";

            var attachClient = new IpcPipeClient(attachPipeName);
            await attachClient.ConnectAsync(3000);

            // attach 요청 전송
            await attachClient.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.RequestAttach,
                TabId = _tabId,
                Data = new Dictionary<string, string>
                {
                    ["pid"] = Process.GetCurrentProcess().Id.ToString(),
                    ["hwnd"] = _hwnd.ToString(),
                    ["title"] = Title,
                }
            });

            // Host가 AttachAccepted로 새 파이프 이름을 보내줌
            var tcs = new TaskCompletionSource<IpcMessage>();
            attachClient.MessageReceived += msg =>
            {
                if (msg.Type == IpcMessageType.AttachAccepted)
                    tcs.TrySetResult(msg);
            };

            var timeoutTask = Task.Delay(5000);
            var completed = await Task.WhenAny(tcs.Task, timeoutTask);

            if (completed == tcs.Task)
            {
                var response = tcs.Task.Result;
                attachClient.Dispose();

                if (response.Data.TryGetValue("pipeName", out var newPipeName))
                {
                    // 새 TabId 가 왔으면 갱신
                    if (!string.IsNullOrEmpty(response.TabId))
                        _tabId = response.TabId;

                    _lastHostPid = hostPid;
                    await ConnectToHost(newPipeName);
                }
            }
            else
            {
                attachClient.Dispose();
                StatusText.Text = "Attach timeout - host did not respond";
            }
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Attach failed: {ex.Message}";
        }
    }

    #endregion

    #region IPC Message Handling

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
                    if (msg.Data.TryGetValue("hostPid", out var pidStr) &&
                        int.TryParse(pidStr, out var hostPid))
                    {
                        _lastHostPid = hostPid;
                    }
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
            StatusText.Text = "Host disconnected - running standalone";
            HandleDetach();
        });
    }

    private void HandleDetach()
    {
        _isEmbedded = false;

        // Win32 API로 윈도우를 독립 윈도우로 전환
        Win32Api.DetachWindow(_hwnd);

        // 마우스 커서 위치로 이동
        Win32Api.GetCursorPos(out var cursorPos);
        Left = cursorPos.X - 100;
        Top = cursorPos.Y - 20;
        Width = 900;
        Height = 600;

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

        // IPC 클라이언트 정리
        _ipcClient?.Dispose();
        _ipcClient = null;

        ShowStandaloneUI();
        UpdateProcessInfo();
    }

    #endregion

    #region Navigation

    private void NavigateTo(string url)
    {
        _currentUrl = url;
        AddressBar.Text = url;
        StatusText.Text = $"Loading {url}...";

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

        StatusText.Text = $"Loaded: {url}";
        Title = PageTitle.Text;
        UpdateProcessInfo();

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

    #endregion

    #region Event Handlers

    private void AddressBar_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
            NavigateTo(AddressBar.Text.Trim());
    }

    private void GoButton_Click(object sender, RoutedEventArgs e) =>
        NavigateTo(AddressBar.Text.Trim());

    private void BackButton_Click(object sender, RoutedEventArgs e) =>
        StatusText.Text = "Back navigation (simulated)";

    private void ForwardButton_Click(object sender, RoutedEventArgs e) =>
        StatusText.Text = "Forward navigation (simulated)";

    private void RefreshButton_Click(object sender, RoutedEventArgs e) =>
        NavigateTo(_currentUrl);

    private void QuickLink_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string url)
            NavigateTo(url);
    }

    private async void AttachButton_Click(object sender, RoutedEventArgs e)
    {
        if (int.TryParse(HostPidInput.Text.Trim(), out var hostPid))
        {
            await AttachToHostAsync(hostPid);
        }
        else
        {
            StatusText.Text = "Please enter a valid Host PID";
        }
    }

    private async void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (_ipcClient != null)
        {
            try
            {
                await _ipcClient.SendAsync(new IpcMessage
                {
                    Type = IpcMessageType.CloseRequested,
                    TabId = _tabId,
                });
            }
            catch { }
            _ipcClient.Dispose();
        }
    }

    #endregion
}
