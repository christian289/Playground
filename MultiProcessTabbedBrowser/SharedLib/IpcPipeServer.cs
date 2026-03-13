using System.IO;
using System.IO.Pipes;

namespace SharedLib;

/// <summary>
/// Named Pipe 서버 (Host 측에서 각 Child 당 하나씩 생성)
/// </summary>
public class IpcPipeServer : IDisposable
{
    private NamedPipeServerStream? _pipeServer;
    private StreamReader? _reader;
    private StreamWriter? _writer;
    private CancellationTokenSource? _cts;
    private Task? _listenTask;
    private readonly string _pipeName;
    private bool _disposed;

    public string PipeName => _pipeName;
    public bool IsConnected => _pipeServer?.IsConnected ?? false;
    public event Action<IpcMessage>? MessageReceived;
    public event Action? ClientDisconnected;

    public IpcPipeServer(string pipeName)
    {
        _pipeName = pipeName;
    }

    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        _pipeServer = new NamedPipeServerStream(
            _pipeName,
            PipeDirection.InOut,
            1,
            PipeTransmissionMode.Byte,
            PipeOptions.Asynchronous);

        await _pipeServer.WaitForConnectionAsync(cancellationToken);

        _reader = new StreamReader(_pipeServer);
        _writer = new StreamWriter(_pipeServer) { AutoFlush = true };

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
            ClientDisconnected?.Invoke();
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
                    ClientDisconnected?.Invoke();
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
            ClientDisconnected?.Invoke();
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
        _pipeServer?.Dispose();
        _cts?.Dispose();
        GC.SuppressFinalize(this);
    }
}
