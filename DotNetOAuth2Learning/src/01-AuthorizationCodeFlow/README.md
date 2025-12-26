# Authorization Code Flow 예제

## 개요
이 예제는 Google OAuth를 사용한 Authorization Code Flow를 구현합니다.

## 프로젝트 생성

```bash
# 프로젝트 생성
dotnet new web -n OAuthWebApp
cd OAuthWebApp

# 패키지 추가
dotnet add package Microsoft.AspNetCore.Authentication.Google
dotnet add package Microsoft.AspNetCore.Authentication.OpenIdConnect
```

## Google OAuth 설정

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. APIs & Services > Credentials 이동
4. Create Credentials > OAuth client ID 선택
5. Application type: Web application
6. Authorized redirect URIs: `https://localhost:5001/signin-google`
7. Client ID와 Client Secret 복사

## User Secrets 설정

```bash
dotnet user-secrets init
dotnet user-secrets set "Authentication:Google:ClientId" "your-client-id"
dotnet user-secrets set "Authentication:Google:ClientSecret" "your-client-secret"
```

## 실행

```bash
dotnet run
```

브라우저에서 `https://localhost:5001` 접속

## 학습 포인트

1. **인증 미들웨어 설정**: `AddAuthentication()`, `AddGoogle()`
2. **Challenge/SignIn/SignOut**: 인증 플로우 트리거
3. **Claims 읽기**: 사용자 정보 접근
4. **Cookie 인증**: 세션 유지
