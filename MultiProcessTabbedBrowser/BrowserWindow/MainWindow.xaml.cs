using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using SharedLib;

namespace BrowserWindow;

public partial class MainWindow : Window
{
    private const string SelfTabId = "__self__";

    // === This window's identity ===
    private IntPtr _hwnd;
    private readonly int _pid = Process.GetCurrentProcess().Id;

    // === Hosting state: tabs I'm hosting ===
    private readonly Dictionary<string, PeerTabInfo> _hostedTabs = new();
    private string _activeTabId = SelfTabId;

    // === Embedded state: when docked into another window ===
    private bool _isEmbedded;
    private IpcPipeClient? _hostPipe;
    private string _myTabIdInHost = string.Empty;

    // === Attach listener: accept dock requests from other windows ===
    private readonly CancellationTokenSource _appCts = new();
    private string AttachPipeName => $"BrowserWindow_Attach_{_pid}";

    // === Local content ===
    private string _currentUrl = "about:blank";

    // === UI timer ===
    private readonly DispatcherTimer _statusTimer;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
        SizeChanged += MainWindow_SizeChanged;
        KeyDown += MainWindow_KeyDown;

        _statusTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _statusTimer.Tick += StatusTimer_Tick;
        _statusTimer.Start();
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        _hwnd = new WindowInteropHelper(this).Handle;
        PidDisplay.Text = $"PID: {_pid}";
        Title = $"Browser Window (PID: {_pid})";
        TitleText.Text = Title;

        UpdateProcessInfo();
        AddSelfTab();

        // Attach 리스너 시작 (다른 윈도우가 dock 요청을 보낼 수 있도록)
        _ = ListenForAttachRequestsAsync(_appCts.Token);

        // 커맨드라인으로 dock 요청이 온 경우 자동 dock
        if (App.DockToPipe != null)
        {
            _myTabIdInHost = App.InitialTabId ?? Guid.NewGuid().ToString("N")[..8];
            await ConnectAsEmbedded(App.DockToPipe);
        }

