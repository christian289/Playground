# Multi-Process Tabbed Browser (WPF)

P2P 방식의 멀티프로세스 탭 브라우저. 모든 윈도우가 대등한 피어로, 호스트이자 차일드가 될 수 있습니다.

## 아키텍처

```
┌── BrowserWindow (PID:100) ───────────┐
│ [This Window] [PID:101] [PID:102] [+]│
│ ┌──────────────────────────────────┐  │
│ │  Embedded: PID:101 (as tab)     │  │     ┌── BrowserWindow (PID:103) ──┐
│ └──────────────────────────────────┘  │     │ [This Window]  [+]          │
└───────────────────────────────────────┘     │ ┌────────────────────────┐  │
         │              │                     │ │  Local content         │  │
    Named Pipe     Named Pipe                 │ └────────────────────────┘  │
         │              │                     └─────────────────────────────┘
   PID:101(embedded)  PID:102(embedded)            ↕ dock/undock 가능

모든 윈도우는 동일한 실행파일 (BrowserWindow.exe)
호스트 ↔ 차일드 역할이 동적으로 전환됨
```

## 핵심 개념

- **단일 실행파일**: `BrowserWindow.exe` 하나로 모든 윈도우가 동일
- **대등한 피어**: 어떤 윈도우든 다른 윈도우를 탭으로 호스팅할 수 있고, 자신이 다른 윈도우의 탭이 될 수도 있음
- **동적 역할 전환**: 호스트였던 윈도우가 분리되어 다른 윈도우에 dock되면 차일드가 됨
- **자동 해제**: dock될 때 기존에 호스팅하던 탭들은 자동으로 독립 윈도우로 해제됨

## 프로젝트 구성

| 프로젝트 | 역할 |
|---------|------|
| **BrowserWindow** | 메인 실행파일. 호스트/차일드 역할을 모두 수행하는 통합 WPF 윈도우 |
| **SharedLib** | IPC 메시지, Named Pipe 통신, Win32 API 래퍼 |

## Dock / Undock 흐름

```
[Window A를 Window B에 dock]
  A → RequestAttach → B (B의 Attach 파이프)
  B → AttachAccepted (전용 파이프 이름) → A
  A: 전용 파이프로 재연결
  A → WindowHandleReady → B
  B: Win32 EmbedWindow → A를 탭으로 임베딩
  A: 타이틀바/탭바 숨김, Embedded 모드 진입

[탭을 분리 (undock)]
  B → RequestDetach → A
  A: Win32 DetachWindow → 독립 윈도우 복원
  A → DetachCompleted → B
  A: 타이틀바/탭바 다시 표시, Standalone 모드 복귀
  A: 이제 다른 윈도우에 다시 dock 가능
```

## 키보드 단축키

| 단축키 | 기능 |
|-------|------|
| `Ctrl+N` | 새 윈도우 (현재 윈도우에 탭으로 추가) |
| `Ctrl+W` | 현재 호스팅 탭 닫기 |
| `Ctrl+Tab` | 다음 탭 |
| `Ctrl+Shift+Tab` | 이전 탭 |
| `Ctrl+D` | 현재 호스팅 탭 분리 (독립 윈도우로) |

## 빌드 및 실행

```bash
# 빌드
dotnet build MultiProcessTabbedBrowser.sln

# 실행 (첫 번째 윈도우)
dotnet run --project BrowserWindow

# 두 번째 윈도우를 별도로 실행
dotnet run --project BrowserWindow

# 두 번째 윈도우에서 첫 번째 윈도우의 PID를 입력하고 Dock 버튼 클릭
```

## 요구사항

- .NET 8.0 SDK
- Windows 10/11 (WPF + Win32 API 사용)
