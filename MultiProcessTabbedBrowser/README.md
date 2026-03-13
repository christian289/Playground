# Multi-Process Tabbed Browser (WPF)

크로미움 스타일의 멀티프로세스 아키텍처를 WPF로 구현한 탭 브라우저입니다.

## 아키텍처

```
┌─────────────────────────────────────────────────┐
│  TabHost (Host Process)                         │
│  ┌─────────┬─────────┬─────────┬───┐            │
│  │  Tab 1  │  Tab 2  │  Tab 3  │ + │  ← Tab Bar │
│  └─────────┴─────────┴─────────┴───┘            │
│  ┌─────────────────────────────────┐            │
│  │                                 │            │
│  │  Embedded Child Window          │            │
│  │  (SetParent API)                │            │
│  │                                 │            │
│  └─────────────────────────────────┘            │
└─────────────────────────────────────────────────┘
         │              │              │
    Named Pipe     Named Pipe     Named Pipe
         │              │              │
    ┌────┴────┐   ┌────┴────┐   ┌────┴────┐
    │TabChild │   │TabChild │   │TabChild │
    │ PID:101 │   │ PID:102 │   │ PID:103 │
    └─────────┘   └─────────┘   └─────────┘
```

## 프로젝트 구성

| 프로젝트 | 역할 |
|---------|------|
| **TabHost** | 메인 호스트 프로세스. 탭 바 관리, 자식 프로세스 윈도우 임베딩 |
| **TabChild** | 탭 컨텐츠 프로세스. 독립 실행 가능한 WPF 윈도우 |
| **SharedLib** | IPC 메시지, Named Pipe 통신, Win32 API 래퍼 |

## 핵심 기능

- **멀티프로세스 격리**: 각 탭이 독립 프로세스로 실행되어 하나가 크래시해도 다른 탭에 영향 없음
- **탭 분리 (Detach)**: 탭을 드래그하여 윈도우 밖으로 끌면 독립 윈도우로 분리됨
- **탭 합치기 (Attach)**: 분리된 독립 TabChild 윈도우에서 Host PID를 입력하면 다시 탭으로 합쳐짐
- **Named Pipe IPC**: Host-Child 간 비동기 JSON 메시지 통신
- **Win32 Window Embedding**: `SetParent` API로 자식 프로세스 윈도우를 호스트에 임베딩
- **Attach Pipe Listener**: Host가 글로벌 파이프를 열어 외부 TabChild의 합류 요청을 수신

## 탭 분리/합치기 흐름

```
[탭 드래그로 분리]
  TabHost → RequestDetach → TabChild
  TabChild: Win32 DetachWindow → 독립 윈도우로 전환
  TabChild → DetachCompleted → TabHost
  TabHost: 탭 목록에서 제거 (프로세스는 유지)

[독립 윈도우에서 Host로 합치기]
  TabChild → RequestAttach → TabHost (글로벌 Attach 파이프)
  TabHost → AttachAccepted (새 전용 파이프 이름 전달) → TabChild
  TabChild: 새 파이프로 재연결
  TabChild → WindowHandleReady → TabHost
  TabHost: Win32 EmbedWindow → 탭으로 임베딩
```

## 키보드 단축키

| 단축키 | 기능 |
|-------|------|
| `Ctrl+T` | 새 탭 |
| `Ctrl+W` | 현재 탭 닫기 |
| `Ctrl+Tab` | 다음 탭 |
| `Ctrl+Shift+Tab` | 이전 탭 |
| `Ctrl+D` | 현재 탭 분리 (독립 윈도우로) |

## 빌드 및 실행

```bash
# 솔루션 전체 빌드
dotnet build MultiProcessTabbedBrowser.sln

# TabHost 실행 (TabChild는 자동으로 시작됨)
dotnet run --project TabHost
```

## 요구사항

- .NET 8.0 SDK
- Windows 10/11 (WPF + Win32 API 사용)
