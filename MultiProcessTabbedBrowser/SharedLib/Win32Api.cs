using System.Runtime.InteropServices;

namespace SharedLib;

/// <summary>
/// Win32 API 래퍼 - 윈도우 임베딩 및 조작에 사용
/// </summary>
public static partial class Win32Api
{
    public const int GWL_STYLE = -16;
    public const int GWL_EXSTYLE = -20;

    // Window Styles
    public const long WS_CHILD = 0x40000000L;
    public const long WS_POPUP = 0x80000000L;
    public const long WS_CAPTION = 0x00C00000L;
    public const long WS_THICKFRAME = 0x00040000L;
    public const long WS_MINIMIZEBOX = 0x00020000L;
    public const long WS_MAXIMIZEBOX = 0x00010000L;
    public const long WS_SYSMENU = 0x00080000L;
    public const long WS_VISIBLE = 0x10000000L;
    public const long WS_OVERLAPPEDWINDOW = WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU;

    // Extended Window Styles
    public const long WS_EX_APPWINDOW = 0x00040000L;
    public const long WS_EX_TOOLWINDOW = 0x00000080L;

    // ShowWindow commands
    public const int SW_HIDE = 0;
    public const int SW_SHOW = 5;
    public const int SW_RESTORE = 9;

    [LibraryImport("user32.dll")]
    public static partial IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

    [LibraryImport("user32.dll")]
    public static partial IntPtr GetParent(IntPtr hWnd);

    [LibraryImport("user32.dll")]
    public static partial long GetWindowLongPtrW(IntPtr hWnd, int nIndex);

    [LibraryImport("user32.dll")]
    public static partial long SetWindowLongPtrW(IntPtr hWnd, int nIndex, long dwNewLong);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height,
        [MarshalAs(UnmanagedType.Bool)] bool repaint);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetForegroundWindow(IntPtr hWnd);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool IsWindow(IntPtr hWnd);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetCursorPos(out POINT lpPoint);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool InvalidateRect(IntPtr hWnd, IntPtr lpRect, [MarshalAs(UnmanagedType.Bool)] bool bErase);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left, Top, Right, Bottom;
        public int Width => Right - Left;
        public int Height => Bottom - Top;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X, Y;
    }

    /// <summary>
    /// 자식 윈도우를 부모 윈도우에 임베딩
    /// </summary>
    public static void EmbedWindow(IntPtr childHwnd, IntPtr parentHwnd)
    {
        // 윈도우 스타일 변경: 독립 윈도우 -> 자식 윈도우
        var style = GetWindowLongPtrW(childHwnd, GWL_STYLE);
        style &= ~(WS_POPUP | WS_OVERLAPPEDWINDOW); // 팝업/오버랩 스타일 제거
        style |= WS_CHILD | WS_VISIBLE;              // 자식 + 보이기
        SetWindowLongPtrW(childHwnd, GWL_STYLE, style);

        // 확장 스타일에서 태스크바 아이콘 제거
        var exStyle = GetWindowLongPtrW(childHwnd, GWL_EXSTYLE);
        exStyle &= ~WS_EX_APPWINDOW;
        exStyle |= WS_EX_TOOLWINDOW;
        SetWindowLongPtrW(childHwnd, GWL_EXSTYLE, exStyle);

        // 부모 설정
        SetParent(childHwnd, parentHwnd);
    }

    /// <summary>
    /// 임베딩된 자식 윈도우를 분리하여 독립 윈도우로 전환
    /// </summary>
    public static void DetachWindow(IntPtr childHwnd)
    {
        // 부모 해제 (데스크탑으로 이동)
        SetParent(childHwnd, IntPtr.Zero);

        // 독립 윈도우 스타일 복원
        var style = GetWindowLongPtrW(childHwnd, GWL_STYLE);
        style &= ~WS_CHILD;
        style |= WS_POPUP | WS_OVERLAPPEDWINDOW | WS_VISIBLE;
        SetWindowLongPtrW(childHwnd, GWL_STYLE, style);

        // 태스크바에 다시 표시
        var exStyle = GetWindowLongPtrW(childHwnd, GWL_EXSTYLE);
        exStyle |= WS_EX_APPWINDOW;
        exStyle &= ~WS_EX_TOOLWINDOW;
        SetWindowLongPtrW(childHwnd, GWL_EXSTYLE, exStyle);

        ShowWindow(childHwnd, SW_SHOW);
    }
}
