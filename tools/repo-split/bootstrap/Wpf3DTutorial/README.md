# Wpf3DTutorial

WPF `Viewport3D`로 3D 씬을 구성하고 마우스로 조작하는 튜토리얼 앱.

## 조작

| 입력 | 동작 |
|---|---|
| 좌클릭 드래그 | 궤도 회전 |
| 우클릭 드래그 | 패닝 |
| 휠 | 확대/축소 |
| 「자동 회전」 토글 | 카메라 자동 회전 |

## 요구 사항

- .NET 10 SDK (`net10.0-windows`)
- Windows

## 실행

```
dotnet run --project src/Wpf3DTutorial/Wpf3DTutorial.csproj
```

## 다루는 내용

`PerspectiveCamera` 배치, `MeshGeometry3D` 구성, 조명 설정, 마우스 입력을 카메라
변환으로 옮기는 방법.
