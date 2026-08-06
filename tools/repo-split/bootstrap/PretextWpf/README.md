# PretextWpf

[pretext](https://github.com/chenglou/pretext)(TypeScript 텍스트 레이아웃 엔진)를
WPF로 포팅한 라이브러리와, 그 위에 올린 데모 앱.

## 구성

| 프로젝트 | 역할 |
|---|---|
| `src/Pretext.Wpf` | 레이아웃 엔진 본체. 유니코드 분석·워드 세그먼트·bidi·측정·줄바꿈 |
| `src/Pretext.Wpf.Demo` | pretext.cool의 Pretext Playground를 WPF로 재현한 데모 |
| `tests/Pretext.Wpf.Tests` | 단위 테스트 + 상류 엔진과의 차분(parity) 테스트 |
| `benchmarks/Pretext.Wpf.Benchmarks` | 레이아웃 벤치마크 |
| `tools/parity` | 상류 엔진을 결정적 fake canvas 위에서 돌려 기대값 코퍼스를 생성 |

## 요구 사항

- .NET 10 SDK
- Windows (WPF 텍스트 측정 API에 의존)

## 빌드와 테스트

```
dotnet build PretextWpf.slnx
dotnet test tests/Pretext.Wpf.Tests/Pretext.Wpf.Tests.csproj
```

## 출처와 라이선스

이식·참조한 상류 코드의 커밋 해시와 파일별 대응은 `upstream-manifest.json`에
기록되어 있다. 상류 라이선스 전문은 `LICENSE-PRETEXT`(chenglou/pretext)와
`LICENSE-WPF-SAMPLES`(microsoft/WPF-Samples)에 있다.

데모 앱이 재현한 Pretext Playground는 0xNyk의 커뮤니티 쇼케이스다.
원본 저장소가 비공개로 전환되어 배포된 번들을 캡처해 참조했으며,
경위는 `upstream-manifest.json`의 두 번째 소스 항목에 적혀 있다.
