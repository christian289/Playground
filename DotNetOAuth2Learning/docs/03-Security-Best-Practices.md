# OAuth 2.0 보안 모범 사례

## 1. 토큰 보안

### Access Token

| 원칙 | 설명 |
|------|------|
| 짧은 수명 | 5분 ~ 1시간 권장 |
| HTTPS 필수 | 토큰 전송 시 항상 TLS 사용 |
| 최소 권한 | 필요한 scope만 요청 |
| 안전한 저장 | 로컬 스토리지 사용 금지 (XSS 취약) |

### Refresh Token

```csharp
// Refresh Token 보안 설정 예시
services.AddAuthentication()
    .AddOAuth("Provider", options =>
    {
        // Refresh Token은 서버 사이드에만 저장
        options.SaveTokens = true;

        // 토큰을 암호화하여 저장
        options.TokenEndpoint = "https://auth.server/token";
    });
```

### 토큰 저장 위치 가이드

| 클라이언트 타입 | Access Token | Refresh Token |
|----------------|--------------|---------------|
| 서버 사이드 웹 | 세션/메모리 | 암호화된 DB |
| SPA | 메모리 (변수) | 사용 금지 또는 BFF 패턴 |
| 모바일 앱 | Secure Storage | Secure Storage |
| 네이티브 앱 | OS Keychain | OS Keychain |

---

## 2. CSRF 방지 (State Parameter)

**State 파라미터**는 CSRF 공격을 방지하는 핵심 보안 메커니즘입니다.

```csharp
public class OAuthStateService
{
    private readonly IDistributedCache _cache;

    public async Task<string> GenerateStateAsync(string userId)
    {
        // 암호학적으로 안전한 랜덤 값 생성
        var state = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

        // 서버에 저장 (검증용)
        await _cache.SetStringAsync(
            $"oauth_state:{state}",
            userId,
            new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
            });

        return state;
    }

    public async Task<bool> ValidateStateAsync(string state, string userId)
    {
        var storedUserId = await _cache.GetStringAsync($"oauth_state:{state}");

        if (storedUserId != userId)
        {
            return false;
        }

        // 한 번 사용 후 삭제
        await _cache.RemoveAsync($"oauth_state:{state}");
        return true;
    }
}
```

---

## 3. Redirect URI 검증

### 취약한 설정 (하지 말 것)

```csharp
// 위험: 와일드카드 허용
options.CallbackPath = "/callback*";  // 절대 금지!

// 위험: 동적 redirect_uri 허용
var redirectUri = Request.Query["redirect_uri"];  // 검증 없이 사용 금지!
```

### 안전한 설정

```csharp
public class RedirectUriValidator
{
    private readonly HashSet<string> _allowedUris = new()
    {
        "https://myapp.com/callback",
        "https://myapp.com/auth/callback"
    };

    public bool Validate(string redirectUri)
    {
        // 정확히 일치하는지 확인 (trailing slash 주의)
        return _allowedUris.Contains(redirectUri.TrimEnd('/'));
    }
}
```

---

## 4. Token Validation

### JWT 검증 체크리스트

```csharp
services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            // 1. 서명 검증 (필수)
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(key),

            // 2. 발급자 검증 (필수)
            ValidateIssuer = true,
            ValidIssuer = "https://auth.mycompany.com",

            // 3. 대상 검증 (필수)
            ValidateAudience = true,
            ValidAudience = "my-api",

            // 4. 만료 시간 검증 (필수)
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),  // 시간 오차 허용

            // 5. 알고리즘 제한 (권장)
            ValidAlgorithms = new[] { SecurityAlgorithms.RsaSha256 }
        };

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = context =>
            {
                // 추가 검증 로직 (예: 사용자 상태 확인)
                return Task.CompletedTask;
            },
            OnAuthenticationFailed = context =>
            {
                // 로깅 (민감 정보 제외)
                Log.Warning("Token validation failed: {Error}",
                    context.Exception.Message);
                return Task.CompletedTask;
            }
        };
    });
```

