using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.Google;
using System.Security.Claims;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// 1. 인증 서비스 구성
// ============================================================
builder.Services.AddAuthentication(options =>
{
    // 기본 인증 스킴: Cookie 기반 (세션 유지용)
    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    // Challenge 시 사용할 스킴: Google OAuth
    options.DefaultChallengeScheme = GoogleDefaults.AuthenticationScheme;
})
.AddCookie(options =>
{
    // 쿠키 설정
    options.Cookie.Name = "OAuthDemo";
    options.Cookie.HttpOnly = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.Cookie.SameSite = SameSiteMode.Lax;
    options.ExpireTimeSpan = TimeSpan.FromHours(1);
    options.SlidingExpiration = true;

    // 미인증 사용자 리다이렉트
    options.LoginPath = "/login";
    options.LogoutPath = "/logout";
    options.AccessDeniedPath = "/access-denied";
})
.AddGoogle(options =>
{
    // Google OAuth 설정 (User Secrets에서 로드)
    options.ClientId = builder.Configuration["Authentication:Google:ClientId"]
        ?? throw new InvalidOperationException("Google ClientId is not configured");
    options.ClientSecret = builder.Configuration["Authentication:Google:ClientSecret"]
        ?? throw new InvalidOperationException("Google ClientSecret is not configured");

    // 요청할 scope
    options.Scope.Add("email");
    options.Scope.Add("profile");

    // Access Token 저장 (API 호출 시 필요)
    options.SaveTokens = true;

    // 이벤트 핸들러
    options.Events.OnCreatingTicket = context =>
    {
        // 토큰 정보 로깅 (디버깅용)
        var accessToken = context.AccessToken;
        var refreshToken = context.RefreshToken;
        var expiresIn = context.ExpiresIn;

        Console.WriteLine($"[OAuth] Access Token received, expires in: {expiresIn}");
        return Task.CompletedTask;
    };
});

builder.Services.AddAuthorization();

var app = builder.Build();

// ============================================================
// 2. 미들웨어 파이프라인
// ============================================================
app.UseAuthentication();
app.UseAuthorization();

// ============================================================
// 3. 엔드포인트 정의
// ============================================================

