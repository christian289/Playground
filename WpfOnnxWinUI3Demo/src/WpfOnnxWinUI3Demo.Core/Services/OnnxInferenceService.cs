using WpfOnnxWinUI3Demo.Core.Models;

namespace WpfOnnxWinUI3Demo.Core.Services;

/// <summary>
/// Provides ONNX model inference with DirectML acceleration and CPU fallback.
/// DirectML 가속 및 CPU 폴백을 지원하는 ONNX 모델 추론을 제공합니다.
/// </summary>
public sealed class OnnxInferenceService : IDisposable
{
    private InferenceSession? _session;
    private bool _useDirectML;
    private bool _disposed;

    private const int ImageSize = 224;
    private const int TopK = 10;

    /// <summary>
    /// Gets whether DirectML is being used for inference.
    /// 추론에 DirectML이 사용되고 있는지 여부를 반환합니다.
    /// </summary>
    public bool IsUsingDirectML => _useDirectML;

    /// <summary>
    /// Gets whether the service is initialized.
    /// 서비스가 초기화되었는지 여부를 반환합니다.
    /// </summary>
    public bool IsInitialized => _session is not null;

    /// <summary>
    /// Initializes the ONNX inference session with the specified model.
    /// 지정된 모델로 ONNX 추론 세션을 초기화합니다.
    /// </summary>
    public void Initialize(string modelPath)
    {
        if (!File.Exists(modelPath))
        {
            throw new FileNotFoundException("ONNX 모델 파일을 찾을 수 없습니다.", modelPath);
            // ONNX model file not found.
        }

        var options = new SessionOptions();

        try
        {
            // Try DirectML first
            // DirectML 먼저 시도
            options.AppendExecutionProvider_DML(0);
            _session = new InferenceSession(modelPath, options);
            _useDirectML = true;
        }
        catch
        {
            // Fallback to CPU
            // CPU로 폴백
            options = new SessionOptions();
            _session = new InferenceSession(modelPath, options);
            _useDirectML = false;
        }
    }

    /// <summary>
    /// Classifies an image and returns top predictions with elapsed time.
    /// 이미지를 분류하고 상위 예측 결과와 소요 시간을 반환합니다.
    /// </summary>
    public (IReadOnlyList<Prediction> Results, TimeSpan Elapsed, string ExecutionProvider) Classify(Stream imageStream)
    {
        if (_session is null)
        {
            throw new InvalidOperationException("서비스가 초기화되지 않았습니다. Initialize()를 먼저 호출하세요.");
            // Service not initialized. Call Initialize() first.
        }

        var sw = Stopwatch.StartNew();

        // Preprocess image
        // 이미지 전처리
        var tensor = PreprocessImage(imageStream);

        // Run inference
        // 추론 실행
        var inputs = new List<NamedOnnxValue>
        {
            NamedOnnxValue.CreateFromTensor("data", tensor)
        };

        using var results = _session.Run(inputs);
        var output = results.First().AsEnumerable<float>().ToArray();

        // Get top K predictions
        // 상위 K개 예측 가져오기
        var predictions = GetTopKPredictions(output, TopK);

        sw.Stop();

        var provider = _useDirectML ? "DirectML" : "CPU";
        return (predictions, sw.Elapsed, provider);
    }

    /// <summary>
    /// Preprocesses an image for ResNet50 v2 model input.
    /// ResNet50 v2 모델 입력을 위해 이미지를 전처리합니다.
    /// </summary>
    private static DenseTensor<float> PreprocessImage(Stream imageStream)
    {
        using var image = Image.Load<Rgb24>(imageStream);

        // Resize to 224x224
        // 224x224로 리사이즈
        image.Mutate(x => x.Resize(new ResizeOptions
        {
            Size = new Size(ImageSize, ImageSize),
            Mode = ResizeMode.Crop
        }));

        // Create tensor with NCHW format (batch, channels, height, width)
        // NCHW 형식으로 텐서 생성 (배치, 채널, 높이, 너비)
        var tensor = new DenseTensor<float>([1, 3, ImageSize, ImageSize]);

        // ImageNet normalization values
        // ImageNet 정규화 값
        float[] mean = [0.485f, 0.456f, 0.406f];
        float[] std = [0.229f, 0.224f, 0.225f];

        image.ProcessPixelRows(accessor =>
        {
            for (int y = 0; y < ImageSize; y++)
            {
                var row = accessor.GetRowSpan(y);
                for (int x = 0; x < ImageSize; x++)
                {
                    var pixel = row[x];

                    // Normalize: (pixel / 255 - mean) / std
                    // 정규화: (pixel / 255 - mean) / std
                    tensor[0, 0, y, x] = ((pixel.R / 255f) - mean[0]) / std[0];
                    tensor[0, 1, y, x] = ((pixel.G / 255f) - mean[1]) / std[1];
                    tensor[0, 2, y, x] = ((pixel.B / 255f) - mean[2]) / std[2];
                }
            }
        });

        return tensor;
    }

    /// <summary>
    /// Gets top K predictions from model output using softmax.
    /// softmax를 사용하여 모델 출력에서 상위 K개 예측을 가져옵니다.
    /// </summary>
    private static IReadOnlyList<Prediction> GetTopKPredictions(float[] output, int k)
    {
        // Apply softmax
        // Softmax 적용
        var maxVal = output.Max();
        var expValues = output.Select(x => MathF.Exp(x - maxVal)).ToArray();
        var sumExp = expValues.Sum();
        var probabilities = expValues.Select(x => x / sumExp).ToArray();

        // Get top K indices
        // 상위 K개 인덱스 가져오기
        return probabilities
            .Select((prob, index) => (Probability: prob, Index: index))
            .OrderByDescending(x => x.Probability)
            .Take(k)
            .Select(x => new Prediction(LabelMap.GetLabel(x.Index), x.Probability))
            .ToList()
            .AsReadOnly();
    }

    public void Dispose()
    {
        if (_disposed) return;

        _session?.Dispose();
        _session = null;
        _disposed = true;
    }
}
