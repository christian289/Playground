using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;

Console.WriteLine("=".PadRight(60, '='));
Console.WriteLine("  JWT (JSON Web Token) Demo");
Console.WriteLine("=".PadRight(60, '='));
Console.WriteLine();

// ============================================================
// Part 1: JWT 구조 이해
// ============================================================
Console.WriteLine("[ Part 1: JWT Structure ]");
Console.WriteLine("-".PadRight(60, '-'));
Console.WriteLine();
Console.WriteLine("JWT consists of three parts separated by dots (.):");
Console.WriteLine("  1. Header   - Algorithm and token type");
Console.WriteLine("  2. Payload  - Claims (data)");
Console.WriteLine("  3. Signature - Verification signature");
Console.WriteLine();

// ============================================================
// Part 2: 대칭 키(HMAC)로 JWT 생성
// ============================================================
Console.WriteLine("[ Part 2: Creating JWT with Symmetric Key (HS256) ]");
Console.WriteLine("-".PadRight(60, '-'));
Console.WriteLine();

var secretKey = "ThisIsASecretKeyForHMACSHA256Algorithm!";
var symmetricKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
var signingCredentials = new SigningCredentials(symmetricKey, SecurityAlgorithms.HmacSha256);

// Claims 정의
var claims = new List<Claim>
{
    // 표준 Claims (Registered Claims)
    new(JwtRegisteredClaimNames.Sub, "user123"),        // Subject
    new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()), // JWT ID
    new(JwtRegisteredClaimNames.Iat, DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64), // Issued At

    // 공개 Claims (Public Claims)
    new(ClaimTypes.Name, "John Doe"),
    new(ClaimTypes.Email, "john@example.com"),
    new(ClaimTypes.Role, "Admin"),
    new(ClaimTypes.Role, "User"),  // 여러 역할 가능

    // 비공개 Claims (Private Claims)
    new("department", "Engineering"),
    new("employee_id", "EMP001"),
    new("permissions", "read,write,delete")
};

var tokenDescriptor = new SecurityTokenDescriptor
{
    Subject = new ClaimsIdentity(claims),
    Issuer = "https://myauth.example.com",
    Audience = "https://myapi.example.com",
    Expires = DateTime.UtcNow.AddHours(1),
    NotBefore = DateTime.UtcNow,
    SigningCredentials = signingCredentials
};

var tokenHandler = new JwtSecurityTokenHandler();
var token = tokenHandler.CreateToken(tokenDescriptor);
var tokenString = tokenHandler.WriteToken(token);

Console.WriteLine("Generated JWT:");
Console.WriteLine(tokenString);
Console.WriteLine();

// 토큰 분해
var parts = tokenString.Split('.');
Console.WriteLine("Token Parts:");
Console.WriteLine($"  Header (Base64):    {parts[0]}");
Console.WriteLine($"  Payload (Base64):   {parts[1]}");
Console.WriteLine($"  Signature (Base64): {parts[2]}");
Console.WriteLine();

// Base64 디코딩
Console.WriteLine("Decoded Header:");
var headerJson = Encoding.UTF8.GetString(Base64UrlDecode(parts[0]));
Console.WriteLine($"  {headerJson}");
Console.WriteLine();

Console.WriteLine("Decoded Payload:");
var payloadJson = Encoding.UTF8.GetString(Base64UrlDecode(parts[1]));
Console.WriteLine($"  {payloadJson}");
Console.WriteLine();

// ============================================================
// Part 3: JWT 검증
// ============================================================
Console.WriteLine("[ Part 3: Validating JWT ]");
Console.WriteLine("-".PadRight(60, '-'));
Console.WriteLine();

