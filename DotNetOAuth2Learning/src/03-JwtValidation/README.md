# JWT 토큰 검증 예제

## 개요
JWT(JSON Web Token)의 구조를 이해하고 검증하는 방법을 학습합니다.

## 학습 내용

1. **JWT 구조**: Header, Payload, Signature
2. **토큰 생성**: 서명 알고리즘과 Claims
3. **토큰 검증**: 서명, 만료, 발급자 등 검증
4. **보안 고려사항**: 알고리즘 혼동 공격 방지

## 프로젝트 생성

```bash
dotnet new console -n JwtDemo
cd JwtDemo
dotnet add package System.IdentityModel.Tokens.Jwt
dotnet add package Microsoft.IdentityModel.Tokens
```

## 실행

```bash
dotnet run
```

## JWT 구조

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.  <- Header (Base64)
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4ifQ.  <- Payload (Base64)
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c  <- Signature
```

## 학습 포인트

1. **대칭 키 서명**: HMAC-SHA256 (HS256)
2. **비대칭 키 서명**: RSA-SHA256 (RS256)
3. **Claims 검증**: iss, aud, exp, nbf, sub
4. **Custom Claims**: 비즈니스 로직용 클레임
