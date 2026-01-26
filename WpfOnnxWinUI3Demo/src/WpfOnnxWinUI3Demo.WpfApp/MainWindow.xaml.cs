using System.IO;
using System.Windows;
using WpfOnnxWinUI3Demo.ViewModels;
using WpfOnnxWinUI3Demo.WpfApp.Hosting;

namespace WpfOnnxWinUI3Demo.WpfApp;

/// <summary>
/// WPF main window that hosts WinUI 3 content via XAML Islands.
/// XAML Islands를 통해 WinUI 3 콘텐츠를 호스팅하는 WPF 메인 윈도우입니다.
/// </summary>
public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel;
    private XamlIslandHost? _xamlHost;

    public MainWindow(MainViewModel viewModel)
    {
        _viewModel = viewModel;
        InitializeComponent();

        Loaded += OnLoaded;
        Closed += OnClosed;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        // Initialize XAML Islands infrastructure
        // XAML Islands 인프라 초기화
        XamlIslandHost.InitializeXamlIslands();

        // Create and add XAML Island host
        // XAML Island 호스트 생성 및 추가
        _xamlHost = new XamlIslandHost(_viewModel);
        RootGrid.Children.Add(_xamlHost);

        // Initialize ONNX model
        // ONNX 모델 초기화
        InitializeModel();
    }

    private void InitializeModel()
    {
        var modelPath = Path.Combine(AppContext.BaseDirectory, "Assets", "model", "resnet50-v2-7.onnx");

        if (!File.Exists(modelPath))
        {
            MessageBox.Show(
                "ONNX 모델 파일을 찾을 수 없습니다.\n\n" +
                "모델 파일 경로: " + modelPath + "\n\n" +
                "다음 URL에서 다운로드하세요:\n" +
                "https://github.com/onnx/models/blob/main/validated/vision/classification/resnet/model/resnet50-v2-7.onnx",
                "Model Not Found",
                // ONNX model file not found.
                // Model file path: {modelPath}
                // Download from the following URL:
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            return;
        }

        _viewModel.InitializeModel(modelPath);
    }

    private void OnClosed(object? sender, EventArgs e)
    {
        _viewModel.Dispose();
    }
}
