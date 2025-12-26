using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// 설정값 (실제 환경에서는 안전한 저장소 사용)
// ============================================================
var jwtSettings = new JwtSettings
{
    SecretKey = "ThisIsA32CharacterLongSecretKey!", // 최소 32자
    Issuer = "https://localhost:5001",
    Audience = "api-server",
    ExpirationMinutes = 60
};

// 등록된 클라이언트 목록 (실제 환경에서는 DB 사용)
var registeredClients = new Dictionary<string, string>
{
    ["service-client-1"] = "secret123",
    ["batch-processor"] = "batchSecret456",
    ["reporting-service"] = "reportSecret789"
};

builder.Services.AddSingleton(jwtSettings);
builder.Services.AddSingleton(registeredClients);

// ============================================================
// JWT 인증 설정
// ============================================================
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            // 1. 서명 검증
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtSettings.SecretKey)),

            // 2. 발급자 검증
            ValidateIssuer = true,
            ValidIssuer = jwtSettings.Issuer,

            // 3. 대상 검증
            ValidateAudience = true,
            ValidAudience = jwtSettings.Audience,

            // 4. 만료 시간 검증
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        // 이벤트 핸들러 (디버깅/로깅용)
        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = context =>
            {
                Console.WriteLine($"[Auth] Failed: {context.Exception.Message}");
                return Task.CompletedTask;
            },
            OnTokenValidated = context =>
            {
                var clientId = context.Principal?.FindFirst("client_id")?.Value;
                Console.WriteLine($"[Auth] Token validated for client: {clientId}");
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization(options =>
{
    // Scope 기반 정책
    options.AddPolicy("read:data", policy =>
        policy.RequireClaim("scope", "read:data"));

    options.AddPolicy("write:data", policy =>
        policy.RequireClaim("scope", "write:data"));
});

var app = builder.Build();

// ============================================================
// 미들웨어
// ============================================================
app.UseAuthentication();
app.UseAuthorization();

// ============================================================
// 엔드포인트
// ============================================================

// 토큰 엔드포인트 (Client Credentials Grant)
app.MapPost("/oauth/token", (TokenRequest request,
    JwtSettings jwt,
    Dictionary<string, string> clients) =>
{
    // 1. Grant Type 검증
    if (request.GrantType != "client_credentials")
    {
        return Results.BadRequest(new { error = "unsupported_grant_type" });
    }

    // 2. 클라이언트 인증
    if (string.IsNullOrEmpty(request.ClientId) ||
        string.IsNullOrEmpty(request.ClientSecret))
    {
        return Results.BadRequest(new { error = "invalid_request" });
    }

    if (!clients.TryGetValue(request.ClientId, out var secret) ||
        secret != request.ClientSecret)
    {
        return Results.Unauthorized();
    }

    // 3. Scope 검증 (선택적)
    var requestedScopes = request.Scope?.Split(' ') ?? ["read:data"];
    var allowedScopes = new[] { "read:data", "write:data" };
    var grantedScopes = requestedScopes.Intersect(allowedScopes).ToArray();

    // 4. Access Token 생성
    var claims = new List<Claim>
    {
        new("client_id", request.ClientId),
        new("scope", string.Join(" ", grantedScopes)),
        new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
    };

    var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SecretKey));
    var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

    var token = new JwtSecurityToken(
        issuer: jwt.Issuer,
        audience: jwt.Audience,
        claims: claims,
        expires: DateTime.UtcNow.AddMinutes(jwt.ExpirationMinutes),
        signingCredentials: credentials);

    var accessToken = new JwtSecurityTokenHandler().WriteToken(token);

    // 5. 응답
    return Results.Ok(new TokenResponse
    {
        AccessToken = accessToken,
        TokenType = "Bearer",
        ExpiresIn = jwt.ExpirationMinutes * 60,
        Scope = string.Join(" ", grantedScopes)
    });
});

// 보호된 API 엔드포인트
app.MapGet("/api/data", (ClaimsPrincipal user) =>
{
    var clientId = user.FindFirst("client_id")?.Value;
    var scope = user.FindFirst("scope")?.Value;

    return Results.Ok(new
    {
        message = "This is protected data",
        accessedBy = clientId,
        grantedScope = scope,
        timestamp = DateTime.UtcNow,
        data = new[]
        {
            new { id = 1, name = "Item 1", value = 100 },
            new { id = 2, name = "Item 2", value = 200 },
            new { id = 3, name = "Item 3", value = 300 }
        }
    });
}).RequireAuthorization();

// Scope 기반 보호 엔드포인트
app.MapPost("/api/data", (DataItem item, ClaimsPrincipal user) =>
{
    var clientId = user.FindFirst("client_id")?.Value;

    return Results.Created($"/api/data/{item.Id}", new
    {
        message = "Data created successfully",
        createdBy = clientId,
        item
    });
}).RequireAuthorization("write:data");

// 헬스 체크 (인증 불필요)
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

// 토큰 검사 (Introspection - 간단 버전)
app.MapPost("/oauth/introspect", (IntrospectRequest request, JwtSettings jwt) =>
{
    try
    {
        var handler = new JwtSecurityTokenHandler();
        var validationParams = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwt.SecretKey)),
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateLifetime = true
        };

        var principal = handler.ValidateToken(request.Token, validationParams, out var validatedToken);

        return Results.Ok(new
        {
            active = true,
            client_id = principal.FindFirst("client_id")?.Value,
            scope = principal.FindFirst("scope")?.Value,
            exp = ((JwtSecurityToken)validatedToken).ValidTo
        });
    }
    catch
    {
        return Results.Ok(new { active = false });
    }
});

Console.WriteLine("API Server running on http://localhost:5001");
Console.WriteLine("Token endpoint: POST /oauth/token");
Console.WriteLine("Protected endpoint: GET /api/data");

app.Run("http://localhost:5001");

// ============================================================
// DTO 클래스들
// ============================================================
record JwtSettings
{
    public required string SecretKey { get; init; }
    public required string Issuer { get; init; }
    public required string Audience { get; init; }
    public int ExpirationMinutes { get; init; } = 60;
}

record TokenRequest
{
    public string? GrantType { get; init; }
    public string? ClientId { get; init; }
    public string? ClientSecret { get; init; }
    public string? Scope { get; init; }
}

record TokenResponse
{
    public required string AccessToken { get; init; }
    public required string TokenType { get; init; }
    public int ExpiresIn { get; init; }
    public string? Scope { get; init; }
}

record IntrospectRequest
{
    public required string Token { get; init; }
}

record DataItem
{
    public int Id { get; init; }
    public string? Name { get; init; }
    public decimal Value { get; init; }
}
