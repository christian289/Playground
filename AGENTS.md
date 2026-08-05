# Playground Monorepo

This is a monorepo containing multiple independent projects. Each subdirectory represents a separate project with its own purpose, dependencies, and configuration.

## Structure

- Each folder in the root is an independent project
- Projects may use different languages, frameworks, and tools
- Check each project's README or documentation for specific setup instructions
- New experiments / demos / samples → create a new top-level folder, do not nest inside an existing project
- Don't add cross-project references between top-level folders unless explicitly requested

## Working with Projects

When working in this repository:
1. Navigate to the specific project folder
2. Follow that project's individual setup and development guidelines
3. Each project manages its own dependencies independently
4. Read the project's own `AGENTS.md` / `README.md` before working in it — patterns differ per project (e.g., `WpfOnnxWinUI3Demo` requires Visual Studio MSBuild, not `dotnet build`)

## Owner Preferences

The repo owner is a Windows desktop developer whose primary stack is **WPF**. Frame proposals around WPF first; introduce non-WPF stacks only when there's a concrete reason WPF cannot meet the requirement.

### WPF vs WinUI 3 — default choice

When a task calls for a "modern Windows desktop app", "WinUI 3 style", or "Fluent design" UI, the default answer is **WPF + [WPF-UI](https://github.com/lepoco/wpfui)** (a pure-WPF reimplementation of the WinUI 3 look) — **not** actual WinUI 3 / XAML Islands.

**Reasoning:**
- WPF-UI delivers Fluent appearance, theme switching, and Mica/Acrylic without the Windows App SDK runtime dependency, MSBuild quirks, x64-only constraint, or the airspace problem inherent to XAML Islands.
- Hybrid (WPF-UI base + Islands for missing controls) sounds clean in theory but in practice loses WPF-UI's deployment simplicity and introduces theme-sync / airspace headaches.

**When to deviate (use actual WinUI 3 / XAML Islands / Windows App SDK):**
Only when the task genuinely requires a Windows-native control or API that WPF + WPF-UI cannot deliver — e.g., `WebView2` (consider the standalone `Microsoft.Web.WebView2.Wpf` package first), `MediaPlayerElement`, `MapControl`, `AppNotifications` UI, Windows AI Foundry, or other Windows App SDK-only features.

**When deviating, isolate the work in a separate top-level project** rather than mixing it into a WPF app. The existing `WpfOnnxWinUI3Demo` is the template for this isolation pattern (it exists because ONNX + DirectML specifically needed Windows App SDK) — do not propagate the XAML Islands pattern into other projects without a similar concrete need.

### .NET solution file format

For new .NET solutions in this repo, use **`.slnx`** (the new XML-based solution format), not the legacy `.sln`. `.slnx` produces cleaner git diffs and is supported by Visual Studio 17.10+ and modern `dotnet` CLI. Do not migrate existing `.sln` files unless asked.
