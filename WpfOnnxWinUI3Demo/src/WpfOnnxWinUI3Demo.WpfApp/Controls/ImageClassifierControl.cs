using System.IO;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Storage.Pickers;
using WpfOnnxWinUI3Demo.ViewModels;
using WinRT.Interop;

namespace WpfOnnxWinUI3Demo.WpfApp.Controls;

/// <summary>
/// WinUI 3 control for image classification UI, created programmatically.
/// 프로그래밍 방식으로 생성된 이미지 분류 UI용 WinUI 3 컨트롤입니다.
/// </summary>
public sealed class ImageClassifierControl : UserControl
{
    private MainViewModel? _viewModel;
    private IntPtr _windowHandle;

    private Button _selectImageButton = null!;
    private Button _classifyButton = null!;
    private ProgressRing _processingRing = null!;
    private TextBlock _statusText = null!;
    private TextBlock _placeholderText = null!;
    private Image _selectedImage = null!;
    private ListView _predictionsList = null!;
    private TextBlock _inferenceTimeText = null!;

    public ImageClassifierControl()
    {
        BuildUI();
    }

    /// <summary>
    /// Sets the window handle for file picker initialization.
    /// 파일 선택기 초기화를 위한 윈도우 핸들을 설정합니다.
    /// </summary>
    public void SetWindowHandle(IntPtr hwnd)
    {
        _windowHandle = hwnd;
    }

    /// <summary>
    /// Sets the ViewModel for data binding.
    /// 데이터 바인딩을 위한 ViewModel을 설정합니다.
    /// </summary>
    public void SetViewModel(MainViewModel viewModel)
    {
        _viewModel = viewModel;
        UpdateUI();
    }

    private void BuildUI()
    {
        // Main grid
        // 메인 그리드
        var mainGrid = new Grid
        {
            Padding = new Thickness(20),
            RowSpacing = 16
        };

        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        mainGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        // Header with buttons
        // 버튼이 있는 헤더
        var headerPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 12
        };
        Grid.SetRow(headerPanel, 0);

        _selectImageButton = new Button
        {
            Content = "Select Image",
            Style = (Style)Application.Current.Resources["AccentButtonStyle"]
        };
        _selectImageButton.Click += OnSelectImageClick;

        _classifyButton = new Button
        {
            Content = "Classify",
            IsEnabled = false
        };
        _classifyButton.Click += OnClassifyClick;

        _processingRing = new ProgressRing
        {
            Width = 24,
            Height = 24,
            IsActive = false,
            Visibility = Visibility.Collapsed
        };

        _statusText = new TextBlock
        {
            VerticalAlignment = VerticalAlignment.Center
        };

        headerPanel.Children.Add(_selectImageButton);
        headerPanel.Children.Add(_classifyButton);
        headerPanel.Children.Add(_processingRing);
        headerPanel.Children.Add(_statusText);

        // Content area
        // 콘텐츠 영역
        var contentGrid = new Grid { ColumnSpacing = 20 };
        contentGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        contentGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        Grid.SetRow(contentGrid, 1);

