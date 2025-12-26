# OAuth 2.0 Grant Types (인가 유형)

## Grant Type 선택 가이드

| 시나리오 | 권장 Grant Type |
|----------|-----------------|
| 웹 애플리케이션 (서버 사이드) | Authorization Code |
| SPA / 모바일 앱 | Authorization Code + PKCE |
| 서버 간 통신 (M2M) | Client Credentials |
| 신뢰할 수 있는 앱 (1st party) | Resource Owner Password (비권장) |

---

## 1. Authorization Code Grant

**가장 일반적이고 안전한 플로우**입니다. 서버 사이드 웹 애플리케이션에 적합합니다.

### 플로우 다이어그램

```
     +----------+
     | Resource |
     |   Owner  |
     +----------+
          ^
          |
         (2)
     +---|----+          Client Identifier      +---------------+
     |        |--(1)-- & Redirection URI ----->|               |
     |  User- |                                | Authorization |
     |  Agent |--(2)-- User authenticates ---->|     Server    |
     |        |                                |               |
     |        |<-(3)-- Authorization Code -----|               |
     +--------+                                +---------------+
         |                                            ^
        (3)                                           |
         v                                            |
     +--------+                                       |
     |        |--(4)-- Authorization Code ----------->|
     | Client |        + Redirect URI                 |
     |        |                                       |
     |        |<-(5)-- Access Token -----------------|
     +--------+       (+ Refresh Token)
```

### 단계별 설명

**Step 1: Authorization Request**
```http
GET /authorize?
    response_type=code
    &client_id=your_client_id
    &redirect_uri=https://yourapp.com/callback
    &scope=openid profile email
    &state=random_state_value
```

**Step 2: 사용자 인증 및 동의**
- 사용자가 로그인하고 권한을 승인

**Step 3: Authorization Code 수신**
```http
GET https://yourapp.com/callback?
    code=authorization_code_here
    &state=random_state_value
```

**Step 4: Token 교환**
```http
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=authorization_code_here
&redirect_uri=https://yourapp.com/callback
&client_id=your_client_id
&client_secret=your_client_secret
```

**Step 5: Token 응답**
```json
{
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "dGhpcyBpcyBhIHJlZn...",
    "scope": "openid profile email"
}
```

---

## 2. Authorization Code + PKCE

**PKCE (Proof Key for Code Exchange)** 는 Authorization Code Grant의 보안 확장입니다.
SPA나 모바일 앱처럼 client_secret을 안전하게 보관할 수 없는 공개 클라이언트에 필수입니다.

### PKCE 동작 원리

```
1. 클라이언트: code_verifier (랜덤 문자열) 생성
2. 클라이언트: code_challenge = SHA256(code_verifier) 계산
3. Authorization Request에 code_challenge 포함
4. Token Request에 code_verifier 포함
5. 서버: code_verifier로 code_challenge 검증
```

### .NET에서 PKCE 구현

```csharp
using System.Security.Cryptography;
using System.Text;

public class PkceHelper
{
    public static (string CodeVerifier, string CodeChallenge) GeneratePkce()
    {
        // 1. Code Verifier 생성 (43-128자의 랜덤 문자열)
        var bytes = new byte[32];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(bytes);
        var codeVerifier = Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

        // 2. Code Challenge 생성 (SHA256 해시)
        using var sha256 = SHA256.Create();
        var challengeBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(codeVerifier));
        var codeChallenge = Convert.ToBase64String(challengeBytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

        return (codeVerifier, codeChallenge);
    }
}
```

### Authorization Request with PKCE
```http
GET /authorize?
    response_type=code
    &client_id=your_client_id
    &redirect_uri=https://yourapp.com/callback
    &scope=openid profile
    &state=random_state
    &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
    &code_challenge_method=S256
```

---

## 3. Client Credentials Grant

**서버 간 통신(Machine-to-Machine)** 에 사용됩니다. 사용자 컨텍스트가 없습니다.

### 플로우

```
+--------+                               +---------------+
|        |                               |               |
| Client |--(1)-- Client Authentication->| Authorization |
|        |        + scope request        |     Server    |
|        |                               |               |
|        |<-(2)-- Access Token ----------|               |
+--------+                               +---------------+
```

### Token Request

```http
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=your_client_id
&client_secret=your_client_secret
&scope=api.read api.write
```

### .NET 구현 예시

```csharp
public class TokenService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;

    public async Task<string> GetAccessTokenAsync()
    {
        var tokenEndpoint = _config["OAuth:TokenEndpoint"];

        var request = new HttpRequestMessage(HttpMethod.Post, tokenEndpoint);
        request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "client_credentials",
            ["client_id"] = _config["OAuth:ClientId"],
            ["client_secret"] = _config["OAuth:ClientSecret"],
            ["scope"] = _config["OAuth:Scope"]
        });

        var response = await _httpClient.SendAsync(request);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadFromJsonAsync<TokenResponse>();
        return json.AccessToken;
    }
}
```

---

## 4. Resource Owner Password Grant (비권장)

**경고**: 이 플로우는 레거시 시스템이나 신뢰할 수 있는 1st-party 앱에서만 사용해야 합니다.

```http
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=password
&username=user@example.com
&password=user_password
&client_id=your_client_id
&scope=openid profile
```

---

## 5. Refresh Token Grant

Access Token이 만료되었을 때 새 토큰을 얻는 데 사용합니다.

```http
POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
&refresh_token=your_refresh_token
&client_id=your_client_id
```

### .NET에서 자동 토큰 갱신

```csharp
public class TokenRefreshHandler : DelegatingHandler
{
    private readonly ITokenService _tokenService;
    private string _accessToken;
    private DateTime _tokenExpiry;

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        if (DateTime.UtcNow >= _tokenExpiry.AddMinutes(-5))
        {
            // 만료 5분 전에 토큰 갱신
            await RefreshTokenAsync();
        }

        request.Headers.Authorization =
            new AuthenticationHeaderValue("Bearer", _accessToken);

        return await base.SendAsync(request, cancellationToken);
    }
}
```

---

## 학습 체크리스트

- [ ] 각 Grant Type의 사용 시나리오를 설명할 수 있다
- [ ] Authorization Code Flow의 단계를 순서대로 설명할 수 있다
- [ ] PKCE가 필요한 이유와 동작 원리를 이해한다
- [ ] Client Credentials Flow를 구현할 수 있다
- [ ] Refresh Token의 용도를 이해한다

## 다음 단계
→ [03-Security-Best-Practices.md](03-Security-Best-Practices.md)에서 보안 모범 사례를 알아봅니다.
