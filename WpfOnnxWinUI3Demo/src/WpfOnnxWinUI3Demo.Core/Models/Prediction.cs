namespace WpfOnnxWinUI3Demo.Core.Models;

/// <summary>
/// Represents a single prediction result from the ONNX model.
/// ONNX 모델의 단일 예측 결과를 나타냅니다.
/// </summary>
public sealed record Prediction(string Label, float Confidence)
{
    /// <summary>
    /// Gets the confidence as a percentage string.
    /// 신뢰도를 백분율 문자열로 반환합니다.
    /// </summary>
    public string ConfidencePercent => $"{Confidence * 100:F2}%";
}