var validationParameters = new TokenValidationParameters
{
    // 서명 검증
    ValidateIssuerSigningKey = true,
    IssuerSigningKey = symmetricKey,

    // 발급자 검증
    ValidateIssuer = true,
    ValidIssuer = "https://myauth.example.com",

    // 대상 검증
    ValidateAudience = true,
    ValidAudience = "https://myapi.example.com",

    // 만료 시간 검증
    ValidateLifetime = true,
    ClockSkew = TimeSpan.FromMinutes(1), // 시간 오차 허용

    // 알고리즘 제한 (보안 강화)
    ValidAlgorithms = new[] { SecurityAlgorithms.HmacSha256 }
};

try
{
    var principal = tokenHandler.ValidateToken(tokenString, validationParameters, out var validatedToken);

    Console.WriteLine("Token is VALID!");
    Console.WriteLine();
    Console.WriteLine("Extracted Claims:");

    foreach (var claim in principal.Claims)
    {
        Console.WriteLine($"  {claim.Type}: {claim.Value}");
    }
    Console.WriteLine();

    // 특정 클레임 접근
    Console.WriteLine("Accessing Specific Claims:");
    Console.WriteLine($"  Name: {principal.Identity?.Name}");
    Console.WriteLine($"  Email: {principal.FindFirst(ClaimTypes.Email)?.Value}");
    Console.WriteLine($"  Is Admin: {principal.IsInRole("Admin")}");
    Console.WriteLine($"  Is Guest: {principal.IsInRole("Guest")}");
    Console.WriteLine();
}
catch (SecurityTokenValidationException ex)
{
    Console.WriteLine($"Token validation failed: {ex.Message}");
}

// ============================================================
// Part 4: 검증 실패 시나리오
// ============================================================
Console.WriteLine("[ Part 4: Validation Failure Scenarios ]");
Console.WriteLine("-".PadRight(60, '-'));
Console.WriteLine();

// 시나리오 1: 잘못된 서명
Console.WriteLine("Scenario 1: Wrong signing key");
try
{
    var wrongKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("WrongKeyHere12345678901234567890"));
    var wrongParams = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = wrongKey,
        ValidateIssuer = false,
        ValidateAudience = false
    };
    tokenHandler.ValidateToken(tokenString, wrongParams, out _);
    Console.WriteLine("  Result: PASSED (unexpected!)");
}
catch (SecurityTokenInvalidSignatureException)
{
    Console.WriteLine("  Result: FAILED - Invalid signature (expected)");
}
Console.WriteLine();

// 시나리오 2: 만료된 토큰
Console.WriteLine("Scenario 2: Expired token");
var expiredToken = CreateExpiredToken(symmetricKey);
try
{
    tokenHandler.ValidateToken(expiredToken, validationParameters, out _);
    Console.WriteLine("  Result: PASSED (unexpected!)");
}
catch (SecurityTokenExpiredException)
{
    Console.WriteLine("  Result: FAILED - Token expired (expected)");
}
Console.WriteLine();

// 시나리오 3: 잘못된 발급자
Console.WriteLine("Scenario 3: Wrong issuer");
try
{
    var wrongIssuerParams = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = symmetricKey,
        ValidateIssuer = true,
        ValidIssuer = "https://different-issuer.com",
        ValidateAudience = false,
        ValidateLifetime = false
    };
    tokenHandler.ValidateToken(tokenString, wrongIssuerParams, out _);
    Console.WriteLine("  Result: PASSED (unexpected!)");
}
catch (SecurityTokenInvalidIssuerException)
{
    Console.WriteLine("  Result: FAILED - Invalid issuer (expected)");
}
Console.WriteLine();

// ============================================================
// Part 5: 비대칭 키(RSA)로 JWT 생성 및 검증
// ============================================================
Console.WriteLine("[ Part 5: Creating JWT with Asymmetric Key (RS256) ]");
Console.WriteLine("-".PadRight(60, '-'));
Console.WriteLine();

using var rsa = RSA.Create(2048);
var rsaPrivateKey = new RsaSecurityKey(rsa.ExportParameters(true));
var rsaPublicKey = new RsaSecurityKey(rsa.ExportParameters(false));

