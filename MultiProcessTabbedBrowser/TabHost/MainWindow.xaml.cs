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

    // TabChild 실행 파일 경로 (빌드 출력 기준)
    private string TabChildExePath =>
        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..",
            "TabChild", "bin", "Debug", "net8.0-windows", "TabChild.exe");

    // 대체 경로: 같은 디렉토리에 있을 경우
    private string TabChildExePathAlt =>
        Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "TabChild.exe");

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
        SizeChanged += MainWindow_SizeChanged;

        // 키보드 단축키
        KeyDown += MainWindow_KeyDown;

        // 상태 업데이트 타이머
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
    }

    #region Tab Management

    /// <summary>
    /// 새 탭 생성 - 별도 프로세스로 TabChild를 실행하고 Named Pipe로 연결
    /// </summary>
    private async Task CreateNewTabAsync()
    {
        var tabId = Guid.NewGuid().ToString("N")[..8];
        var pipeName = $"MultiProcessBrowser_{Process.GetCurrentProcess().Id}_{tabId}";

        var tabInfo = new TabInfo
        {
            TabId = tabId,
            Title = "New Tab",
        };

        // 1. Named Pipe 서버 시작
        var pipeServer = new IpcPipeServer(pipeName);
        tabInfo.PipeServer = pipeServer;

        pipeServer.MessageReceived += msg => OnChildMessage(tabId, msg);
        pipeServer.ClientDisconnected += () => OnChildDisconnected(tabId);

        _tabs[tabId] = tabInfo;

        // UI에 탭 버튼 추가
        AddTabButton(tabInfo);

        StatusText.Text = $"Creating new tab process...";

        // 2. Pipe 서버를 백그라운드에서 대기 시작
        var pipeTask = pipeServer.StartAsync();

        // 3. TabChild 프로세스 실행
        var exePath = FindTabChildExe();
        if (exePath == null)
        {
            StatusText.Text = "Error: TabChild.exe not found. Please build the TabChild project first.";
            MessageBox.Show(
                "TabChild.exe를 찾을 수 없습니다.\n\n" +
                "솔루션 전체를 빌드한 후 다시 시도해주세요.\n" +
                "dotnet build MultiProcessTabbedBrowser.sln",
                "오류", MessageBoxButton.OK, MessageBoxImage.Error);
            _tabs.Remove(tabId);
            return;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = exePath,
            Arguments = $"--pipe {pipeName} --tabId {tabId}",
            UseShellExecute = false,
        };

        try
        {
            var process = Process.Start(startInfo);
            if (process == null)
            {
                StatusText.Text = "Error: Failed to start child process";
                return;
            }

            tabInfo.ChildProcess = process;
            tabInfo.ChildPid = process.Id;
            StatusText.Text = $"Child process started (PID: {process.Id}), waiting for connection...";

            // 4. 파이프 연결 대기
            await pipeTask;
            StatusText.Text = $"Tab {tabId} connected (PID: {process.Id})";

            // 활성 탭으로 전환
            SwitchToTab(tabId);
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Error starting child: {ex.Message}";
            _tabs.Remove(tabId);
        }

        UpdateStatusBar();
    }

    private string? FindTabChildExe()
    {
        // 여러 경로에서 TabChild.exe 탐색
        var candidates = new[]
        {
            TabChildExePath,
            TabChildExePathAlt,
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "TabChild", "TabChild.exe"),
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "TabChild",
                "bin", "Debug", "net8.0-windows", "TabChild.exe"),
        };

        return candidates.FirstOrDefault(File.Exists);
    }

    /// <summary>
    /// 탭 전환 - 해당 자식 프로세스의 윈도우를 보이게 하고 나머지는 숨김
    /// </summary>
    private void SwitchToTab(string tabId)
    {
        if (!_tabs.ContainsKey(tabId)) return;

        _activeTabId = tabId;

        foreach (var (id, tab) in _tabs)
        {
            if (tab.ChildHwnd != IntPtr.Zero)
            {
                if (id == tabId)
                {
                    // 활성 탭: 보이기 및 크기 조정
                    Win32Api.ShowWindow(tab.ChildHwnd, Win32Api.SW_SHOW);
                    ResizeEmbeddedWindow(tab);
                }
                else
                {
                    // 비활성 탭: 숨기기
                    Win32Api.ShowWindow(tab.ChildHwnd, Win32Api.SW_HIDE);
                }
            }
        }

        // 탭 버튼 UI 갱신
        UpdateTabButtonStyles();
        EmptyState.Visibility = _tabs.Count > 0 ? Visibility.Collapsed : Visibility.Visible;

        // 제목 표시줄 갱신
        var activeTab = _tabs[tabId];
        Title = $"{activeTab.Title} - Multi-Process Browser";
    }

    /// <summary>
    /// 탭 닫기 - 자식 프로세스 종료
    /// </summary>
    private async Task CloseTabAsync(string tabId)
    {
        if (!_tabs.TryGetValue(tabId, out var tab)) return;

        // 자식 프로세스에 닫기 명령
        if (tab.PipeServer?.IsConnected == true)
        {
            await tab.PipeServer.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.CloseTab,
                TabId = tabId,
            });
        }

        // 정리
        tab.Dispose();
        _tabs.Remove(tabId);

        // 탭 버튼 제거
        RemoveTabButton(tabId);

        // 다른 탭으로 전환
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

    /// <summary>
    /// 탭을 별도 윈도우로 분리 (드래그 아웃)
    /// </summary>
    private async Task DetachTabAsync(string tabId)
    {
        if (!_tabs.TryGetValue(tabId, out var tab)) return;

        // 자식 프로세스에 분리 명령
        if (tab.PipeServer?.IsConnected == true)
        {
            await tab.PipeServer.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.RequestDetach,
                TabId = tabId,
            });
        }

        tab.IsEmbedded = false;

        // 탭 정보에서 제거 (프로세스는 유지)
        tab.PipeServer?.Dispose();
        tab.PipeServer = null;
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

    /// <summary>
    /// 외부 프로세스(독립 실행 중인 TabChild)를 탭으로 합치기
    /// </summary>
    public void AttachExternalProcess(int pid)
    {
        try
        {
            var process = Process.GetProcessById(pid);
            if (process.MainWindowHandle == IntPtr.Zero)
            {
                StatusText.Text = $"Process {pid} has no visible window";
                return;
            }

            var tabId = Guid.NewGuid().ToString("N")[..8];
            var tabInfo = new TabInfo
            {
                TabId = tabId,
                Title = process.MainWindowTitle,
                ChildHwnd = process.MainWindowHandle,
                ChildPid = pid,
                ChildProcess = process,
                IsEmbedded = true,
                IsReady = true,
            };

            _tabs[tabId] = tabInfo;

            // Win32 API로 임베딩
            var hostContentHwnd = GetContentHostHwnd();
            Win32Api.EmbedWindow(tabInfo.ChildHwnd, hostContentHwnd);

            AddTabButton(tabInfo);
            SwitchToTab(tabId);

            UpdateStatusBar();
            StatusText.Text = $"Attached process {pid} as tab";
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Failed to attach process: {ex.Message}";
        }
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
                        {
                            Title = $"{title} - Multi-Process Browser";
                        }
                    }
                    if (msg.Data.TryGetValue("url", out var url))
                    {
                        tab.Url = url;
                    }
                    break;

                case IpcMessageType.DetachCompleted:
                    StatusText.Text = $"Tab {tabId} detached successfully";
                    break;

                case IpcMessageType.CloseRequested:
                    _ = CloseTabAsync(tabId);
                    break;

                case IpcMessageType.Pong:
                    StatusText.Text = $"Tab {tabId} responded to ping";
                    break;
            }
        });
    }

    private void HandleWindowHandleReady(TabInfo tab, IpcMessage msg)
    {
        if (msg.Data.TryGetValue("hwnd", out var hwndStr) && nint.TryParse(hwndStr, out var hwnd))
        {
            tab.ChildHwnd = hwnd;
        }

        if (msg.Data.TryGetValue("pid", out var pidStr) && int.TryParse(pidStr, out var pid))
        {
            tab.ChildPid = pid;
        }

        if (msg.Data.TryGetValue("title", out var title))
        {
            tab.Title = title;
        }

        // 자식 윈도우를 호스트에 임베딩
        if (tab.ChildHwnd != IntPtr.Zero)
        {
            var hostContentHwnd = GetContentHostHwnd();
            Win32Api.EmbedWindow(tab.ChildHwnd, hostContentHwnd);
            tab.IsEmbedded = true;

            ResizeEmbeddedWindow(tab);

            // 현재 활성 탭이면 보이고 아니면 숨기기
            if (tab.TabId != _activeTabId)
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
            StatusText.Text = $"Tab {tabId} process disconnected";
            _ = CloseTabAsync(tabId);
        });
    }

    #endregion

    #region Window Management

    private IntPtr GetContentHostHwnd()
    {
        // ContentGrid의 Win32 핸들을 사용
        var source = PresentationSource.FromVisual(ContentGrid) as HwndSource;
        return source?.Handle ?? _hostHwnd;
    }

    private void ResizeEmbeddedWindow(TabInfo tab)
    {
        if (tab.ChildHwnd == IntPtr.Zero || !tab.IsEmbedded) return;

        // ContentHost의 실제 렌더링 크기 계산
        var point = ContentHost.PointToScreen(new Point(0, 0));
        var hostPoint = this.PointToScreen(new Point(0, 0));

        var dpi = VisualTreeHelper.GetDpi(this);
        var width = (int)(ContentHost.ActualWidth * dpi.DpiScaleX);
        var height = (int)(ContentHost.ActualHeight * dpi.DpiScaleY);
        var x = (int)((point.X - hostPoint.X) * dpi.DpiScaleX);
        var y = (int)((point.Y - hostPoint.Y) * dpi.DpiScaleY);

        // 자식 윈도우를 호스트 윈도우 좌표 기준으로 배치
        // SetParent로 임베딩 시, 좌표는 부모 클라이언트 영역 기준
        Win32Api.MoveWindow(tab.ChildHwnd, x, y, width, height, true);
    }

    private void MainWindow_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        // 모든 임베딩된 자식 윈도우의 크기 재조정
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
            Name = $"Tab_{tab.TabId}",
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

        // 탭 제목
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

        // 닫기 버튼
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

        // 클릭 이벤트: 탭 전환
        tabButton.MouseLeftButtonDown += TabButton_MouseLeftButtonDown;

        // 드래그 시작: 탭 분리
        tabButton.MouseMove += TabButton_MouseMove;

        TabBar.Children.Add(tabButton);
        EmptyState.Visibility = Visibility.Collapsed;
    }

    private void RemoveTabButton(string tabId)
    {
        var toRemove = TabBar.Children.OfType<Border>()
            .FirstOrDefault(b => b.Tag as string == tabId);
        if (toRemove != null)
        {
            TabBar.Children.Remove(toRemove);
        }
    }

    private void UpdateTabButtonTitle(string tabId, string title)
    {
        var tabBorder = TabBar.Children.OfType<Border>()
            .FirstOrDefault(b => b.Tag as string == tabId);
        if (tabBorder?.Child is Grid grid)
        {
            var textBlock = grid.Children.OfType<TextBlock>().FirstOrDefault();
            if (textBlock != null)
            {
                textBlock.Text = title;
            }
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

        // 30px 이상 드래그하면 탭 분리
        var diff = currentPos - _dragStartPoint;
        if (Math.Abs(diff.Y) > 30 || Math.Abs(diff.X) > 60)
        {
            _isDragging = false;

            // 탭이 1개 뿐이면 분리하지 않음
            if (_tabs.Count <= 1) return;

            // DataObject로 드래그 시작 (외부 윈도우에 드롭 가능)
            var data = new DataObject("TabId", tabId);
            DragDrop.DoDragDrop(border, data, DragDropEffects.Move);
        }
    }

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent("TabId") || e.Data.GetDataPresent("ProcessId"))
        {
            e.Effects = DragDropEffects.Move;
        }
        else
        {
            e.Effects = DragDropEffects.None;
        }
        e.Handled = true;
    }

    private async void Window_Drop(object sender, DragEventArgs e)
    {
        // 탭 드래그 앤 드롭으로 분리
        if (e.Data.GetDataPresent("TabId"))
        {
            var tabId = e.Data.GetData("TabId") as string;
            if (tabId != null)
            {
                await DetachTabAsync(tabId);
            }
        }
        // 외부 프로세스 드롭으로 합치기 (PID 전달 시)
        else if (e.Data.GetDataPresent("ProcessId"))
        {
            var pidStr = e.Data.GetData("ProcessId") as string;
            if (pidStr != null && int.TryParse(pidStr, out var pid))
            {
                AttachExternalProcess(pid);
            }
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
        // Ctrl+T: 새 탭
        if (e.Key == Key.T && Keyboard.Modifiers == ModifierKeys.Control)
        {
            await CreateNewTabAsync();
            e.Handled = true;
        }
        // Ctrl+W: 탭 닫기
        else if (e.Key == Key.W && Keyboard.Modifiers == ModifierKeys.Control)
        {
            if (_activeTabId != null)
            {
                await CloseTabAsync(_activeTabId);
            }
            e.Handled = true;
        }
        // Ctrl+Tab: 다음 탭
        else if (e.Key == Key.Tab && Keyboard.Modifiers == ModifierKeys.Control)
        {
            CycleTab(forward: true);
            e.Handled = true;
        }
        // Ctrl+Shift+Tab: 이전 탭
        else if (e.Key == Key.Tab && Keyboard.Modifiers == (ModifierKeys.Control | ModifierKeys.Shift))
        {
            CycleTab(forward: false);
            e.Handled = true;
        }
        // Ctrl+D: 현재 탭 분리
        else if (e.Key == Key.D && Keyboard.Modifiers == ModifierKeys.Control)
        {
            if (_activeTabId != null && _tabs.Count > 1)
            {
                await DetachTabAsync(_activeTabId);
            }
            e.Handled = true;
        }
    }

    private void CycleTab(bool forward)
    {
        if (_tabs.Count <= 1 || _activeTabId == null) return;

        var keys = _tabs.Keys.ToList();
        var idx = keys.IndexOf(_activeTabId);

        if (forward)
            idx = (idx + 1) % keys.Count;
        else
            idx = (idx - 1 + keys.Count) % keys.Count;

        SwitchToTab(keys[idx]);
    }

    // 제목 표시줄 드래그로 윈도우 이동
    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            MaximizeButton_Click(sender, e);
        }
        else
        {
            DragMove();
        }
    }

    private void MinimizeButton_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState.Minimized;

    private void MaximizeButton_Click(object sender, RoutedEventArgs e) =>
        WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;

    private void CloseButton_Click(object sender, RoutedEventArgs e) => Close();

    private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _statusTimer.Stop();

        // 모든 자식 프로세스 종료
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

        // 죽은 프로세스 정리
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

        // 전체 메모리 사용량
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
