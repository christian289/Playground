using System.Text.Json;
using System.Text.Json.Serialization;

namespace SharedLib;

/// <summary>
/// IPC 메시지 타입 정의
/// </summary>
public enum IpcMessageType
{
    // Host -> Child
    RequestEmbed,       // 자식 프로세스에게 윈도우 핸들 요청
    RequestDetach,      // 자식 프로세스에게 분리 요청
    SetTitle,           // 탭 제목 변경 요청
    Navigate,           // URL 이동 요청
    CloseTab,           // 탭 닫기 요청
    Ping,               // 연결 확인

    // Child -> Host
    WindowHandleReady,  // 자식 윈도우 핸들 전달
    TitleChanged,       // 제목 변경 알림
    DetachCompleted,    // 분리 완료 알림
    CloseRequested,     // 닫기 요청
    Pong,               // Ping 응답
    ChildReady,         // 자식 프로세스 초기화 완료
}

/// <summary>
/// Host-Child 간 통신 메시지
/// </summary>
public class IpcMessage
{
    [JsonPropertyName("type")]
    public IpcMessageType Type { get; set; }

    [JsonPropertyName("tabId")]
    public string TabId { get; set; } = string.Empty;

    [JsonPropertyName("data")]
    public Dictionary<string, string> Data { get; set; } = new();

    public string Serialize() => JsonSerializer.Serialize(this);

    public static IpcMessage? Deserialize(string json)
    {
        try
        {
            return JsonSerializer.Deserialize<IpcMessage>(json);
        }
        catch
        {
            return null;
        }
    }
}
