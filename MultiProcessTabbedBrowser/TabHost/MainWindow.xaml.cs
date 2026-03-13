using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using SharedLib;

namespace TabHost;

public partial class MainWindow : Window
{
    private readonly Dictionary<string, TabInfo> _tabs = new();
    private string? _activeTabId;
    private IntPtr _hostHwnd;
    private readonly DispatcherTimer _statusTimer;
    private readonly CancellationTokenSource _appCts = new();

    // 외부 TabChild가 연결할 수 있는 글로벌 파이프 이름
    private string GlobalPipeName => $"MultiProcessBrowser_Attach_{Process.GetCurrentProcess().Id}";

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
        SizeChanged += MainWindow_SizeChanged;
        KeyDown += MainWindow_KeyDown;

        _statusTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(2),
        };
        _statusTimer.Tick += StatusTimer_Tick;
        _statusTimer.Start();
    }

    private void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        _hostHwnd = new WindowInteropHelper(this).Handle;
        UpdateStatusBar();

        // 외부 TabChild의 attach 요청을 수신하는 파이프 서버 시작
        _ = ListenForAttachRequestsAsync(_appCts.Token);
    }

    #region Attach Listener

    /// <summary>
    /// 독립 실행 중인 TabChild가 이 호스트에 합류하려 할 때 연결을 수신
    /// </summary>
    private async Task ListenForAttachRequestsAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                var attachServer = new IpcPipeServer(GlobalPipeName);
                await attachServer.StartAsync(ct);

                // 연결이 오면 RequestAttach 메시지를 기다림
                var tcs = new TaskCompletionSource<IpcMessage>();
                attachServer.MessageReceived += msg =>
                {
                    if (msg.Type == IpcMessageType.RequestAttach)
                        tcs.TrySetResult(msg);
                };

                // 5초 타임아웃
                var timeoutTask = Task.Delay(5000, ct);
                var completed = await Task.WhenAny(tcs.Task, timeoutTask);

                if (completed == tcs.Task)
                {
                    var msg = tcs.Task.Result;
                    await Dispatcher.InvokeAsync(() => HandleAttachRequest(msg, attachServer));
                }
                else
                {
                    attachServer.Dispose();
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch
            {
                // 파이프 에러 시 잠시 대기 후 재시도
                try { await Task.Delay(500, ct); } catch { break; }
            }
        }
    }

    private async void HandleAttachRequest(IpcMessage msg, IpcPipeServer attachServer)
    {
        var tabId = msg.TabId;
        if (string.IsNullOrEmpty(tabId))
            tabId = Guid.NewGuid().ToString("N")[..8];

        var tabInfo = new TabInfo { TabId = tabId, Title = "Attaching..." };

        // 새 전용 파이프로 전환
        var pipeName = $"MultiProcessBrowser_{Process.GetCurrentProcess().Id}_{tabId}";
        var pipeServer = new IpcPipeServer(pipeName);
        tabInfo.PipeServer = pipeServer;

        pipeServer.MessageReceived += m => OnChildMessage(tabId, m);
        pipeServer.ClientDisconnected += () => OnChildDisconnected(tabId);

        _tabs[tabId] = tabInfo;
        AddTabButton(tabInfo);

        // child에 새 파이프 이름 전달
        await attachServer.SendAsync(new IpcMessage
        {
            Type = IpcMessageType.AttachAccepted,
            TabId = tabId,
            Data = new Dictionary<string, string>
            {
                ["pipeName"] = pipeName,
            }
        });

        // attach용 파이프는 정리
        attachServer.Dispose();

        // 새 파이프 연결 대기
        try
        {
            await pipeServer.StartAsync(_appCts.Token);
            SwitchToTab(tabId);
            UpdateStatusBar();
            StatusText.Text = $"Tab {tabId} attached from external process";
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Attach failed: {ex.Message}";
            _tabs.Remove(tabId);
            RemoveTabButton(tabId);
        }
    }

    #endregion

    #region Tab Management

    private async Task CreateNewTabAsync()
    {
        var tabId = Guid.NewGuid().ToString("N")[..8];
        var pipeName = $"MultiProcessBrowser_{Process.GetCurrentProcess().Id}_{tabId}";

        var tabInfo = new TabInfo
        {
            TabId = tabId,
            Title = "New Tab",
        };

        var pipeServer = new IpcPipeServer(pipeName);
        tabInfo.PipeServer = pipeServer;

        pipeServer.MessageReceived += msg => OnChildMessage(tabId, msg);
        pipeServer.ClientDisconnected += () => OnChildDisconnected(tabId);

        _tabs[tabId] = tabInfo;
        AddTabButton(tabInfo);
        StatusText.Text = "Creating new tab process...";

        // Pipe 서버를 먼저 시작
        var pipeTask = pipeServer.StartAsync(_appCts.Token);

        // TabChild 프로세스 실행
        var exePath = FindTabChildExe();
        if (exePath == null)
        {
            StatusText.Text = "Error: TabChild.exe not found. Build the TabChild project first.";
            MessageBox.Show(
                "TabChild.exe를 찾을 수 없습니다.\n\n" +
                "솔루션 전체를 빌드한 후 다시 시도해주세요.\n" +
                "dotnet build MultiProcessTabbedBrowser.sln",
                "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            _tabs.Remove(tabId);
            RemoveTabButton(tabId);
            pipeServer.Dispose();
            return;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = exePath,
            Arguments = $"--pipe {pipeName} --tabId {tabId} --hostPid {Process.GetCurrentProcess().Id}",
            UseShellExecute = false,
        };

        try
        {
            var process = Process.Start(startInfo);
            if (process == null)
            {
                StatusText.Text = "Error: Failed to start child process";
                _tabs.Remove(tabId);
                RemoveTabButton(tabId);
                pipeServer.Dispose();
                return;
            }

            tabInfo.ChildProcess = process;
            tabInfo.ChildPid = process.Id;
            StatusText.Text = $"Child process started (PID: {process.Id}), waiting for connection...";

            await pipeTask;
            StatusText.Text = $"Tab {tabId} connected (PID: {process.Id})";

            SwitchToTab(tabId);
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Error starting child: {ex.Message}";
            _tabs.Remove(tabId);
            RemoveTabButton(tabId);
            pipeServer.Dispose();
        }

        UpdateStatusBar();
    }

    private string? FindTabChildExe()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(baseDir, "TabChild.exe"),
            Path.Combine(baseDir, "..", "..", "..", "..",
                "TabChild", "bin", "Debug", "net8.0-windows", "TabChild.exe"),
            Path.Combine(baseDir, "..", "TabChild", "TabChild.exe"),
            Path.Combine(baseDir, "..", "..", "TabChild",
                "bin", "Debug", "net8.0-windows", "TabChild.exe"),
            // Release 빌드 경로
            Path.Combine(baseDir, "..", "..", "..", "..",
                "TabChild", "bin", "Release", "net8.0-windows", "TabChild.exe"),
        };

        return candidates.Select(Path.GetFullPath).FirstOrDefault(File.Exists);
    }

    private void SwitchToTab(string tabId)
    {
        if (!_tabs.ContainsKey(tabId)) return;

        _activeTabId = tabId;

        foreach (var (id, tab) in _tabs)
        {
            if (tab.ChildHwnd == IntPtr.Zero || !tab.IsEmbedded) continue;

            if (id == tabId)
            {
                Win32Api.ShowWindow(tab.ChildHwnd, Win32Api.SW_SHOW);
                ResizeEmbeddedWindow(tab);
            }
            else
            {
                Win32Api.ShowWindow(tab.ChildHwnd, Win32Api.SW_HIDE);
            }
        }

        UpdateTabButtonStyles();
        EmptyState.Visibility = _tabs.Count > 0 ? Visibility.Collapsed : Visibility.Visible;

        var activeTab = _tabs[tabId];
        Title = $"{activeTab.Title} - Multi-Process Browser";
    }

    private async Task CloseTabAsync(string tabId)
    {
        if (!_tabs.TryGetValue(tabId, out var tab)) return;

        if (tab.PipeServer?.IsConnected == true)
        {
            try
            {
                await tab.PipeServer.SendAsync(new IpcMessage
                {
                    Type = IpcMessageType.CloseTab,
                    TabId = tabId,
                });
                // 짧게 대기 후 정리
                await Task.Delay(200);
            }
            catch { }
        }

        tab.Dispose();
        _tabs.Remove(tabId);
        RemoveTabButton(tabId);

        if (_tabs.Count > 0)
        {
            SwitchToTab(_tabs.Keys.Last());
        }
        else
        {
            _activeTabId = null;
            EmptyState.Visibility = Visibility.Visible;
            Title = "Multi-Process Browser";
        }

        UpdateStatusBar();
    }

    private async Task DetachTabAsync(string tabId)
    {
        if (!_tabs.TryGetValue(tabId, out var tab)) return;

        // 자식에게 분리 명령 + 호스트 PID 전달 (나중에 re-attach 할 수 있도록)
        if (tab.PipeServer?.IsConnected == true)
        {
            await tab.PipeServer.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.RequestDetach,
                TabId = tabId,
                Data = new Dictionary<string, string>
                {
                    ["hostPid"] = Process.GetCurrentProcess().Id.ToString(),
                }
            });

            // child가 DetachCompleted를 보낼 때까지 잠깐 대기
            await Task.Delay(300);
        }

        // 파이프 정리 (프로세스는 살려둠)
        tab.PipeServer?.Dispose();
        tab.PipeServer = null;
        tab.IsEmbedded = false;

        // ChildProcess 참조 해제 (Kill하지 않음)
        tab.ChildProcess = null;
        _tabs.Remove(tabId);
        RemoveTabButton(tabId);

        if (_tabs.Count > 0)
        {
            SwitchToTab(_tabs.Keys.Last());
        }
        else
        {
            _activeTabId = null;
            EmptyState.Visibility = Visibility.Visible;
            Title = "Multi-Process Browser";
        }

        UpdateStatusBar();
        StatusText.Text = $"Tab {tabId} detached as standalone window";
    }

    #endregion

    #region IPC Message Handling

    private void OnChildMessage(string tabId, IpcMessage msg)
    {
        Dispatcher.Invoke(() =>
        {
            if (!_tabs.TryGetValue(tabId, out var tab)) return;

            switch (msg.Type)
            {
                case IpcMessageType.WindowHandleReady:
                    HandleWindowHandleReady(tab, msg);
                    break;

                case IpcMessageType.ChildReady:
                    tab.IsReady = true;
                    StatusText.Text = $"Tab {tabId} ready (PID: {tab.ChildPid})";
                    break;

                case IpcMessageType.TitleChanged:
                    if (msg.Data.TryGetValue("title", out var title))
                    {
                        tab.Title = title;
                        UpdateTabButtonTitle(tabId, title);
                        if (tabId == _activeTabId)
                            Title = $"{title} - Multi-Process Browser";
                    }
                    if (msg.Data.TryGetValue("url", out var url))
                        tab.Url = url;
                    break;

                case IpcMessageType.DetachCompleted:
                    StatusText.Text = $"Tab {tabId} detached successfully";
                    break;

                case IpcMessageType.CloseRequested:
                    _ = CloseTabAsync(tabId);
                    break;

                case IpcMessageType.Pong:
                    break;
            }
        });
    }

    private void HandleWindowHandleReady(TabInfo tab, IpcMessage msg)
    {
        if (msg.Data.TryGetValue("hwnd", out var hwndStr) && nint.TryParse(hwndStr, out var hwnd))
            tab.ChildHwnd = hwnd;

        if (msg.Data.TryGetValue("pid", out var pidStr) && int.TryParse(pidStr, out var pid))
        {
            tab.ChildPid = pid;
            // ChildProcess가 없으면 PID로 가져오기 (re-attach 시)
            if (tab.ChildProcess == null)
            {
                try { tab.ChildProcess = Process.GetProcessById(pid); } catch { }
            }
        }

        if (msg.Data.TryGetValue("title", out var title))
        {
            tab.Title = title;
            UpdateTabButtonTitle(tab.TabId, title);
        }

        // 자식 윈도우를 호스트에 임베딩
        if (tab.ChildHwnd != IntPtr.Zero)
        {
            Win32Api.EmbedWindow(tab.ChildHwnd, _hostHwnd);
            tab.IsEmbedded = true;

            // 현재 활성 탭이면 보이고 아니면 숨기기
            if (tab.TabId == _activeTabId)
            {
                Win32Api.ShowWindow(tab.ChildHwnd, Win32Api.SW_SHOW);
                ResizeEmbeddedWindow(tab);
            }
            else
            {
                Win32Api.ShowWindow(tab.ChildHwnd, Win32Api.SW_HIDE);
            }

            StatusText.Text = $"Tab embedded (PID: {tab.ChildPid}, HWND: 0x{tab.ChildHwnd:X})";
        }
    }

    private void OnChildDisconnected(string tabId)
    {
        Dispatcher.Invoke(() =>
        {
            if (!_tabs.ContainsKey(tabId)) return;
            StatusText.Text = $"Tab {tabId} process disconnected";
            _ = CloseTabAsync(tabId);
        });
    }

    #endregion

    #region Window Management

    private void ResizeEmbeddedWindow(TabInfo tab)
    {
        if (tab.ChildHwnd == IntPtr.Zero || !tab.IsEmbedded) return;

        // ContentHost의 스크린 좌표를 구하고, 부모 윈도우(hostHwnd)의 클라이언트 좌표로 변환
        var screenPoint = ContentHost.PointToScreen(new Point(0, 0));
        var pt = new Win32Api.POINT
        {
            X = (int)screenPoint.X,
            Y = (int)screenPoint.Y,
        };
        Win32Api.ScreenToClient(_hostHwnd, ref pt);

        var dpi = VisualTreeHelper.GetDpi(this);
        var width = (int)(ContentHost.ActualWidth * dpi.DpiScaleX);
        var height = (int)(ContentHost.ActualHeight * dpi.DpiScaleY);

        Win32Api.MoveWindow(tab.ChildHwnd, pt.X, pt.Y, width, height, true);
    }

    private void MainWindow_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        // 활성 탭의 임베딩된 윈도우 크기 조정
        if (_activeTabId != null && _tabs.TryGetValue(_activeTabId, out var tab))
        {
            ResizeEmbeddedWindow(tab);
        }
    }

    #endregion

    #region Tab Bar UI

    private void AddTabButton(TabInfo tab)
    {
        var tabButton = new Border
        {
            Tag = tab.TabId,
            Background = new SolidColorBrush(Color.FromRgb(0x2D, 0x2D, 0x44)),
            CornerRadius = new CornerRadius(6, 6, 0, 0),
            Margin = new Thickness(2, 0, 0, 0),
            Padding = new Thickness(4, 4, 4, 4),
            MinWidth = 120,
            MaxWidth = 240,
            Cursor = Cursors.Hand,
        };

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var titleBlock = new TextBlock
        {
            Text = tab.Title,
            Foreground = Brushes.White,
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(8, 0, 4, 0),
        };
        Grid.SetColumn(titleBlock, 0);

        var closeBtn = new Button
        {
            Content = "\u2715",
            FontSize = 10,
            Width = 20,
            Height = 20,
            Background = Brushes.Transparent,
            Foreground = new SolidColorBrush(Color.FromRgb(0x88, 0x88, 0xAA)),
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            Tag = tab.TabId,
            VerticalAlignment = VerticalAlignment.Center,
        };
        closeBtn.Click += TabCloseButton_Click;
        Grid.SetColumn(closeBtn, 1);

        grid.Children.Add(titleBlock);
        grid.Children.Add(closeBtn);
        tabButton.Child = grid;

        tabButton.MouseLeftButtonDown += TabButton_MouseLeftButtonDown;
        tabButton.MouseMove += TabButton_MouseMove;

        TabBar.Children.Add(tabButton);
        EmptyState.Visibility = Visibility.Collapsed;
    }

    private void RemoveTabButton(string tabId)
    {
        var toRemove = TabBar.Children.OfType<Border>()
            .FirstOrDefault(b => b.Tag as string == tabId);
        if (toRemove != null)
            TabBar.Children.Remove(toRemove);
    }

    private void UpdateTabButtonTitle(string tabId, string title)
    {
        var tabBorder = TabBar.Children.OfType<Border>()
            .FirstOrDefault(b => b.Tag as string == tabId);
        if (tabBorder?.Child is Grid grid)
        {
            var textBlock = grid.Children.OfType<TextBlock>().FirstOrDefault();
            if (textBlock != null)
                textBlock.Text = title;
        }
    }

    private void UpdateTabButtonStyles()
    {
        foreach (var border in TabBar.Children.OfType<Border>())
        {
            var isActive = border.Tag as string == _activeTabId;
            border.Background = new SolidColorBrush(
                isActive ? Color.FromRgb(0x28, 0x28, 0x40) : Color.FromRgb(0x2D, 0x2D, 0x44));
        }
    }

    #endregion

    #region Event Handlers

    private void TabButton_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (sender is Border border && border.Tag is string tabId)
        {
            SwitchToTab(tabId);
        }
    }

    private Point _dragStartPoint;
    private bool _isDragging;

    private void TabButton_MouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        if (sender is not Border border || border.Tag is not string tabId) return;

        var currentPos = e.GetPosition(this);

        if (!_isDragging)
        {
            _dragStartPoint = currentPos;
            _isDragging = true;
            return;
        }

        var diff = currentPos - _dragStartPoint;
        if (Math.Abs(diff.Y) > 40 || Math.Abs(diff.X) > 80)
        {
            _isDragging = false;

            // 탭이 1개뿐이면 분리하지 않음
            if (_tabs.Count <= 1) return;

            var data = new DataObject("TabId", tabId);
            var result = DragDrop.DoDragDrop(border, data, DragDropEffects.Move);

            // 드롭이 자기 윈도우 밖에서 일어나면 (DragDropEffects.None) 탭 분리
            if (result == DragDropEffects.None)
            {
                _ = DetachTabAsync(tabId);
            }
        }
    }

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent("TabId"))
        {
            e.Effects = DragDropEffects.Move;
        }
        else
        {
            e.Effects = DragDropEffects.None;
        }
        e.Handled = true;
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
        // 탭이 같은 윈도우 내에서 드롭되면 아무것도 하지 않음 (이미 존재하는 탭)
        if (e.Data.GetDataPresent("TabId"))
        {
            e.Effects = DragDropEffects.Move;
            e.Handled = true;
        }
    }

    private void TabCloseButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string tabId)
        {
            _ = CloseTabAsync(tabId);
            e.Handled = true;
        }
    }

    private async void NewTabButton_Click(object sender, RoutedEventArgs e)
    {
        await CreateNewTabAsync();
    }

    private async void MainWindow_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.T && Keyboard.Modifiers == ModifierKeys.Control)
        {
            await CreateNewTabAsync();
            e.Handled = true;
        }
        else if (e.Key == Key.W && Keyboard.Modifiers == ModifierKeys.Control)
        {
            if (_activeTabId != null)
                await CloseTabAsync(_activeTabId);
            e.Handled = true;
        }
        else if (e.Key == Key.Tab && Keyboard.Modifiers == (ModifierKeys.Control | ModifierKeys.Shift))
        {
            CycleTab(forward: false);
            e.Handled = true;
        }
        else if (e.Key == Key.Tab && Keyboard.Modifiers == ModifierKeys.Control)
        {
            CycleTab(forward: true);
            e.Handled = true;
        }
        else if (e.Key == Key.D && Keyboard.Modifiers == ModifierKeys.Control)
        {
            if (_activeTabId != null && _tabs.Count > 1)
                await DetachTabAsync(_activeTabId);
            e.Handled = true;
        }
    }

    private void CycleTab(bool forward)
    {
        if (_tabs.Count <= 1 || _activeTabId == null) return;

        var keys = _tabs.Keys.ToList();
        var idx = keys.IndexOf(_activeTabId);

        idx = forward
            ? (idx + 1) % keys.Count
            : (idx - 1 + keys.Count) % keys.Count;

        SwitchToTab(keys[idx]);
    }

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
            MaximizeButton_Click(sender, e);
        else
            DragMove();
    }

    private void MinimizeButton_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState.Minimized;

    private void MaximizeButton_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;

    private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();

    private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _statusTimer.Stop();
        _appCts.Cancel();

        foreach (var tab in _tabs.Values.ToList())
        {
            tab.Dispose();
        }
        _tabs.Clear();
    }

    #endregion

    #region Status Bar

    private void StatusTimer_Tick(object? sender, EventArgs e)
    {
        UpdateStatusBar();

        var deadTabs = _tabs
            .Where(kv => kv.Value.ChildProcess is { HasExited: true })
            .Select(kv => kv.Key)
            .ToList();

        foreach (var tabId in deadTabs)
        {
            _ = CloseTabAsync(tabId);
        }
    }

    private void UpdateStatusBar()
    {
        TabCountText.Text = $"{_tabs.Count} tab{(_tabs.Count == 1 ? "" : "s")}";

        var processCount = _tabs.Values
            .Select(t => t.ChildPid)
            .Where(pid => pid > 0)
            .Distinct()
            .Count();
        ProcessCountText.Text = $"{processCount + 1} process{(processCount + 1 == 1 ? "" : "es")}";

        try
        {
            var totalMemory = Process.GetCurrentProcess().WorkingSet64;
            foreach (var tab in _tabs.Values)
            {
                if (tab.ChildProcess is { HasExited: false })
                {
                    tab.ChildProcess.Refresh();
                    totalMemory += tab.ChildProcess.WorkingSet64;
                }
            }
            MemoryText.Text = $"{totalMemory / 1024 / 1024} MB total";
        }
        catch { }
    }

    #endregion
}
