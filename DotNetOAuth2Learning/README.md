# .NET OAuth 2.0 학습 가이드

## 학습 목표
이 프로젝트를 통해 OAuth 2.0의 핵심 개념과 .NET에서의 구현 방법을 배웁니다.

## 학습 순서

### Phase 1: OAuth 2.0 기초 이론 (docs 폴더)
1. `docs/01-OAuth2-Basics.md` - OAuth 2.0 기본 개념
2. `docs/02-Grant-Types.md` - Grant Types 상세 설명
3. `docs/03-Security-Best-Practices.md` - 보안 모범 사례

### Phase 2: 실습 예제 (src 폴더)
1. `01-AuthorizationCodeFlow` - 웹 애플리케이션용 표준 플로우
2. `02-ClientCredentialsFlow` - 서버 간 통신용 플로우
3. `03-JwtValidation` - JWT 토큰 검증 및 처리

## 프로젝트 구조
```
DotNetOAuth2Learning/
├── README.md                    # 이 파일
├── docs/                        # 이론 학습 자료
│   ├── 01-OAuth2-Basics.md
│   ├── 02-Grant-Types.md
│   └── 03-Security-Best-Practices.md
└── src/                         # 실습 코드
    ├── 01-AuthorizationCodeFlow/
    ├── 02-ClientCredentialsFlow/
    └── 03-JwtValidation/
```

## 필수 사전 지식
- C# 기초
- ASP.NET Core 기본 개념
- HTTP 프로토콜 이해

## 개발 환경
- .NET 8.0 SDK
- Visual Studio 2022 또는 VS Code
- Postman (API 테스트용)

## 시작하기
각 예제 폴더로 이동하여 README를 따라 진행하세요.