        // Image display area
        // 이미지 표시 영역
        var imageBorder = new Border
        {
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8)
        };
        Grid.SetColumn(imageBorder, 0);

        var imageGrid = new Grid();
        _placeholderText = new TextBlock
        {
            Text = "No image selected",
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        _selectedImage = new Image
        {
            Stretch = Stretch.Uniform,
            Margin = new Thickness(8)
        };

        imageGrid.Children.Add(_placeholderText);
        imageGrid.Children.Add(_selectedImage);
        imageBorder.Child = imageGrid;

        // Predictions area
        // 예측 결과 영역
        var predictionsBorder = new Border
        {
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(16)
        };
        Grid.SetColumn(predictionsBorder, 1);

        var predictionsGrid = new Grid { RowSpacing = 12 };
        predictionsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        predictionsGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var predictionsTitle = new TextBlock
        {
            Text = "Top 10 Predictions",
            FontSize = 18,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold
        };
        Grid.SetRow(predictionsTitle, 0);

        _predictionsList = new ListView { SelectionMode = ListViewSelectionMode.None };
        Grid.SetRow(_predictionsList, 1);

        predictionsGrid.Children.Add(predictionsTitle);
        predictionsGrid.Children.Add(_predictionsList);
        predictionsBorder.Child = predictionsGrid;

        contentGrid.Children.Add(imageBorder);
        contentGrid.Children.Add(predictionsBorder);

        // Footer
        // 푸터
        var footerBorder = new Border
        {
            CornerRadius = new CornerRadius(4),
            Padding = new Thickness(12, 8, 12, 8)
        };
        Grid.SetRow(footerBorder, 2);

        _inferenceTimeText = new TextBlock { Text = "Ready" };
        footerBorder.Child = _inferenceTimeText;

        mainGrid.Children.Add(headerPanel);
        mainGrid.Children.Add(contentGrid);
        mainGrid.Children.Add(footerBorder);

        Content = mainGrid;
    }

    private async void OnSelectImageClick(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(".jpg");
        picker.FileTypeFilter.Add(".jpeg");
        picker.FileTypeFilter.Add(".png");
        picker.FileTypeFilter.Add(".bmp");

        if (_windowHandle != IntPtr.Zero)
        {
            InitializeWithWindow.Initialize(picker, _windowHandle);
        }

        var file = await picker.PickSingleFileAsync();
        if (file is not null)
        {
            _viewModel?.SetSelectedImage(file.Path);
            await LoadImageAsync(file.Path);
            _classifyButton.IsEnabled = _viewModel?.IsModelLoaded ?? false;
        }
    }

    private async void OnClassifyClick(object sender, RoutedEventArgs e)
    {
        if (_viewModel is null) return;

        SetProcessingState(true);

        try
        {
            await _viewModel.ClassifyCommand.ExecuteAsync(null);
            UpdatePredictionsList();
        }
        finally
        {
            SetProcessingState(false);
            UpdateUI();
        }
    }

    private async Task LoadImageAsync(string path)
    {
        try
        {
            var bitmap = new BitmapImage();
            using var stream = File.OpenRead(path);
            var memStream = new MemoryStream();
            await stream.CopyToAsync(memStream);
            memStream.Position = 0;

            var randomAccessStream = memStream.AsRandomAccessStream();
            await bitmap.SetSourceAsync(randomAccessStream);

            _selectedImage.Source = bitmap;
            _placeholderText.Visibility = Visibility.Collapsed;
        }
        catch
        {
            _placeholderText.Text = "Failed to load image";
            _placeholderText.Visibility = Visibility.Visible;
        }
    }

    private void SetProcessingState(bool isProcessing)
    {
        _processingRing.IsActive = isProcessing;
        _processingRing.Visibility = isProcessing ? Visibility.Visible : Visibility.Collapsed;
        _selectImageButton.IsEnabled = !isProcessing;
        _classifyButton.IsEnabled = !isProcessing;
    }

    private void UpdateUI()
    {
        if (_viewModel is null) return;

        _statusText.Text = _viewModel.StatusMessage ?? string.Empty;
        _inferenceTimeText.Text = _viewModel.InferenceTimeText ?? "Ready";
    }

    private void UpdatePredictionsList()
    {
        if (_viewModel is null) return;

        var items = _viewModel.Predictions
            .Select((p, i) => new PredictionDisplayItem(i + 1, p.Label, p.ConfidencePercent))
            .ToList();

        _predictionsList.ItemsSource = items;
    }
}

/// <summary>
/// Display item for prediction list with rank.
/// 순위가 포함된 예측 목록 표시 항목입니다.
/// </summary>
internal sealed record PredictionDisplayItem(int Rank, string Label, string ConfidencePercent)
{
    public override string ToString() => $"{Rank}. {Label} ({ConfidencePercent})";
}
