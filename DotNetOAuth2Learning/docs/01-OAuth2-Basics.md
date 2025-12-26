# OAuth 2.0 기본 개념

## OAuth 2.0이란?

OAuth 2.0은 **권한 위임(Authorization Delegation)** 을 위한 산업 표준 프로토콜입니다.
사용자가 자신의 자격 증명(비밀번호)을 공유하지 않고도 제3자 애플리케이션에 제한된 접근 권한을 부여할 수 있게 합니다.

## 핵심 용어

### 1. Resource Owner (리소스 소유자)
- 보호된 리소스에 대한 접근 권한을 부여할 수 있는 주체
- 일반적으로 **최종 사용자(End User)**

### 2. Client (클라이언트)
- 리소스 소유자를 대신하여 보호된 리소스에 접근하는 애플리케이션
- 예: 웹 앱, 모바일 앱, 데스크톱 앱

### 3. Authorization Server (인가 서버)
- 리소스 소유자를 인증하고 권한을 부여한 후 Access Token을 발급
- 예: Azure AD, Auth0, Keycloak, IdentityServer

### 4. Resource Server (리소스 서버)
- 보호된 리소스를 호스팅하는 서버
- Access Token을 검증하여 요청을 수락/거부
- 예: API 서버

### 5. Access Token
- 보호된 리소스에 접근하기 위한 자격 증명
- 일반적으로 JWT(JSON Web Token) 형식
- 제한된 수명을 가짐

### 6. Refresh Token
- 새로운 Access Token을 얻기 위한 자격 증명
- Access Token보다 긴 수명
- 안전하게 저장해야 함

## OAuth 2.0 플로우 개요

```
+--------+                               +---------------+
|        |--(1)-- Authorization Request ->|   Resource    |
|        |                               |     Owner     |
|        |<-(2)-- Authorization Grant ---|               |
|        |                               +---------------+
|        |
|        |                               +---------------+
|        |--(3)-- Authorization Grant -->| Authorization |
| Client |                               |     Server    |
|        |<-(4)-- Access Token ----------|               |
|        |                               +---------------+
|        |
|        |                               +---------------+
|        |--(5)-- Access Token --------->|    Resource   |
|        |                               |     Server    |
|        |<-(6)-- Protected Resource ----|               |
+--------+                               +---------------+
```

## OAuth 2.0 vs OpenID Connect (OIDC)

| 구분 | OAuth 2.0 | OpenID Connect |
|------|-----------|----------------|
| 목적 | 권한 부여 (Authorization) | 인증 (Authentication) |
| 토큰 | Access Token | ID Token + Access Token |
| 용도 | API 접근 권한 | 사용자 신원 확인 |

**OIDC는 OAuth 2.0 위에 구축된 인증 레이어입니다.**

## .NET에서의 OAuth 2.0

### 주요 NuGet 패키지

```xml
<!-- 인증/인가 기본 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" />

<!-- OpenID Connect 클라이언트 -->
<PackageReference Include="Microsoft.AspNetCore.Authentication.OpenIdConnect" />

<!-- IdentityServer (자체 인가 서버 구축) -->
<PackageReference Include="Duende.IdentityServer" />
```

### 간단한 JWT 인증 설정 예시

```csharp
// Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://your-auth-server.com";
        options.Audience = "your-api";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true
        };
    });

builder.Services.AddAuthorization();

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
```

## 학습 체크리스트

- [ ] OAuth 2.0의 목적을 설명할 수 있다
- [ ] 4가지 역할(Resource Owner, Client, Auth Server, Resource Server)을 구분할 수 있다
- [ ] Access Token과 Refresh Token의 차이를 이해한다
- [ ] OAuth 2.0과 OIDC의 차이를 설명할 수 있다

## 다음 단계
→ [02-Grant-Types.md](02-Grant-Types.md)에서 다양한 Grant Type에 대해 알아봅니다.