// 홈 페이지
app.MapGet("/", (ClaimsPrincipal user) =>
{
    var isAuthenticated = user.Identity?.IsAuthenticated ?? false;

    var html = $"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>OAuth 2.0 Demo</title>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }}
                .btn {{ padding: 10px 20px; margin: 5px; text-decoration: none; border-radius: 5px; display: inline-block; }}
                .btn-primary {{ background: #4285f4; color: white; }}
                .btn-danger {{ background: #dc3545; color: white; }}
                .info-box {{ background: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0; }}
                pre {{ background: #282c34; color: #abb2bf; padding: 15px; border-radius: 5px; overflow-x: auto; }}
            </style>
        </head>
        <body>
            <h1>OAuth 2.0 Authorization Code Flow Demo</h1>

            {(isAuthenticated ? $"""
            <div class="info-box">
                <h3>Welcome, {user.FindFirst(ClaimTypes.Name)?.Value}!</h3>
                <p>Email: {user.FindFirst(ClaimTypes.Email)?.Value}</p>
            </div>
            <a href="/profile" class="btn btn-primary">View Profile</a>
            <a href="/tokens" class="btn btn-primary">View Tokens</a>
            <a href="/logout" class="btn btn-danger">Logout</a>
            """ : """
            <div class="info-box">
                <p>You are not logged in. Click the button below to authenticate with Google.</p>
            </div>
            <a href="/login" class="btn btn-primary">Login with Google</a>
            """)}

            <h2>How it works</h2>
            <pre>
1. User clicks "Login with Google"
2. Browser redirects to Google's Authorization endpoint
3. User authenticates and grants permission
4. Google redirects back with Authorization Code
5. Server exchanges code for Access Token
6. User is logged in with a session cookie
            </pre>
        </body>
        </html>
        """;

    return Results.Content(html, "text/html");
});

// 로그인 (Google OAuth Challenge 시작)
app.MapGet("/login", (HttpContext context) =>
{
    // State 파라미터는 ASP.NET Core가 자동으로 생성/검증
    var properties = new AuthenticationProperties
    {
        RedirectUri = "/",
        // 추가 데이터 저장 가능
        Items = { { "LoginTimestamp", DateTime.UtcNow.ToString() } }
    };

    return Results.Challenge(properties, [GoogleDefaults.AuthenticationScheme]);
});

// 로그아웃
app.MapGet("/logout", async (HttpContext context) =>
{
    await context.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    return Results.Redirect("/");
});

// 프로필 정보 (인증 필요)
app.MapGet("/profile", (ClaimsPrincipal user) =>
{
    var claims = user.Claims.Select(c => new { c.Type, c.Value }).ToList();

    var html = $"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Profile - OAuth Demo</title>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }}
                table {{ width: 100%; border-collapse: collapse; }}
                th, td {{ padding: 10px; border: 1px solid #ddd; text-align: left; }}
                th {{ background: #f8f9fa; }}
                .btn {{ padding: 10px 20px; text-decoration: none; background: #4285f4; color: white; border-radius: 5px; }}
            </style>
        </head>
        <body>
            <h1>User Profile</h1>
            <p><a href="/" class="btn">Back to Home</a></p>

            <h2>Claims from Identity Token</h2>
            <table>
                <tr><th>Claim Type</th><th>Value</th></tr>
                {string.Join("\n", claims.Select(c => $"<tr><td>{c.Type}</td><td>{c.Value}</td></tr>"))}
            </table>
        </body>
        </html>
        """;

    return Results.Content(html, "text/html");
}).RequireAuthorization();

// 토큰 정보 확인 (인증 필요)
app.MapGet("/tokens", async (HttpContext context) =>
{
    // 저장된 토큰 가져오기
    var accessToken = await context.GetTokenAsync("access_token");
    var refreshToken = await context.GetTokenAsync("refresh_token");
    var tokenType = await context.GetTokenAsync("token_type");
    var expiresAt = await context.GetTokenAsync("expires_at");

    // 보안: 토큰의 일부만 표시
    var maskedAccessToken = accessToken?.Length > 20
        ? $"{accessToken[..10]}...{accessToken[^10..]}"
        : accessToken ?? "N/A";

    var html = $"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Tokens - OAuth Demo</title>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }}
                .token-box {{ background: #282c34; color: #abb2bf; padding: 15px; border-radius: 5px; margin: 10px 0; word-break: break-all; }}
                .warning {{ background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; }}
                .btn {{ padding: 10px 20px; text-decoration: none; background: #4285f4; color: white; border-radius: 5px; }}
            </style>
        </head>
        <body>
            <h1>OAuth Tokens</h1>
            <p><a href="/" class="btn">Back to Home</a></p>

            <div class="warning">
                <strong>Security Note:</strong> Never expose full tokens in production!
                This page is for learning purposes only.
            </div>

            <h3>Access Token (masked)</h3>
            <div class="token-box">{maskedAccessToken}</div>

            <h3>Token Type</h3>
            <div class="token-box">{tokenType ?? "N/A"}</div>

            <h3>Expires At</h3>
            <div class="token-box">{expiresAt ?? "N/A"}</div>

            <h3>Refresh Token</h3>
            <div class="token-box">{(refreshToken != null ? "Present (hidden)" : "Not provided by Google")}</div>

            <h2>What can you do with these tokens?</h2>
            <ul>
                <li><strong>Access Token:</strong> Call Google APIs on behalf of the user</li>
                <li><strong>Refresh Token:</strong> Get a new access token when it expires</li>
            </ul>
        </body>
        </html>
        """;

    return Results.Content(html, "text/html");
}).RequireAuthorization();

// 접근 거부 페이지
app.MapGet("/access-denied", () =>
{
    return Results.Content("""
        <!DOCTYPE html>
        <html>
        <head><title>Access Denied</title></head>
        <body>
            <h1>Access Denied</h1>
            <p>You don't have permission to access this resource.</p>
            <a href="/">Go Home</a>
        </body>
        </html>
        """, "text/html");
});

app.Run();
