using System.IO;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Text;
using System.Windows;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;
using Windows.Storage.Streams;
using WinRTBitmapDecoder = Windows.Graphics.Imaging.BitmapDecoder;

namespace WinAppCliOcr;

public partial class MainWindow : Window
{
    private SoftwareBitmap? _currentBitmap;
    private OcrEngine? _ocrEngine;

    public MainWindow()
    {
        InitializeComponent();
        InitializeOcrLanguages();

        // Keyboard shortcut for paste
        KeyDown += (s, e) =>
        {
            if (e.Key == System.Windows.Input.Key.V &&
                System.Windows.Input.Keyboard.Modifiers == System.Windows.Input.ModifierKeys.Control)
            {
                BtnPaste_Click(s, e);
            }
        };
    }

    private void InitializeOcrLanguages()
    {
        var languages = OcrEngine.AvailableRecognizerLanguages;
        foreach (var lang in languages)
        {
            CmbLanguage.Items.Add(new LanguageItem(lang.DisplayName, lang.LanguageTag));
        }

        if (CmbLanguage.Items.Count > 0)
        {
            // Try to select Korean or English as default
            var defaultLang = languages.FirstOrDefault(l => l.LanguageTag.StartsWith("ko")) ??
                              languages.FirstOrDefault(l => l.LanguageTag.StartsWith("en")) ??
                              languages.First();

            for (int i = 0; i < CmbLanguage.Items.Count; i++)
            {
                if (((LanguageItem)CmbLanguage.Items[i]).Tag == defaultLang.LanguageTag)
                {
                    CmbLanguage.SelectedIndex = i;
                    break;
                }
            }
        }
    }

    private async void BtnSelectImage_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Image files (*.png;*.jpg;*.jpeg;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files (*.*)|*.*",
            Title = "Select an image for OCR"
        };

        if (dialog.ShowDialog() == true)
        {
            await LoadImageAsync(dialog.FileName);
        }
    }

    private async void BtnPaste_Click(object sender, RoutedEventArgs e)
    {
        if (Clipboard.ContainsImage())
        {
            var bitmapSource = Clipboard.GetImage();
            if (bitmapSource != null)
            {
                await LoadImageFromBitmapSourceAsync(bitmapSource);
            }
        }
        else if (Clipboard.ContainsFileDropList())
        {
            var files = Clipboard.GetFileDropList();
            if (files.Count > 0 && IsImageFile(files[0]!))
            {
                await LoadImageAsync(files[0]!);
            }
        }
        else
        {
            TxtStatus.Text = "No image in clipboard";
        }
    }

    private async void BtnRecognize_Click(object sender, RoutedEventArgs e)
    {
        if (_currentBitmap == null)
        {
            TxtStatus.Text = "No image loaded";
            return;
        }

        if (CmbLanguage.SelectedItem == null)
        {
            TxtStatus.Text = "Please select a language";
            return;
        }

        try
        {
            BtnRecognize.IsEnabled = false;
            TxtStatus.Text = "Recognizing text...";

            var selectedLang = (LanguageItem)CmbLanguage.SelectedItem;
            var language = new Windows.Globalization.Language(selectedLang.Tag);
            _ocrEngine = OcrEngine.TryCreateFromLanguage(language);

            if (_ocrEngine == null)
            {
                TxtStatus.Text = $"Failed to create OCR engine for {selectedLang.Name}";
                return;
            }

            var result = await _ocrEngine.RecognizeAsync(_currentBitmap);

            var sb = new StringBuilder();
            foreach (var line in result.Lines)
            {
                sb.AppendLine(line.Text);
            }

            TxtResult.Text = sb.ToString();
            BtnCopy.IsEnabled = !string.IsNullOrEmpty(TxtResult.Text);
            TxtStatus.Text = $"Recognition complete. {result.Lines.Count} lines found.";
        }
        catch (Exception ex)
        {
            TxtStatus.Text = $"Error: {ex.Message}";
        }
        finally
        {
            BtnRecognize.IsEnabled = true;
        }
    }

    private void BtnCopy_Click(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrEmpty(TxtResult.Text))
        {
            Clipboard.SetText(TxtResult.Text);
            TxtStatus.Text = "Text copied to clipboard";
        }
    }

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            var files = (string[])e.Data.GetData(DataFormats.FileDrop);
            e.Effects = files.Length > 0 && IsImageFile(files[0])
                ? DragDropEffects.Copy
                : DragDropEffects.None;
        }
        else
        {
            e.Effects = DragDropEffects.None;
        }
        e.Handled = true;
    }

    private async void Window_Drop(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            var files = (string[])e.Data.GetData(DataFormats.FileDrop);
            if (files.Length > 0 && IsImageFile(files[0]))
            {
                await LoadImageAsync(files[0]);
            }
        }
    }

    private async Task LoadImageAsync(string filePath)
    {
        try
        {
            TxtStatus.Text = "Loading image...";

            // Load for WPF display
            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.UriSource = new Uri(filePath);
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.EndInit();
            bitmap.Freeze();

            ImgPreview.Source = bitmap;
            TxtImagePlaceholder.Visibility = Visibility.Collapsed;

            // Load for OCR
            var file = await StorageFile.GetFileFromPathAsync(filePath);
            using var stream = await file.OpenAsync(FileAccessMode.Read);
            var decoder = await WinRTBitmapDecoder.CreateAsync(stream);
            _currentBitmap = await decoder.GetSoftwareBitmapAsync(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);

            BtnRecognize.IsEnabled = true;
            TxtStatus.Text = $"Image loaded: {Path.GetFileName(filePath)}";
        }
        catch (Exception ex)
        {
            TxtStatus.Text = $"Failed to load image: {ex.Message}";
        }
    }

    private async Task LoadImageFromBitmapSourceAsync(BitmapSource bitmapSource)
    {
        try
        {
            TxtStatus.Text = "Loading image from clipboard...";

            ImgPreview.Source = bitmapSource;
            TxtImagePlaceholder.Visibility = Visibility.Collapsed;

            // Convert to SoftwareBitmap for OCR
            using var ms = new MemoryStream();
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(System.Windows.Media.Imaging.BitmapFrame.Create(bitmapSource));
            encoder.Save(ms);
            ms.Position = 0;

            var randomAccessStream = new InMemoryRandomAccessStream();
            await randomAccessStream.WriteAsync(ms.ToArray().AsBuffer());
            randomAccessStream.Seek(0);

            var decoder = await WinRTBitmapDecoder.CreateAsync(randomAccessStream);
            _currentBitmap = await decoder.GetSoftwareBitmapAsync(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);

            BtnRecognize.IsEnabled = true;
            TxtStatus.Text = "Image loaded from clipboard";
        }
        catch (Exception ex)
        {
            TxtStatus.Text = $"Failed to load image: {ex.Message}";
        }
    }

    private static bool IsImageFile(string filePath)
    {
        var ext = Path.GetExtension(filePath).ToLowerInvariant();
        return ext is ".png" or ".jpg" or ".jpeg" or ".bmp" or ".gif";
    }
}

public record LanguageItem(string Name, string Tag)
{
    public override string ToString() => Name;
}
