# Upstream parity tooling

Two dev-only tools that keep the port honest. Neither ships with the library, and
neither is part of `PretextWpf.slnx`.

## Why

`Pretext.Wpf` is a port of [chenglou/pretext](https://github.com/chenglou/pretext)
(TypeScript, canvas measurement) to WPF. Hand-written unit tests prove the port is
*self-consistent*; they cannot prove it *breaks lines the same way upstream does*.
These tools close that gap by running both engines over the same corpus with the
same deterministic measurements and diffing the results.

## `generate.ts` — capture upstream behavior

```sh
cd PretextWpf/tools/parity
bun run generate.ts
```

Requires the upstream snapshot at `PretextWpf/.upstream/pretext` (clone the repo at
the commit pinned in `upstream-manifest.json`; the directory is gitignored).

It installs the deterministic fake canvas from upstream's own suite
(`fake-canvas.ts`, ported verbatim from `src/layout.test.ts`) and writes three
fixtures into `tests/Pretext.Wpf.Tests/TestData`:

| Fixture | Contents |
|---|---|
| `upstream-parity-corpus.json` | 380 cases: upstream's per-line text and width across its full corpus (Latin, Arabic, Hebrew, mixed bidi, CJK, Korean, Thai, emoji, edge cases) × 3 sizes × 4 widths, plus letter-spacing / keep-all / pre-wrap / soft-hyphen / ZWSP sweeps |
| `upstream-rich-corpus.json` | 28 cases: upstream's rich-inline fragments, gaps, occupied widths and stats across 7 scenarios × 4 widths |
| `native-word-dictionary.json` | ICU word boundaries for scriptio-continua runs (Thai) |

`UpstreamParityTests` replays all of it. Because both engines measure through the
same width function, any mismatch is a line-breaking divergence in the port.

### The dictionary fixture

Thai, Lao, Khmer and Myanmar have no visible word spacing, so break opportunities
come from a dictionary. Upstream gets them from `Intl.Segmenter`; `Pretext.Wpf` gets
them from WPF (`WpfTextMeasurer.GetNativeBreakOffsets`, which probes the real
formatter). Off Windows there is no WPF, so the fixture supplies ICU's boundaries and
`CanvasParityMeasurer` stands in for the dictionary. That keeps the engine-side split
path under test everywhere; only the formatter probe itself is Windows-only.

## `Parity/` — run the core suites off Windows

```sh
cd PretextWpf/tools/parity/Parity
dotnet run -c Release
```

`Pretext.Wpf.Tests` targets `net10.0-windows`, so it needs the
`Microsoft.WindowsDesktop.App` runtime and cannot execute on macOS or Linux. This
runner compiles the platform-independent core sources plus the WPF-free suites
(`TextAnalyzerTests`, `BidiLevelResolverTests`, `UpstreamParityTests`) against
minimal shims in `WpfShims.cs`, and executes them reflectively.

It excludes and stubs exactly the device-dependent files — `WpfTextMeasurer`,
`PretextTextRunProperties`, `PlainTextSource` — so everything it does exercise is the
real shipping code. Measurement-dependent suites (`WpfTextMeasurerTests`, the WPF
oracle tests, anything constructing real `Typeface`s) only run on Windows via
`dotnet test`.

Keep this runner's suite list in sync when adding platform-independent test files.