---

## 5. Scope 관리

### 최소 권한 원칙

```csharp
// 나쁜 예: 과도한 권한 요청
var scopes = "openid profile email admin.all api.full";

// 좋은 예: 필요한 권한만 요청
var scopes = "openid profile";  // 기본 로그인
var scopes = "api.read";        // 읽기 전용 API 접근
```

### Scope 기반 권한 부여

```csharp
// 정책 기반 인가
services.AddAuthorization(options =>
{
    options.AddPolicy("CanReadUsers", policy =>
        policy.RequireClaim("scope", "users.read"));

    options.AddPolicy("CanWriteUsers", policy =>
        policy.RequireClaim("scope", "users.write"));
});

// 컨트롤러에서 사용
[Authorize(Policy = "CanReadUsers")]
[HttpGet("users")]
public IActionResult GetUsers() { }

[Authorize(Policy = "CanWriteUsers")]
[HttpPost("users")]
public IActionResult CreateUser() { }
```

---

## 6. Client Secret 관리

### 안전한 저장

```csharp
// appsettings.json에 직접 저장 금지!
// 대신 다음을 사용:

// 1. User Secrets (개발 환경)
// dotnet user-secrets set "OAuth:ClientSecret" "your-secret"

// 2. Azure Key Vault (프로덕션)
builder.Configuration.AddAzureKeyVault(
    new Uri("https://your-vault.vault.azure.net/"),
    new DefaultAzureCredential());

// 3. 환경 변수
var clientSecret = Environment.GetEnvironmentVariable("OAUTH_CLIENT_SECRET");
```

### Secret Rotation

```csharp
public class SecretRotationService
{
    // 여러 secret을 지원하여 무중단 교체 가능
    private readonly List<string> _validSecrets;

    public bool ValidateSecret(string secret)
    {
        return _validSecrets.Any(s =>
            CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(s),
                Encoding.UTF8.GetBytes(secret)));
    }
}
```

---

## 7. 로깅 및 모니터링

### 로깅 원칙

```csharp
// 나쁜 예: 토큰 전체 로깅
_logger.LogInformation("Token: {Token}", accessToken);  // 절대 금지!

// 좋은 예: 필요한 정보만 로깅
_logger.LogInformation(
    "Token issued for user {UserId}, expires at {Expiry}",
    userId,
    tokenExpiry);

// 토큰 참조용 (마지막 4자리만)
var tokenHint = accessToken.Substring(accessToken.Length - 4);
_logger.LogInformation("Token ...{TokenHint} validated", tokenHint);
```

### 모니터링 항목

- 실패한 인증 시도 (Brute Force 감지)
- 비정상적인 토큰 갱신 패턴
- 알 수 없는 클라이언트 ID 요청
- Scope 에스컬레이션 시도

---

## 8. 일반적인 취약점과 대응

### 취약점 체크리스트

| 취약점 | 대응 |
|--------|------|
| Authorization Code Injection | PKCE 사용 |
| CSRF | State 파라미터 검증 |
| Open Redirect | Redirect URI 화이트리스트 |
| Token Leakage | HTTPS, 안전한 저장소 |
| Insufficient Scope Validation | 서버 사이드 scope 검증 |
| Client Secret Exposure | 환경 변수, Key Vault 사용 |

---

## 학습 체크리스트

- [ ] 토큰을 안전하게 저장하는 방법을 알고 있다
- [ ] State 파라미터의 역할을 설명할 수 있다
- [ ] JWT 토큰 검증 시 확인해야 할 항목을 알고 있다
- [ ] Scope 기반 권한 부여를 구현할 수 있다
- [ ] Client Secret을 안전하게 관리하는 방법을 알고 있다

## 다음 단계
→ 이제 실습 예제로 넘어가서 직접 구현해봅시다!
→ [../src/01-AuthorizationCodeFlow](../src/01-AuthorizationCodeFlow)
