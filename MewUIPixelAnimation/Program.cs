using MewUIPixelAnimation;

// 다크 테마 설정
// Set dark theme
Theme.Current = Theme.Dark.WithAccent(Color.FromRgb(0, 255, 100));

// 픽셀 그리드 생성 (80x60 = 4,800개 Label)
// Create pixel grid (80x60 = 4,800 Labels)
var grid = new PixelGrid();

// 애니메이션 상태
// Animation state
int stickmanX = 0;
int frameIndex = 0;
int stickmanY = PixelGrid.GroundY - StickmanFrames.SpriteHeight;

// 성능 측정
// Performance metrics
var sw = new Stopwatch();
var fpsSw = Stopwatch.StartNew();
int frameCount = 0;
double currentFps = 0;
double lastRenderMs = 0;
int totalElapsedSeconds = 0;

// FPS 표시 라벨
// FPS display labels
var fpsValue = new ObservableValue<string>("FPS: --");
var renderTimeValue = new ObservableValue<string>("Render: -- ms");
var controlCountValue = new ObservableValue<string>($"Controls: {grid.TotalControls}");
var elapsedValue = new ObservableValue<string>("Elapsed: 0s");

// 타이머 참조 (클로저에서 캡처용)
// Timer reference (for capture in closure)
System.Threading.Timer? animTimer = null;

// 애니메이션 틱 핸들러
// Animation tick handler
void OnTick()
{
    sw.Restart();

    // 1. 프레임 버퍼 클리어
    // 1. Clear frame buffer
    grid.Clear();

    // 2. 지면 라인 그리기
    // 2. Draw ground line
    grid.DrawGround();

    // 3. 스틱맨 스프라이트 렌더링
    // 3. Render stickman sprite
    grid.DrawSprite(StickmanFrames.Frames[frameIndex], stickmanX, stickmanY);

    // 4. 프레임 버퍼를 화면에 적용
    // 4. Flush frame buffer to screen
    grid.Flush();

    sw.Stop();
    lastRenderMs = sw.Elapsed.TotalMilliseconds;

    // 5. 스틱맨 위치/프레임 업데이트
    // 5. Update stickman position/frame
    stickmanX += 1;
    if (stickmanX > PixelGrid.GridWidth)
    {
        stickmanX = -StickmanFrames.SpriteWidth;
    }

    frameIndex = (frameIndex + 1) % StickmanFrames.FrameCount;

    // 6. FPS 카운터 업데이트
    // 6. Update FPS counter
    frameCount++;
    double elapsed = fpsSw.Elapsed.TotalSeconds;
    if (elapsed >= 1.0)
    {
        currentFps = frameCount / elapsed;
        totalElapsedSeconds += (int)elapsed;
        frameCount = 0;
        fpsSw.Restart();
    }

    // 7. 성능 메트릭 표시 업데이트
    // 7. Update performance metric display
    fpsValue.Value = $"FPS: {currentFps:F1}";
    renderTimeValue.Value = $"Render: {lastRenderMs:F2} ms";
    elapsedValue.Value = $"Elapsed: {totalElapsedSeconds}s";
}

// 윈도우 생성
// Create window
var window = new Window()
    .Title("MewUI Pixel Animation - Performance Test")
    .Fixed(
        PixelGrid.GridWidth * PixelGrid.PixelSize + 20,
        PixelGrid.GridHeight * PixelGrid.PixelSize + 80)
    .Padding(4)
    .Content(
        new DockPanel()
            .Children(
                new StackPanel()
                    .DockTop()
                    .Horizontal()
                    .Spacing(16)
                    .Children(
                        new Label().BindText(fpsValue).Bold().Foreground(Color.FromRgb(0, 255, 100)),
                        new Label().BindText(renderTimeValue).Foreground(Color.FromRgb(200, 200, 200)),
                        new Label().BindText(controlCountValue).Foreground(Color.FromRgb(150, 150, 150)),
                        new Label().BindText(elapsedValue).Foreground(Color.FromRgb(150, 150, 150))
                    ),
                grid.Canvas
            )
    )
    .OnLoaded(() =>
    {
        // OnLoaded는 UI 스레드에서 실행되므로 SynchronizationContext를 캡처
        // OnLoaded runs on UI thread, so capture SynchronizationContext
        var syncContext = SynchronizationContext.Current;
        animTimer = new System.Threading.Timer(_ =>
        {
            if (syncContext != null)
                syncContext.Post(_ => OnTick(), null);
            else
                OnTick();
        }, null, 0, 33);
    })
    .OnClosed(() =>
    {
        animTimer?.Dispose();
    });

Application.Run(window);
