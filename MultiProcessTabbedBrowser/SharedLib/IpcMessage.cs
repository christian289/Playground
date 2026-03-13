using System.Text.Json;
using System.Text.Json.Serialization;

namespace SharedLib;

public enum IpcMessageType
{
    // Host -> Child
    RequestEmbed,
    RequestDetach,
    SetTitle,
    Navigate,
    CloseTab,
    Ping,

    // Child -> Host
    WindowHandleReady,
    TitleChanged,
    DetachCompleted,
    CloseRequested,
    Pong,
    ChildReady,

    // Child -> Host (re-attach)
    RequestAttach,
    AttachAccepted,
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
