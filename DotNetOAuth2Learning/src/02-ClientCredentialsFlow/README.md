# Client Credentials Flow 예제

## 개요
서버 간 통신(Machine-to-Machine)을 위한 Client Credentials Flow를 구현합니다.
이 예제는 두 개의 프로젝트로 구성됩니다:

1. **ApiServer**: 보호된 API 서버 (Resource Server)
2. **ApiClient**: API를 호출하는 클라이언트 (Console App)

## 시나리오
- ApiClient가 자체 자격 증명(Client ID/Secret)으로 토큰을 얻습니다
- 받은 토큰으로 ApiServer의 보호된 엔드포인트에 접근합니다
- 사용자 컨텍스트 없이 서버 간 직접 통신합니다

## 프로젝트 생성

```bash
# API 서버 생성
dotnet new webapi -n ApiServer
cd ApiServer
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer

# API 클라이언트 생성 (다른 터미널)
dotnet new console -n ApiClient
cd ApiClient
dotnet add package System.IdentityModel.Tokens.Jwt
```

## 실행 방법

```bash
# 터미널 1: API 서버 실행
cd ApiServer
dotnet run

# 터미널 2: 클라이언트 실행
cd ApiClient
dotnet run
```

## 학습 포인트

1. **자체 토큰 발급**: 간단한 토큰 엔드포인트 구현
2. **JWT 생성**: `System.IdentityModel.Tokens.Jwt` 사용
3. **JWT 검증**: `AddJwtBearer()` 미들웨어
4. **HttpClient 토큰 주입**: Authorization 헤더 설정
