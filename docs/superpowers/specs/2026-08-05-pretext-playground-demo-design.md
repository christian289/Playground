# Pretext Playground — WPF demo reproduction

**Date:** 2026-08-05
**Goal:** Replace the placeholder demo window in `PretextWpf/src/Pretext.Wpf.Demo` with a
faithful WPF reproduction of the community showcase deployed at
`https://www.pretext.cool/demos/pretext-playground/` (linked from
`/demo/pretext-playground/`). The `Pretext.Wpf` library itself is **not modified** —
its public API (`PrepareWithSegments`, `Layout`, `LayoutWithLines`, `WalkLineRanges`,
`MeasureNaturalWidth`, `PrepareOptions.WhiteSpace = PreWrap`) already covers every
pretext call the upstream demo makes.

## Upstream source of truth

The original GitHub repo (`github.com/0xNyk/pretext-playground`) is no longer public
(404). The deployed Vite bundle was captured and de-minified instead:

| Asset | Role |
|---|---|
| `index.html` / `ascii.html` | Two-tab shell: **Dragon**, **ASCII Animations** |
| `main-CaY02GpH.js` | Dragon page bootstrap + settings panel DOM |
| `dragon-JNptzR-R.js` | Dragon scene: config/presets, letter physics, fire, enemies, runes, tunnel, cursor |
| `ascii-CGAS80-L.js` | 5 ASCII scenes: Matrix Rain, Text Wave, Text Morph, Particle Text, Typewriter |
| `layout-B0URrYGj.js` | pretext library bundle — exports map `n`=prepare, `t`=layout(lines), `r`=walkLines |
| `shared-aeVaPDaJ.css` | Dark theme: `#0a0a0a` bg, orange `#f60`/`#ff8844` accent, 44px top nav, panel/slider/toggle styles |

Upstream pretext call sites map 1:1 onto `Pretext.Wpf`:

| Upstream (JS) | Pretext.Wpf |
|---|---|
| `prepare(text, font, {whiteSpace:'pre-wrap'}?)` | `TextLayoutEngine.PrepareWithSegments(text, style, new PrepareOptions(whiteSpace: …))` |
| `layout(prepared, maxWidth, lineHeight)` → `{lines, lineCount, height}` | `TextLayoutEngine.LayoutWithLines(prepared, maxWidth, lineHeight)` |
| `walk(prepared, maxWidth, cb)` (shrinkwrap) | `TextLayoutEngine.WalkLineRanges(prepared, maxWidth, visitor)` |
| `ctx.measureText(ch).width` (per-char placement) | demo-side `GlyphSheet.Advance` cache (FormattedText @ em 100, scaled) |

## Architecture (all inside Pretext.Wpf.Demo)

- **Shell** — `MainWindow` becomes the playground chrome: 44px top tab nav
  (`Dragon`, `ASCII Animations`, `Layout Lab`), lazily-created views in a
  `ContentControl`. `Layout Lab` keeps the previous width/letter-spacing smoke surface.
- **Rendering/GlyphSheet.cs** — per-`Typeface` cache: frozen `Geometry` per grapheme
  (built once at em 100 via `FormattedText.BuildGeometry`, scaled per draw) + advance
  widths + frozen `SolidColorBrush` cache by `Color`. This is the WPF stand-in for
  canvas `fillText`/`measureText`: transform-based, so per-glyph rotation/scale/alpha
  (dragon physics, burn, morph) stay cheap at the demo's 2 000-letter cap.
- **Playground/DragonConfig.cs** — the 19 tunables + 6 presets (Default, Gentle,
  Chaos, Zen, Tiny, Leviathan) as an observable object bound to the settings panel.
- **Playground/DragonSurface.cs** — `FrameworkElement` port of `dragon.js` on
  `CompositionTarget.Rendering`: SoA letter arrays, dragon chain follow, letter
  spring/push physics, click-and-hold fire (particles, embers, screen shake, letter
  ignition), enemies + score, floating runes, perspective text tunnel, custom cursor,
  fps/letters/particles stats, fading hint.
- **Playground/AsciiSurface.cs + Scenes/** — scene host + 5 `IAsciiScene` ports with
  scene tab buttons and per-scene hint.
- **Views/** — `DragonView` (surface + hint + ⚙ panel with sliders/toggles/presets,
  `P`/`Esc` keyboard), `AsciiView`, `LayoutLabView`.

## Known, accepted deviations from the web original

- Canvas persistence trails (`rgba(10,10,10,0.12)` overlay in Matrix Rain / Particle
  Text) don't exist in WPF retained rendering; Matrix Rain's explicit per-column fade
  already reads the same, Particle Text gets short ghost-position trails instead.
- Emoji render monochrome (WPF geometry/text has no COLR support here); `Inter`
  webfont → `Segoe UI`.
- Rendering is DIP-based; no devicePixelRatio handling needed.

## Testing

- Existing library/test suite untouched; must stay green.
- Demo verified by `dotnet build` (warnings-as-errors) and launching the app,
  checking every tab and scene visually.

## Provenance

`upstream-manifest.json` currently lists demo-gallery destinations that were never
created (accordion/bubbles/masonry…). Those stale entries are replaced by entries for
the real files above, sourced from the deployed pretext-playground bundle.