        RefreshAvailablePeers();
    }

    #region Self Tab

    private void AddSelfTab()
    {
        var selfTab = new Border
        {
            Tag = SelfTabId,
            Background = new SolidColorBrush(Color.FromRgb(0x28, 0x28, 0x40)),
            CornerRadius = new CornerRadius(6, 6, 0, 0),
            Margin = new Thickness(2, 0, 0, 0),
            Padding = new Thickness(4),
            MinWidth = 100,
            MaxWidth = 200,
            Cursor = Cursors.Hand,
        };

        var titleBlock = new TextBlock
        {
            Text = $"This Window",
            Foreground = Brushes.White,
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(8, 0, 8, 0),
        };

        selfTab.Child = titleBlock;
        selfTab.MouseLeftButtonDown += (s, ev) => SwitchToTab(SelfTabId);
        TabBar.Children.Add(selfTab);
    }

    #endregion

    #region Attach Listener (accept dock requests)

    private async Task ListenForAttachRequestsAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                var attachServer = new IpcPipeServer(AttachPipeName);
                await attachServer.StartAsync(ct);

                var tcs = new TaskCompletionSource<IpcMessage>();
                attachServer.MessageReceived += msg =>
                {
                    if (msg.Type == IpcMessageType.RequestAttach)
                        tcs.TrySetResult(msg);
                };

                var timeoutTask = Task.Delay(5000, ct);
                var completed = await Task.WhenAny(tcs.Task, timeoutTask);

                if (completed == tcs.Task)
                {
                    var msg = tcs.Task.Result;
                    await Dispatcher.InvokeAsync(() => HandleIncomingDockRequest(msg, attachServer));
                }
                else
                {
                    attachServer.Dispose();
                }
            }
            catch (OperationCanceledException) { break; }
            catch
            {
                try { await Task.Delay(500, ct); } catch { break; }
            }
        }
    }

    private async void HandleIncomingDockRequest(IpcMessage msg, IpcPipeServer attachServer)
    {
        var tabId = Guid.NewGuid().ToString("N")[..8];
        var pipeName = $"BrowserWindow_Tab_{_pid}_{tabId}";

        var tabInfo = new PeerTabInfo
        {
            TabId = tabId,
            Title = msg.Data.GetValueOrDefault("title", "Window"),
        };

        if (msg.Data.TryGetValue("pid", out var pidStr) && int.TryParse(pidStr, out var pid))
        {
            tabInfo.PeerPid = pid;
            try { tabInfo.PeerProcess = Process.GetProcessById(pid); } catch { }
        }

        var pipeServer = new IpcPipeServer(pipeName);
        tabInfo.PipeServer = pipeServer;
        pipeServer.MessageReceived += m => OnHostedPeerMessage(tabId, m);
        pipeServer.ClientDisconnected += () => OnHostedPeerDisconnected(tabId);

        _hostedTabs[tabId] = tabInfo;
        AddHostedTabButton(tabInfo);

        // 상대에게 새 파이프 이름 전달
        await attachServer.SendAsync(new IpcMessage
        {
            Type = IpcMessageType.AttachAccepted,
            TabId = tabId,
            Data = new Dictionary<string, string> { ["pipeName"] = pipeName }
        });
        attachServer.Dispose();

        try
        {
            await pipeServer.StartAsync(_appCts.Token);
            StatusText.Text = $"Peer PID:{tabInfo.PeerPid} docked as tab {tabId}";
            SwitchToTab(tabId);
            UpdateStatusBar();
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Dock accept failed: {ex.Message}";
            _hostedTabs.Remove(tabId);
            RemoveTabButton(tabId);
            pipeServer.Dispose();
        }
    }

    #endregion

    #region Dock into another window (become embedded)

    private async Task DockIntoAsync(int targetPid)
    {
        if (targetPid == _pid)
        {
            StatusText.Text = "Cannot dock into self";
            return;
        }

        // 현재 호스팅 중인 탭들을 모두 해제 (standalone으로 전환)
        await ReleaseAllHostedTabsAsync();

        StatusText.Text = $"Requesting dock into PID:{targetPid}...";

        try
        {
            var attachPipe = $"BrowserWindow_Attach_{targetPid}";
            var attachClient = new IpcPipeClient(attachPipe);
            await attachClient.ConnectAsync(3000);

            await attachClient.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.RequestAttach,
                Data = new Dictionary<string, string>
                {
                    ["pid"] = _pid.ToString(),
                    ["hwnd"] = _hwnd.ToString(),
                    ["title"] = GetCurrentTitle(),
                }
            });

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

                _myTabIdInHost = response.TabId;
                if (response.Data.TryGetValue("pipeName", out var newPipe))
                {
                    await ConnectAsEmbedded(newPipe);
                }
            }
            else
            {
                attachClient.Dispose();
                StatusText.Text = "Dock request timed out";
            }
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Dock failed: {ex.Message}";
        }
    }

    private async Task ConnectAsEmbedded(string pipeName)
    {
        try
        {
            _hostPipe?.Dispose();
            _hostPipe = new IpcPipeClient(pipeName);
            _hostPipe.MessageReceived += OnHostMessage;
            _hostPipe.Disconnected += OnHostDisconnected;

            await _hostPipe.ConnectAsync();

            // 핸들 전달
            await _hostPipe.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.WindowHandleReady,
                TabId = _myTabIdInHost,
                Data = new Dictionary<string, string>
                {
                    ["hwnd"] = _hwnd.ToString(),
                    ["pid"] = _pid.ToString(),
                    ["title"] = GetCurrentTitle(),
                }
            });

            await _hostPipe.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.Ready,
                TabId = _myTabIdInHost,
            });

            EnterEmbeddedMode();
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Embed connection failed: {ex.Message}";
            _hostPipe?.Dispose();
            _hostPipe = null;
        }
    }

    private void EnterEmbeddedMode()
    {
        _isEmbedded = true;

        // 타이틀바와 탭바 숨김
        TitleBarArea.Visibility = Visibility.Collapsed;
        TabBarArea.Visibility = Visibility.Collapsed;

        // 자신의 탭만 보이게 (호스팅 탭은 이미 해제됨)
        SwitchToTab(SelfTabId);

        ModeText.Text = "Embedded";
        ModeText.Foreground = System.Windows.Media.Brushes.Yellow;
        StatusText.Text = "Embedded in host window";
        UpdateProcessInfo();
    }

    private void ExitEmbeddedMode()
    {
        _isEmbedded = false;

        // 윈도우 분리
        Win32Api.DetachWindow(_hwnd);
        Win32Api.GetCursorPos(out var cursor);
        Left = cursor.X - 100;
        Top = cursor.Y - 20;
        Width = 1100;
        Height = 700;

        // UI 복원
        TitleBarArea.Visibility = Visibility.Visible;
        TabBarArea.Visibility = Visibility.Visible;

        ModeText.Text = "Standalone";
        ModeText.Foreground = System.Windows.Media.Brushes.LimeGreen;
        StatusText.Text = "Detached - running standalone";

        // 파이프 정리
        _hostPipe?.Dispose();
        _hostPipe = null;

        UpdateProcessInfo();
        RefreshAvailablePeers();
    }

    #endregion

    #region Host: manage embedded peers

    private void OnHostedPeerMessage(string tabId, IpcMessage msg)
    {
        Dispatcher.Invoke(() =>
        {
            if (!_hostedTabs.TryGetValue(tabId, out var tab)) return;

            switch (msg.Type)
            {
                case IpcMessageType.WindowHandleReady:
                    HandlePeerWindowReady(tab, msg);
                    break;

                case IpcMessageType.Ready:
                    tab.IsReady = true;
                    StatusText.Text = $"Tab {tabId} (PID:{tab.PeerPid}) ready";
                    break;

                case IpcMessageType.TitleChanged:
                    if (msg.Data.TryGetValue("title", out var title))
                    {
                        tab.Title = title;
                        UpdateTabButtonTitle(tabId, title);
                        if (tabId == _activeTabId)
                            UpdateWindowTitle();
                    }
                    break;

                case IpcMessageType.DetachCompleted:
                    FinalizeTabRemoval(tabId, killProcess: false);
                    break;

                case IpcMessageType.CloseRequested:
                    FinalizeTabRemoval(tabId, killProcess: false);
                    break;

                case IpcMessageType.Pong:
                    break;
            }
        });
    }

    private void HandlePeerWindowReady(PeerTabInfo tab, IpcMessage msg)
    {
        if (msg.Data.TryGetValue("hwnd", out var hwndStr) && nint.TryParse(hwndStr, out var hwnd))
            tab.PeerHwnd = hwnd;

        if (msg.Data.TryGetValue("pid", out var pidStr) && int.TryParse(pidStr, out var pid))
        {
            tab.PeerPid = pid;
            if (tab.PeerProcess == null)
                try { tab.PeerProcess = Process.GetProcessById(pid); } catch { }
        }

        if (msg.Data.TryGetValue("title", out var title))
        {
            tab.Title = title;
            UpdateTabButtonTitle(tab.TabId, title);
        }

        if (tab.PeerHwnd != IntPtr.Zero)
        {
            Win32Api.EmbedWindow(tab.PeerHwnd, _hwnd);
            tab.IsEmbedded = true;

            if (tab.TabId == _activeTabId)
            {
                Win32Api.ShowWindow(tab.PeerHwnd, Win32Api.SW_SHOW);
                ResizeEmbeddedPeer(tab);
            }
            else
            {
                Win32Api.ShowWindow(tab.PeerHwnd, Win32Api.SW_HIDE);
            }

            StatusText.Text = $"Peer embedded (PID:{tab.PeerPid}, HWND:0x{tab.PeerHwnd:X})";
        }
    }

    private void OnHostedPeerDisconnected(string tabId)
    {
        Dispatcher.Invoke(() =>
        {
            if (!_hostedTabs.ContainsKey(tabId)) return;
            StatusText.Text = $"Tab {tabId} disconnected";
            FinalizeTabRemoval(tabId, killProcess: false);
        });
    }

    private async Task DetachHostedTabAsync(string tabId)
    {
        if (!_hostedTabs.TryGetValue(tabId, out var tab)) return;

        if (tab.PipeServer?.IsConnected == true)
        {
            await tab.PipeServer.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.RequestDetach,
                TabId = tabId,
            });
            await Task.Delay(300);
        }

        // 프로세스는 살려둠
        tab.PeerProcess = null;
        tab.PipeServer?.Dispose();
        tab.PipeServer = null;
        tab.IsEmbedded = false;

        _hostedTabs.Remove(tabId);
        RemoveTabButton(tabId);

        if (_activeTabId == tabId)
            SwitchToTab(_hostedTabs.Count > 0 ? _hostedTabs.Keys.Last() : SelfTabId);

        UpdateStatusBar();
        StatusText.Text = $"Tab {tabId} detached";
    }

    private void FinalizeTabRemoval(string tabId, bool killProcess)
    {
        if (!_hostedTabs.TryGetValue(tabId, out var tab)) return;

        if (!killProcess)
            tab.PeerProcess = null;

        tab.Dispose();
        _hostedTabs.Remove(tabId);
        RemoveTabButton(tabId);

        if (_activeTabId == tabId)
            SwitchToTab(_hostedTabs.Count > 0 ? _hostedTabs.Keys.Last() : SelfTabId);

        UpdateStatusBar();
    }

    private async Task CloseHostedTabAsync(string tabId)
    {
        if (!_hostedTabs.TryGetValue(tabId, out var tab)) return;

        if (tab.PipeServer?.IsConnected == true)
        {
            try
            {
                await tab.PipeServer.SendAsync(new IpcMessage
                {
                    Type = IpcMessageType.CloseTab,
                    TabId = tabId,
                });
                await Task.Delay(200);
            }
            catch { }
        }

        FinalizeTabRemoval(tabId, killProcess: true);
    }

    private async Task ReleaseAllHostedTabsAsync()
    {
        var tabIds = _hostedTabs.Keys.ToList();
        foreach (var tabId in tabIds)
        {
            await DetachHostedTabAsync(tabId);
        }
    }

    /// <summary>
    /// 새 BrowserWindow 프로세스를 생성하고 dock
    /// </summary>
    private async Task SpawnAndDockNewWindowAsync()
    {
        var tabId = Guid.NewGuid().ToString("N")[..8];
        var pipeName = $"BrowserWindow_Tab_{_pid}_{tabId}";

        var tabInfo = new PeerTabInfo { TabId = tabId, Title = "New Window" };
        var pipeServer = new IpcPipeServer(pipeName);
        tabInfo.PipeServer = pipeServer;

        pipeServer.MessageReceived += m => OnHostedPeerMessage(tabId, m);
        pipeServer.ClientDisconnected += () => OnHostedPeerDisconnected(tabId);

        _hostedTabs[tabId] = tabInfo;
        AddHostedTabButton(tabInfo);

        var pipeTask = pipeServer.StartAsync(_appCts.Token);

        var exePath = Process.GetCurrentProcess().MainModule?.FileName;
        if (exePath == null)
        {
            StatusText.Text = "Cannot find own executable path";
            _hostedTabs.Remove(tabId);
            RemoveTabButton(tabId);
            pipeServer.Dispose();
            return;
        }

        try
        {
            var process = Process.Start(new ProcessStartInfo
            {
                FileName = exePath,
                Arguments = $"--dockTo {pipeName} --tabId {tabId}",
                UseShellExecute = false,
            });

            if (process == null)
            {
                StatusText.Text = "Failed to start new window process";
                _hostedTabs.Remove(tabId);
                RemoveTabButton(tabId);
                pipeServer.Dispose();
                return;
            }

            tabInfo.PeerProcess = process;
            tabInfo.PeerPid = process.Id;

            await pipeTask;
            SwitchToTab(tabId);
            UpdateStatusBar();
        }
        catch (Exception ex)
        {
            StatusText.Text = $"Error: {ex.Message}";
            _hostedTabs.Remove(tabId);
            RemoveTabButton(tabId);
            pipeServer.Dispose();
        }
    }

    #endregion

    #region Embedded: messages from host

    private void OnHostMessage(IpcMessage msg)
    {
        Dispatcher.Invoke(() =>
        {
            switch (msg.Type)
            {
                case IpcMessageType.RequestDetach:
                    ExitEmbeddedMode();
                    _ = _hostPipe?.SendAsync(new IpcMessage
                    {
                        Type = IpcMessageType.DetachCompleted,
                        TabId = _myTabIdInHost,
                    });
                    break;

                case IpcMessageType.CloseTab:
                    Close();
                    break;

                case IpcMessageType.Ping:
                    _ = _hostPipe?.SendAsync(new IpcMessage
                    {
                        Type = IpcMessageType.Pong,
                        TabId = _myTabIdInHost,
                    });
                    break;
            }
        });
    }

    private void OnHostDisconnected()
    {
        Dispatcher.Invoke(() =>
        {
            ExitEmbeddedMode();
        });
    }

    #endregion

    #region Tab Switching & Window Management

    private void SwitchToTab(string tabId)
    {
        _activeTabId = tabId;

        if (tabId == SelfTabId)
        {
            LocalContent.Visibility = Visibility.Visible;
            HostedContent.Visibility = Visibility.Collapsed;

            foreach (var (_, tab) in _hostedTabs)
            {
                if (tab.PeerHwnd != IntPtr.Zero && tab.IsEmbedded)
                    Win32Api.ShowWindow(tab.PeerHwnd, Win32Api.SW_HIDE);
            }
        }
        else
        {
            LocalContent.Visibility = Visibility.Collapsed;
            HostedContent.Visibility = Visibility.Visible;

            foreach (var (id, tab) in _hostedTabs)
            {
                if (tab.PeerHwnd == IntPtr.Zero || !tab.IsEmbedded) continue;

                if (id == tabId)
                {
                    Win32Api.ShowWindow(tab.PeerHwnd, Win32Api.SW_SHOW);
                    ResizeEmbeddedPeer(tab);
                }
                else
                {
                    Win32Api.ShowWindow(tab.PeerHwnd, Win32Api.SW_HIDE);
                }
            }
        }

        UpdateTabButtonStyles();
        UpdateWindowTitle();
    }

    private void ResizeEmbeddedPeer(PeerTabInfo tab)
    {
        if (tab.PeerHwnd == IntPtr.Zero || !tab.IsEmbedded) return;

        var screenPoint = HostedContent.PointToScreen(new Point(0, 0));
        var pt = new Win32Api.POINT { X = (int)screenPoint.X, Y = (int)screenPoint.Y };
        Win32Api.ScreenToClient(_hwnd, ref pt);

        var dpi = VisualTreeHelper.GetDpi(this);
        var width = (int)(HostedContent.ActualWidth * dpi.DpiScaleX);
        var height = (int)(HostedContent.ActualHeight * dpi.DpiScaleY);

        Win32Api.MoveWindow(tab.PeerHwnd, pt.X, pt.Y, width, height, true);
    }

    private void MainWindow_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        if (_activeTabId != SelfTabId && _hostedTabs.TryGetValue(_activeTabId, out var tab))
        {
            ResizeEmbeddedPeer(tab);
        }
    }

    #endregion

    #region Tab Bar UI

    private void AddHostedTabButton(PeerTabInfo tab)
    {
        var border = new Border
        {
            Tag = tab.TabId,
            Background = new SolidColorBrush(Color.FromRgb(0x2D, 0x2D, 0x44)),
            CornerRadius = new CornerRadius(6, 6, 0, 0),
            Margin = new Thickness(2, 0, 0, 0),
            Padding = new Thickness(4),
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
        border.Child = grid;

        border.MouseLeftButtonDown += TabButton_MouseLeftButtonDown;
        border.MouseMove += TabButton_MouseMove;

        TabBar.Children.Add(border);
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
        var border = TabBar.Children.OfType<Border>()
            .FirstOrDefault(b => b.Tag as string == tabId);

        if (border?.Child is Grid grid)
        {
            var tb = grid.Children.OfType<TextBlock>().FirstOrDefault();
            if (tb != null) tb.Text = title;
        }
        else if (border?.Child is TextBlock textBlock)
        {
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

    private void UpdateWindowTitle()
    {
        if (_activeTabId == SelfTabId)
        {
            var pageTitle = string.IsNullOrEmpty(_currentUrl) || _currentUrl == "about:blank"
                ? "New Window" : PageTitle.Text;
            Title = $"{pageTitle} - Browser (PID:{_pid})";
        }
        else if (_hostedTabs.TryGetValue(_activeTabId, out var tab))
        {
            Title = $"{tab.Title} - Browser (PID:{_pid})";
        }
        TitleText.Text = Title;
    }

    #endregion

    #region Event Handlers

    private void TabButton_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (sender is Border border && border.Tag is string tabId)
            SwitchToTab(tabId);
    }

    private Point _dragStartPoint;
    private bool _isDragging;

    private void TabButton_MouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        if (sender is not Border border || border.Tag is not string tabId) return;
        if (tabId == SelfTabId) return; // 자기 탭은 드래그 불가

        var pos = e.GetPosition(this);
        if (!_isDragging)
        {
            _dragStartPoint = pos;
            _isDragging = true;
            return;
        }

        var diff = pos - _dragStartPoint;
        if (Math.Abs(diff.Y) > 40 || Math.Abs(diff.X) > 80)
        {
            _isDragging = false;
            var data = new DataObject("TabId", tabId);
            var result = DragDrop.DoDragDrop(border, data, DragDropEffects.Move);

            if (result == DragDropEffects.None)
                _ = DetachHostedTabAsync(tabId);
        }
    }

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent("TabId")
            ? DragDropEffects.Move
            : DragDropEffects.None;
        e.Handled = true;
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
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
            _ = CloseHostedTabAsync(tabId);
            e.Handled = true;
        }
    }

    private async void NewWindowButton_Click(object sender, RoutedEventArgs e)
    {
        await SpawnAndDockNewWindowAsync();
    }

    private async void MainWindow_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.N && Keyboard.Modifiers == ModifierKeys.Control)
        {
            await SpawnAndDockNewWindowAsync();
            e.Handled = true;
        }
        else if (e.Key == Key.W && Keyboard.Modifiers == ModifierKeys.Control)
        {
            if (_activeTabId != SelfTabId)
                await CloseHostedTabAsync(_activeTabId);
            e.Handled = true;
        }
        else if (e.Key == Key.Tab && Keyboard.Modifiers == (ModifierKeys.Control | ModifierKeys.Shift))
        {
            CycleTab(false);
            e.Handled = true;
        }
        else if (e.Key == Key.Tab && Keyboard.Modifiers == ModifierKeys.Control)
        {
            CycleTab(true);
            e.Handled = true;
        }
        else if (e.Key == Key.D && Keyboard.Modifiers == ModifierKeys.Control)
        {
            if (_activeTabId != SelfTabId)
                await DetachHostedTabAsync(_activeTabId);
            e.Handled = true;
        }
    }

    private void CycleTab(bool forward)
    {
        var allIds = new List<string> { SelfTabId };
        allIds.AddRange(_hostedTabs.Keys);

        if (allIds.Count <= 1) return;

        var idx = allIds.IndexOf(_activeTabId);
        idx = forward ? (idx + 1) % allIds.Count : (idx - 1 + allIds.Count) % allIds.Count;
        SwitchToTab(allIds[idx]);
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

    private async void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        _statusTimer.Stop();
        _appCts.Cancel();

        // embedded 상태이면 호스트에 알림
        if (_isEmbedded && _hostPipe != null)
        {
            try
            {
                await _hostPipe.SendAsync(new IpcMessage
                {
                    Type = IpcMessageType.CloseRequested,
                    TabId = _myTabIdInHost,
                });
            }
            catch { }
            _hostPipe.Dispose();
        }

        // 호스팅 중인 탭들 정리
        foreach (var tab in _hostedTabs.Values.ToList())
            tab.Dispose();
        _hostedTabs.Clear();
    }

    #endregion

    #region Local Content / Navigation

    private void NavigateTo(string url)
    {
        _currentUrl = url;
        AddressBar.Text = url;

        if (url.StartsWith("about:"))
        {
            PageTitle.Text = "New Window";
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
                               $"Rendered by process PID:{_pid}\n" +
                               $"Each window runs in its own process.\n\n" +
                               $"This window can host other windows as tabs,\n" +
                               $"or be docked into another window as a tab.";
        }

        Title = $"{PageTitle.Text} - Browser (PID:{_pid})";
        TitleText.Text = Title;
        UpdateProcessInfo();
        UpdateSelfTabTitle();

        // embedded 상태이면 호스트에 제목 변경 알림
        if (_isEmbedded)
        {
            _ = _hostPipe?.SendAsync(new IpcMessage
            {
                Type = IpcMessageType.TitleChanged,
                TabId = _myTabIdInHost,
                Data = new Dictionary<string, string>
                {
                    ["title"] = PageTitle.Text,
                    ["url"] = url,
                }
            });
        }
    }

    private void UpdateSelfTabTitle()
    {
        var selfBorder = TabBar.Children.OfType<Border>()
            .FirstOrDefault(b => b.Tag as string == SelfTabId);
        if (selfBorder?.Child is TextBlock tb)
        {
            var title = _currentUrl == "about:blank" ? "This Window" : PageTitle.Text;
            tb.Text = title;
        }
    }

    private string GetCurrentTitle()
    {
        return _currentUrl == "about:blank" ? $"Window (PID:{_pid})" : PageTitle.Text;
    }

    private void AddressBar_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) NavigateTo(AddressBar.Text.Trim());
    }

    private void GoButton_Click(object sender, RoutedEventArgs e) =>
        NavigateTo(AddressBar.Text.Trim());

    private void BackButton_Click(object sender, RoutedEventArgs e) =>
        StatusText.Text = "Back (simulated)";

    private void ForwardButton_Click(object sender, RoutedEventArgs e) =>
        StatusText.Text = "Forward (simulated)";

    private void RefreshButton_Click(object sender, RoutedEventArgs e) =>
        NavigateTo(_currentUrl);

    private void QuickLink_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button btn && btn.Tag is string url)
            NavigateTo(url);
    }

    private async void DockButton_Click(object sender, RoutedEventArgs e)
    {
        if (int.TryParse(TargetPidInput.Text.Trim(), out var targetPid))
            await DockIntoAsync(targetPid);
        else
            StatusText.Text = "Enter a valid PID";
    }

    private void RefreshPeersButton_Click(object sender, RoutedEventArgs e) =>
        RefreshAvailablePeers();

    #endregion

    #region Status & Process Info

    private void UpdateProcessInfo()
    {
        var process = Process.GetCurrentProcess();
        ProcessInfo.Text = $"Process ID: {_pid}\n" +
                           $"Window Handle: 0x{_hwnd:X}\n" +
                           $"Mode: {(_isEmbedded ? "Embedded" : "Standalone")}\n" +
                           $"Hosted Tabs: {_hostedTabs.Count}\n" +
                           $"Working Set: {process.WorkingSet64 / 1024 / 1024} MB\n" +
                           $"URL: {_currentUrl}";
    }

    private void RefreshAvailablePeers()
    {
        try
        {
            var myName = Process.GetCurrentProcess().ProcessName;
            var peers = Process.GetProcessesByName(myName)
                .Where(p => p.Id != _pid)
                .Select(p => $"PID:{p.Id}")
                .ToList();

            AvailablePeersText.Text = peers.Count > 0
                ? $"Available peers: {string.Join(", ", peers)}"
                : "No other BrowserWindow instances found. Launch another instance first.";
        }
        catch
        {
            AvailablePeersText.Text = "Could not scan for peers";
        }
    }

    private void StatusTimer_Tick(object? sender, EventArgs e)
    {
        UpdateStatusBar();

        var deadTabs = _hostedTabs
            .Where(kv => kv.Value.PeerProcess is { HasExited: true })
            .Select(kv => kv.Key)
            .ToList();

        foreach (var tabId in deadTabs)
            FinalizeTabRemoval(tabId, killProcess: false);
    }

    private void UpdateStatusBar()
    {
        var tabCount = 1 + _hostedTabs.Count; // self + hosted
        TabCountText.Text = $"{tabCount} tab{(tabCount == 1 ? "" : "s")}";

        var processCount = 1 + _hostedTabs.Values
            .Select(t => t.PeerPid).Where(p => p > 0).Distinct().Count();
        ProcessCountText.Text = $"{processCount} process{(processCount == 1 ? "" : "es")}";

        try
        {
            var totalMemory = Process.GetCurrentProcess().WorkingSet64;
            foreach (var tab in _hostedTabs.Values)
            {
                if (tab.PeerProcess is { HasExited: false })
                {
                    tab.PeerProcess.Refresh();
                    totalMemory += tab.PeerProcess.WorkingSet64;
                }
            }
            MemoryText.Text = $"{totalMemory / 1024 / 1024} MB";
        }
        catch { }
    }

    #endregion
}