var rsaSigningCredentials = new SigningCredentials(rsaPrivateKey, SecurityAlgorithms.RsaSha256);

var rsaToken = tokenHandler.CreateToken(new SecurityTokenDescriptor
{
    Subject = new ClaimsIdentity(new[]
    {
        new Claim(JwtRegisteredClaimNames.Sub, "user456"),
        new Claim("name", "Jane Doe")
    }),
    Issuer = "https://myauth.example.com",
    Audience = "https://myapi.example.com",
    Expires = DateTime.UtcNow.AddHours(1),
    SigningCredentials = rsaSigningCredentials
});

var rsaTokenString = tokenHandler.WriteToken(rsaToken);
Console.WriteLine($"RSA-signed JWT: {rsaTokenString[..50]}...");
Console.WriteLine();

// 공개 키로만 검증 가능
var rsaValidationParams = new TokenValidationParameters
{
    ValidateIssuerSigningKey = true,
    IssuerSigningKey = rsaPublicKey,  // 공개 키만 필요
    ValidateIssuer = true,
    ValidIssuer = "https://myauth.example.com",
    ValidateAudience = true,
    ValidAudience = "https://myapi.example.com",
    ValidateLifetime = true
};

try
{
    var rsaPrincipal = tokenHandler.ValidateToken(rsaTokenString, rsaValidationParams, out _);
    Console.WriteLine("RSA Token validated with PUBLIC key only!");
    Console.WriteLine($"  Subject: {rsaPrincipal.FindFirst(JwtRegisteredClaimNames.Sub)?.Value}");
}
catch (Exception ex)
{
    Console.WriteLine($"Validation failed: {ex.Message}");
}
Console.WriteLine();

// ============================================================
// Part 6: 보안 권장사항
// ============================================================
Console.WriteLine("[ Part 6: Security Best Practices ]");
Console.WriteLine("-".PadRight(60, '-'));
Console.WriteLine();
Console.WriteLine("1. Always validate the signature");
Console.WriteLine("2. Check expiration (exp) and not-before (nbf) claims");
Console.WriteLine("3. Validate issuer (iss) and audience (aud)");
Console.WriteLine("4. Use strong signing keys (256+ bits for HMAC)");
Console.WriteLine("5. Prefer RS256 over HS256 for distributed systems");
Console.WriteLine("6. Never store sensitive data in JWT payload");
Console.WriteLine("7. Implement token revocation for logout");
Console.WriteLine("8. Use short expiration times with refresh tokens");
Console.WriteLine("9. Restrict accepted algorithms (prevent 'none' algorithm)");
Console.WriteLine("10. Store tokens securely (HttpOnly cookies, not localStorage)");
Console.WriteLine();

Console.WriteLine("=".PadRight(60, '='));
Console.WriteLine("  Demo Complete!");
Console.WriteLine("=".PadRight(60, '='));

// ============================================================
// Helper Methods
// ============================================================

static byte[] Base64UrlDecode(string input)
{
    var output = input
        .Replace('-', '+')
        .Replace('_', '/');

    switch (output.Length % 4)
    {
        case 2: output += "=="; break;
        case 3: output += "="; break;
    }

    return Convert.FromBase64String(output);
}

static string CreateExpiredToken(SecurityKey key)
{
    var handler = new JwtSecurityTokenHandler();
    var token = handler.CreateToken(new SecurityTokenDescriptor
    {
        Subject = new ClaimsIdentity(new[] { new Claim("sub", "expired-user") }),
        Issuer = "https://myauth.example.com",
        Audience = "https://myapi.example.com",
        Expires = DateTime.UtcNow.AddSeconds(-10),  // 이미 만료됨
        NotBefore = DateTime.UtcNow.AddHours(-1),
        SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256)
    });
    return handler.WriteToken(token);
}
