# WinAppCliOcr Project

## Overview
Windows OCR application built with WPF and Windows.Media.Ocr API, using winapp CLI for development workflow and Velopack for deployment.

## Tech Stack
- .NET 10, WPF, Windows SDK 10.0.26100.0
- Windows.Media.Ocr (Windows built-in OCR engine)
- Velopack 0.0.1298 (installer & auto-updates)
- winapp CLI (debug identity for Package Identity APIs)

## Project Structure
```
WinAppCliOcr/
├── WinAppCliOcr.csproj       # Main WPF project (SingleFile, SelfContained)
├── WinAppCliOcr.slnx         # Solution file
├── App.xaml(.cs)             # App entry with Velopack bootstrap
├── MainWindow.xaml(.cs)      # UI and OCR logic
├── appxmanifest.xml          # Package manifest for winapp CLI
├── build.ps1                 # Build/publish/package script
├── publish/                  # dotnet publish output
└── releases/                 # Velopack installer output
    ├── WinAppCliOcr-win-Setup.exe
    ├── WinAppCliOcr-win-Portable.zip
    └── WinAppCliOcr-{version}-full.nupkg
```

## Build Configuration (csproj)
```xml
<TargetFramework>net10.0-windows10.0.26100.0</TargetFramework>
<RuntimeIdentifier>win-x64</RuntimeIdentifier>
<DebugType>embedded</DebugType>           <!-- PDB in exe -->
<PublishSingleFile>true</PublishSingleFile>
<SelfContained>true</SelfContained>
<EnableCompressionInSingleFile>true</EnableCompressionInSingleFile>
```

## Build Commands
```powershell
# Debug build
dotnet build -c Debug

# Release publish
dotnet publish -c Release -o publish

# Create Velopack package
vpk pack --packId WinAppCliOcr --packVersion 1.0.0 --packDir publish --mainExe WinAppCliOcr.exe --outputDir releases

# All-in-one script
.\build.ps1 -Package -Version "1.0.0"
```

## Velopack Deployment
- **Setup.exe**: One-click installer (~74MB)
- **Portable.zip**: Extract and run (~72MB)
- **full.nupkg**: Delta update package
- Install path: `%LocalAppData%\WinAppCliOcr`
- Start Menu shortcut auto-created

## Key Implementation
- `App.xaml.cs`: `VelopackApp.Build().Run()` bootstrap
- `MainWindow.xaml.cs`: OCR logic using `Windows.Media.Ocr.OcrEngine`
- Namespace alias for WinRT types: `using WinRTBitmapDecoder = Windows.Graphics.Imaging.BitmapDecoder`

## Adding Auto-Update
```csharp
var mgr = new UpdateManager("https://your-server/releases");
var newVersion = await mgr.CheckForUpdatesAsync();
if (newVersion != null) {
    await mgr.DownloadUpdatesAsync(newVersion);
    mgr.ApplyUpdatesAndRestart(newVersion);
}
```

## Dependencies
- Velopack (NuGet): Auto-update framework
- Windows.Media.Ocr: Built-in Windows API (no NuGet needed)
- vpk CLI: `dotnet tool install -g vpk`
