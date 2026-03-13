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
- **탭 합치기/분리**: 독립 윈도우를 탭으로 합치거나, 탭을 드래그하여 독립 윈도우로 분리
- **Named Pipe IPC**: Host-Child 간 비동기 메시지 통신
- **Win32 Window Embedding**: `SetParent` API로 자식 프로세스 윈도우를 호스트에 임베딩

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
