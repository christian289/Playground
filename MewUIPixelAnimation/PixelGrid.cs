namespace MewUIPixelAnimation;

/// <summary>
/// 80x60 = 4,800개 Label 컨트롤을 Canvas 위에 배치하는 픽셀 그리드
/// Pixel grid placing 80x60 = 4,800 Label controls on a Canvas
/// </summary>
sealed class PixelGrid
{
    public const int GridWidth = 80;
    public const int GridHeight = 60;
    public const int PixelSize = 8;
    public const int GroundY = 55;

    // 프레임 버퍼: 각 픽셀의 색상 상태
    // Frame buffer: color state for each pixel
    private readonly Color[,] _buffer = new Color[GridHeight, GridWidth];
    private readonly Color[,] _prevBuffer = new Color[GridHeight, GridWidth];

    // Label 컨트롤 참조 (직접 Background 업데이트용)
    // Label control references (for direct Background updates)
    private readonly Label[,] _pixels = new Label[GridHeight, GridWidth];

    private readonly Color _backgroundColor = Color.Black;
    private readonly Color _characterColor = Color.FromRgb(0, 255, 100);
    private readonly Color _groundColor = Color.White;

    public Canvas Canvas { get; }
    public int TotalControls => GridWidth * GridHeight;

    public PixelGrid()
    {
        var children = new Element[GridWidth * GridHeight];
        int index = 0;

        for (int y = 0; y < GridHeight; y++)
        {
            for (int x = 0; x < GridWidth; x++)
            {
                _buffer[y, x] = _backgroundColor;
                _prevBuffer[y, x] = _backgroundColor;

                var label = new Label()
                    .Size(PixelSize, PixelSize)
                    .CanvasLeft(x * PixelSize)
                    .CanvasTop(y * PixelSize)
                    .Background(_backgroundColor);

                _pixels[y, x] = label;
                children[index++] = label;
            }
        }

        Canvas = new Canvas()
            .Size(GridWidth * PixelSize, GridHeight * PixelSize)
            .Background(_backgroundColor)
            .Children(children);
    }

    /// <summary>
    /// 프레임 버퍼를 검은색으로 클리어
    /// Clear frame buffer to black
    /// </summary>
    public void Clear()
    {
        for (int y = 0; y < GridHeight; y++)
        {
            for (int x = 0; x < GridWidth; x++)
            {
                _buffer[y, x] = _backgroundColor;
            }
        }
    }

    /// <summary>
    /// 지면 라인 그리기
    /// Draw ground line
    /// </summary>
    public void DrawGround()
    {
        for (int x = 0; x < GridWidth; x++)
        {
            _buffer[GroundY, x] = _groundColor;
        }
    }

    /// <summary>
    /// 스틱맨 스프라이트를 프레임 버퍼에 렌더링
    /// Render stickman sprite to frame buffer
    /// </summary>
    public void DrawSprite(byte[,] frame, int posX, int posY)
    {
        int spriteH = frame.GetLength(0);
        int spriteW = frame.GetLength(1);

        for (int row = 0; row < spriteH; row++)
        {
            int gy = posY + row;
            if (gy < 0 || gy >= GridHeight) continue;

            for (int col = 0; col < spriteW; col++)
            {
                int gx = posX + col;
                if (gx < 0 || gx >= GridWidth) continue;

                if (frame[row, col] == 1)
                {
                    _buffer[gy, gx] = _characterColor;
                }
            }
        }
    }

    /// <summary>
    /// 프레임 버퍼의 변경사항을 Label 컨트롤에 적용 (변경된 픽셀만 업데이트)
    /// Apply frame buffer changes to Label controls (only changed pixels)
    /// </summary>
    public int Flush()
    {
        int updatedCount = 0;

        for (int y = 0; y < GridHeight; y++)
        {
            for (int x = 0; x < GridWidth; x++)
            {
                Color newColor = _buffer[y, x];
                if (newColor != _prevBuffer[y, x])
                {
                    _pixels[y, x].Background = newColor;
                    _prevBuffer[y, x] = newColor;
                    updatedCount++;
                }
            }
        }

        return updatedCount;
    }
}
