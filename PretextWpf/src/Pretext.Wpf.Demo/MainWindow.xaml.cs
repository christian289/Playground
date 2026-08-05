using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace Pretext.Wpf.Demo;

/// <summary>
/// Playground shell: 44px top tab nav (Dragon / ASCII Animations / Layout Lab) over a
/// full-bleed page host, reproducing the deployed pretext-playground chrome.
/// </summary>
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        SourceInitialized += (_, _) => EnableDarkTitleBar();
    }

    private void OnTabChecked(object sender, RoutedEventArgs e)
    {
        if (DragonPage is null || AsciiPage is null || LabPage is null)
        {
            return;
        }

        DragonPage.Visibility = DragonTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        AsciiPage.Visibility = AsciiTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        LabPage.Visibility = LabTab.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private void EnableDarkTitleBar()
    {
        nint handle = new WindowInteropHelper(this).Handle;
        if (handle != 0)
        {
            int enabled = 1;
            _ = NativeMethods.DwmSetWindowAttribute(handle, 20, ref enabled, sizeof(int));
        }
    }

    private static class NativeMethods
    {
        [DllImport("dwmapi.dll", ExactSpelling = true)]
        internal static extern int DwmSetWindowAttribute(nint hwnd, int attribute, ref int value, int size);
    }
}
