using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

Console.WriteLine("=".PadRight(60, '='));
Console.WriteLine("  Client Credentials Flow Demo");
Console.WriteLine("=".PadRight(60, '='));
Console.WriteLine();

// ============================================================
// 설정
// ============================================================
var tokenEndpoint = "http://localhost:5001/oauth/token";
var apiEndpoint = "http://localhost:5001/api/data";
var clientId = "service-client-1";
var clientSecret = "secret123";
var scope = "read:data write:data";

using var httpClient = new HttpClient();

try
{
    // ============================================================
    // Step 1: Access Token 요청
    // ============================================================
    Console.WriteLine("[Step 1] Requesting Access Token...");
    Console.WriteLine($"  Token Endpoint: {tokenEndpoint}");
    Console.WriteLine($"  Client ID: {clientId}");
    Console.WriteLine($"  Scope: {scope}");
    Console.WriteLine();

    var tokenRequest = new FormUrlEncodedContent(new Dictionary<string, string>
    {
        ["grant_type"] = "client_credentials",
        ["client_id"] = clientId,
        ["client_secret"] = clientSecret,
        ["scope"] = scope
    });

    var tokenResponse = await httpClient.PostAsync(tokenEndpoint, tokenRequest);

    if (!tokenResponse.IsSuccessStatusCode)
    {
        Console.WriteLine($"[Error] Token request failed: {tokenResponse.StatusCode}");
        var errorContent = await tokenResponse.Content.ReadAsStringAsync();
        Console.WriteLine($"  Response: {errorContent}");
        return;
    }

    var tokenResult = await tokenResponse.Content.ReadFromJsonAsync<TokenResponse>();
    Console.WriteLine("[Success] Access Token received!");
    Console.WriteLine($"  Token Type: {tokenResult?.TokenType}");
    Console.WriteLine($"  Expires In: {tokenResult?.ExpiresIn} seconds");
    Console.WriteLine($"  Scope: {tokenResult?.Scope}");
    Console.WriteLine();

    // ============================================================
    // Step 2: JWT 토큰 분석 (학습용)
    // ============================================================
    Console.WriteLine("[Step 2] Analyzing JWT Token...");

    var jwtHandler = new JwtSecurityTokenHandler();
    var jwt = jwtHandler.ReadJwtToken(tokenResult?.AccessToken);

    Console.WriteLine($"  Issuer: {jwt.Issuer}");
    Console.WriteLine($"  Audience: {string.Join(", ", jwt.Audiences)}");
    Console.WriteLine($"  Valid From: {jwt.ValidFrom:yyyy-MM-dd HH:mm:ss} UTC");
    Console.WriteLine($"  Valid To: {jwt.ValidTo:yyyy-MM-dd HH:mm:ss} UTC");
    Console.WriteLine("  Claims:");
    foreach (var claim in jwt.Claims)
    {
        Console.WriteLine($"    - {claim.Type}: {claim.Value}");
    }
    Console.WriteLine();

    // ============================================================
    // Step 3: 보호된 API 호출
    // ============================================================
    Console.WriteLine("[Step 3] Calling Protected API...");
    Console.WriteLine($"  Endpoint: {apiEndpoint}");

    // Authorization 헤더에 Bearer 토큰 설정
    httpClient.DefaultRequestHeaders.Authorization =
        new AuthenticationHeaderValue("Bearer", tokenResult?.AccessToken);

    var apiResponse = await httpClient.GetAsync(apiEndpoint);

    if (!apiResponse.IsSuccessStatusCode)
    {
        Console.WriteLine($"[Error] API call failed: {apiResponse.StatusCode}");
        return;
    }

    var apiResult = await apiResponse.Content.ReadAsStringAsync();
    var formatted = JsonSerializer.Serialize(
        JsonSerializer.Deserialize<JsonElement>(apiResult),
        new JsonSerializerOptions { WriteIndented = true });

    Console.WriteLine("[Success] API Response:");
    Console.WriteLine(formatted);
    Console.WriteLine();

    // ============================================================
    // Step 4: 토큰 없이 API 호출 시도 (실패 예상)
    // ============================================================
    Console.WriteLine("[Step 4] Testing without token (should fail)...");

    using var noAuthClient = new HttpClient();
    var unauthorizedResponse = await noAuthClient.GetAsync(apiEndpoint);

    Console.WriteLine($"  Status: {(int)unauthorizedResponse.StatusCode} {unauthorizedResponse.StatusCode}");
    Console.WriteLine("  Expected: 401 Unauthorized");
    Console.WriteLine();

    // ============================================================
    // Step 5: 토큰 갱신 시뮬레이션
    // ============================================================
    Console.WriteLine("[Step 5] Token Refresh Simulation...");
    Console.WriteLine("  In a real application, you would:");
    Console.WriteLine("  1. Check if token is about to expire");
    Console.WriteLine("  2. Request a new token before expiration");
    Console.WriteLine("  3. Cache the token to avoid unnecessary requests");
    Console.WriteLine();

    // 만료까지 남은 시간 계산
    var timeToExpiry = jwt.ValidTo - DateTime.UtcNow;
    Console.WriteLine($"  Current token expires in: {timeToExpiry.TotalMinutes:F1} minutes");
    Console.WriteLine();

    Console.WriteLine("=".PadRight(60, '='));
    Console.WriteLine("  Demo Complete!");
    Console.WriteLine("=".PadRight(60, '='));
}
catch (HttpRequestException ex)
{
    Console.WriteLine($"[Error] Connection failed: {ex.Message}");
    Console.WriteLine("  Make sure the API server is running on http://localhost:5001");
}
catch (Exception ex)
{
    Console.WriteLine($"[Error] Unexpected error: {ex.Message}");
}

// ============================================================
// DTO
// ============================================================
record TokenResponse
{
    public string? AccessToken { get; init; }
    public string? TokenType { get; init; }
    public int ExpiresIn { get; init; }
    public string? Scope { get; init; }
}
