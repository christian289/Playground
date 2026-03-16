using System.Text.Json;
using System.Text.Json.Serialization;

namespace SharedLib;

public enum IpcMessageType
{
    // Dock request (peer -> target's attach listener)
    RequestAttach,
    AttachAccepted,

    // After dock established (embedded -> host)
    WindowHandleReady,
    Ready,
    TitleChanged,
    DetachCompleted,
    CloseRequested,

    // Host -> embedded
    RequestDetach,
    CloseTab,
    Ping,

    // Embedded -> host
    Pong,
}

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
