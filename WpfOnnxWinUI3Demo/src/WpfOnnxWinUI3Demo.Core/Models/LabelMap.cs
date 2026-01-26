namespace WpfOnnxWinUI3Demo.Core.Models;

/// <summary>
/// Provides ImageNet class labels for ONNX model predictions.
/// ONNX 모델 예측을 위한 ImageNet 클래스 레이블을 제공합니다.
/// </summary>
public static class LabelMap
{
    private static string[]? _labels;

    /// <summary>
    /// Gets the ImageNet labels. Loads from file or uses default subset.
    /// ImageNet 레이블을 반환합니다. 파일에서 로드하거나 기본 서브셋을 사용합니다.
    /// </summary>
    public static string[] Labels => _labels ??= LoadLabels();

    /// <summary>
    /// Loads labels from file or returns a default set.
    /// 파일에서 레이블을 로드하거나 기본 세트를 반환합니다.
    /// </summary>
    private static string[] LoadLabels()
    {
        var labelsPath = Path.Combine(AppContext.BaseDirectory, "Assets", "model", "imagenet_labels.txt");

        if (File.Exists(labelsPath))
        {
            return File.ReadAllLines(labelsPath);
        }

        // Return default placeholder labels if file not found
        // 파일을 찾을 수 없으면 기본 플레이스홀더 레이블 반환
        return Enumerable.Range(0, 1000).Select(i => $"class_{i}").ToArray();
    }

    /// <summary>
    /// Gets a label by index with bounds checking.
    /// 경계 검사와 함께 인덱스로 레이블을 가져옵니다.
    /// </summary>
    public static string GetLabel(int index)
    {
        if (index < 0 || index >= Labels.Length)
        {
            return $"unknown_{index}";
        }

        return Labels[index];
    }
}
