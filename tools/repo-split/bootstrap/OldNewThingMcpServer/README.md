# OldNewThingMcpServer

Microsoft DevBlogs(대표적으로 Raymond Chen의 *The Old New Thing*) 피드를
MCP 도구로 노출하는 서버. 같은 기능을 두 가지 호스팅 방식으로 구현했다.

| 프로젝트 | 방식 | 용도 |
|---|---|---|
| `MicrosoftDevBlogsMcpServer` | stdio | Claude Code 등 로컬 MCP 클라이언트 |
| `MicrosoftDevBlogsRemoteMcpServer` | HTTP | 원격 호스팅 |

> 저장소 이름은 `OldNewThingMcpServer`지만 내부 프로젝트명은
> `MicrosoftDevBlogsMcpServer`다. 대상 블로그가 The Old New Thing 하나에서
> DevBlogs 전반으로 넓어지면서 생긴 차이다.

## 요구 사항

- .NET 10 SDK

## 실행

```
dotnet run --project MicrosoftDevBlogsMcpServer/MicrosoftDevBlogsMcpServer.csproj
```

MCP 등록 정보는 `MicrosoftDevBlogsMcpServer/.mcp/server.json`에 있다.
각 프로젝트 폴더의 README에 도구 목록과 상세 사용법이 있다.
