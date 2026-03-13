using System.IO;
using System.IO.Pipes;

namespace SharedLib;

/// <summary>
/// Named Pipe 클라이언트 (Child 프로세스에서 Host에 연결)
/// </summary>
public class IpcPipeClient : IDisposable
{
    private NamedPipeClientStream? _pipeClient;
    private StreamReader? _reader;
    private StreamWriter? _writer;
    private CancellationTokenSource? _cts;
    private Task? _listenTask;
    private readonly string _pipeName;
    private bool _disposed;

    public bool IsConnected => _pipeClient?.IsConnected ?? false;
    public event Action<IpcMessage>? MessageReceived;
    public event Action? Disconnected;

    public IpcPipeClient(string pipeName)
    {
        _pipeName = pipeName;
    }

    public async Task ConnectAsync(int timeoutMs = 5000, CancellationToken cancellationToken = default)
    {
        _pipeClient = new NamedPipeClientStream(
            ".",
            _pipeName,
            PipeDirection.InOut,
            PipeOptions.Asynchronous);

        await _pipeClient.ConnectAsync(timeoutMs, cancellationToken);

        _reader = new StreamReader(_pipeClient);
        _writer = new StreamWriter(_pipeClient) { AutoFlush = true };

        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _listenTask = ListenAsync(_cts.Token);
    }

    public async Task SendAsync(IpcMessage message)
    {
        if (_writer == null || !IsConnected) return;
        try
        {
            await _writer.WriteLineAsync(message.Serialize());
        }
        catch (IOException)
        {
            Disconnected?.Invoke();
        }
        catch (ObjectDisposedException) { }
    }

    private async Task ListenAsync(CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested && _reader != null)
            {
                var line = await _reader.ReadLineAsync(ct);
                if (line == null)
                {
                    Disconnected?.Invoke();
                    break;
                }

                var msg = IpcMessage.Deserialize(line);
                if (msg != null)
                {
                    MessageReceived?.Invoke(msg);
                }
            }
        }
        catch (OperationCanceledException) { }
        catch (IOException)
        {
            Disconnected?.Invoke();
        }
        catch (ObjectDisposedException) { }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _cts?.Cancel();
        _reader?.Dispose();
        _writer?.Dispose();
        _pipeClient?.Dispose();
        _cts?.Dispose();
        GC.SuppressFinalize(this);
    }
}
