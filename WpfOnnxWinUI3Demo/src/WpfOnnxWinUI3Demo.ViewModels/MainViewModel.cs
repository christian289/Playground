namespace WpfOnnxWinUI3Demo.ViewModels;

/// <summary>
/// Main ViewModel for the image classification demo.
/// 이미지 분류 데모의 메인 ViewModel입니다.
/// </summary>
public sealed partial class MainViewModel : ObservableObject, IDisposable
{
    private readonly OnnxInferenceService _inferenceService;

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(ClassifyCommand))]
    private string? _selectedImagePath;

    [ObservableProperty]
    private string? _statusMessage;

    [ObservableProperty]
    private string? _inferenceTimeText;

    [ObservableProperty]
    private bool _isProcessing;

    [ObservableProperty]
    private bool _isModelLoaded;

    public ObservableCollection<Prediction> Predictions { get; } = [];

    public MainViewModel(OnnxInferenceService inferenceService)
    {
        _inferenceService = inferenceService;
    }

    /// <summary>
    /// Initializes the ONNX model.
    /// ONNX 모델을 초기화합니다.
    /// </summary>
    public void InitializeModel(string modelPath)
    {
        try
        {
            _inferenceService.Initialize(modelPath);
            IsModelLoaded = true;

            var provider = _inferenceService.IsUsingDirectML ? "DirectML" : "CPU";
            StatusMessage = $"모델 로드 완료 ({provider})";
            // Model loaded ({provider})
        }
        catch (Exception ex)
        {
            StatusMessage = $"모델 로드 실패: {ex.Message}";
            // Model load failed: {ex.Message}
            IsModelLoaded = false;
        }
    }

    /// <summary>
    /// Sets the selected image path and triggers classification.
    /// 선택된 이미지 경로를 설정하고 분류를 트리거합니다.
    /// </summary>
    public void SetSelectedImage(string imagePath)
    {
        SelectedImagePath = imagePath;
    }

    private bool CanClassify() => !string.IsNullOrEmpty(SelectedImagePath) && IsModelLoaded && !IsProcessing;

    [RelayCommand(CanExecute = nameof(CanClassify))]
    private async Task ClassifyAsync()
    {
        if (string.IsNullOrEmpty(SelectedImagePath)) return;

        IsProcessing = true;
        Predictions.Clear();
        StatusMessage = "분류 중...";
        // Classifying...

        try
        {
            var result = await Task.Run(() =>
            {
                using var stream = File.OpenRead(SelectedImagePath);
                return _inferenceService.Classify(stream);
            });

            foreach (var prediction in result.Results)
            {
                Predictions.Add(prediction);
            }

            InferenceTimeText = $"추론 시간: {result.Elapsed.TotalMilliseconds:F1}ms ({result.ExecutionProvider})";
            // Inference Time: {result.Elapsed.TotalMilliseconds:F1}ms ({result.ExecutionProvider})

            StatusMessage = "분류 완료";
            // Classification complete
        }
        catch (Exception ex)
        {
            StatusMessage = $"분류 실패: {ex.Message}";
            // Classification failed: {ex.Message}
            InferenceTimeText = null;
        }
        finally
        {
            IsProcessing = false;
        }
    }

    public void Dispose()
    {
        _inferenceService.Dispose();
    }
}
