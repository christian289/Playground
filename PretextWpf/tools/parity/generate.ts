// Regenerates the upstream parity fixtures consumed by Pretext.Wpf.Tests.
//
//   cd PretextWpf/tools/parity && bun run generate.ts
//
// Requires the upstream snapshot at PretextWpf/.upstream/pretext (clone the repo and
// commit pinned in upstream-manifest.json). Writes three fixtures into
// tests/Pretext.Wpf.Tests/TestData:
//   upstream-parity-corpus.json  — per-case line text/width from upstream's engine
//   upstream-rich-corpus.json    — per-line rich-inline fragments from upstream's engine
//   native-word-dictionary.json  — ICU word boundaries for scriptio-continua runs,
//                                  standing in for WPF's line-breaking dictionary offline
import {
  layoutWithLines,
  prepareWithSegments,
  type PrepareOptions,
} from '../../.upstream/pretext/src/layout.js'
import {
  materializeRichInlineLineRange,
  measureRichInlineStats,
  prepareRichInline,
  walkRichInlineLineRanges,
  type RichInlineItem,
} from '../../.upstream/pretext/src/rich-inline.js'
import { TEXTS } from '../../.upstream/pretext/src/test-data.js'
import { installFakeCanvas } from './fake-canvas.ts'

installFakeCanvas()

const OUT_DIR = '../../tests/Pretext.Wpf.Tests/TestData'
const SIZES = [12, 16, 24]
const WIDTHS = [150, 250, 400, 600]

type CaseResult = {
  label: string
  text: string
  size: number
  width: number
  options: PrepareOptions | null
  lines: { text: string; width: number }[]
}

const results: CaseResult[] = []

function runCase(label: string, text: string, size: number, width: number, options: PrepareOptions | null): void {
  const prepared = prepareWithSegments(text, `${size}px Test`, options ?? undefined)
  const laidOut = layoutWithLines(prepared, width, size * 1.2)
  results.push({
    label,
    text,
    size,
    width,
    options,
    lines: laidOut.lines.map(line => ({ text: line.text, width: line.width })),
  })
}

for (const entry of TEXTS) {
  for (const size of SIZES) {
    for (const width of WIDTHS) {
      runCase(entry.label, entry.text, size, width, null)
    }
  }
}

// Option sweeps on representative texts: letter spacing, keep-all, pre-wrap
// whitespace, discretionary hyphens, and explicit zero-width break opportunities.
const korean = TEXTS.find(entry => entry.label === 'Korean')!
for (const width of WIDTHS) {
  runCase('Latin letterSpacing', TEXTS[0]!.text, 16, width, { letterSpacing: 1.5 })
  runCase('Korean keep-all', korean.text, 16, width, { wordBreak: 'keep-all' })
  runCase('PreWrap mixed', 'Hello\n  World\tTabbed\nEnd  ', 16, width, { whiteSpace: 'pre-wrap' })
  runCase('SoftHyphen', 'extra\u00ADordinary compression', 16, width, null)
  runCase('ZWSP', 'foo\u200Bbarbazquux something', 16, width, null)
}

await Bun.write(`${OUT_DIR}/upstream-parity-corpus.json`, JSON.stringify(results))
console.log(`upstream-parity-corpus.json: ${results.length} cases`)

// --- rich inline ---

type ScenarioItem = {
  text: string
  size: number
  letterSpacing?: number
  break?: 'normal' | 'never'
  extraWidth?: number
}

const SCENARIOS: { label: string; items: ScenarioItem[] }[] = [
  {
    label: 'plain run',
    items: [
      { text: 'The quick brown fox ', size: 16 },
      { text: 'jumps over ', size: 16 },
      { text: 'the lazy dog and keeps running', size: 16 },
    ],
  },
  {
    label: 'styled sizes',
    items: [
      { text: 'Mixed ', size: 12 },
      { text: 'sizes ', size: 24 },
      { text: 'in one inline flow that wraps somewhere', size: 16 },
    ],
  },
  {
    label: 'chips',
    items: [
      { text: 'Assigned to ', size: 16 },
      { text: '@christian289', size: 16, break: 'never', extraWidth: 12 },
      { text: ' and ', size: 16 },
      { text: '@reviewer-with-long-handle', size: 16, break: 'never', extraWidth: 12 },
      { text: ' today', size: 16 },
    ],
  },
  {
    label: 'letter spacing',
    items: [
      { text: 'Spaced out heading ', size: 16, letterSpacing: 2 },
      { text: 'then normal body text that continues', size: 16 },
    ],
  },
  {
    label: 'boundary whitespace',
    items: [
      { text: 'trailing   ', size: 16 },
      { text: '   leading and more words here', size: 16 },
    ],
  },
  {
    label: 'cjk mix',
    items: [
      { text: '这是中文', size: 16 },
      { text: ' mixed with English ', size: 16 },
      { text: '和更多中文内容在这里', size: 16 },
    ],
  },
  {
    label: 'rtl mix',
    items: [
      { text: 'Total ', size: 16 },
      { text: 'مرحبا بالعالم', size: 16 },
      { text: ' done', size: 16 },
    ],
  },
]

const RICH_WIDTHS = [120, 200, 320, 500]

const richResults: {
  label: string
  items: ScenarioItem[]
  width: number
  lineCount: number
  maxLineWidth: number
  lines: { width: number; fragments: { itemIndex: number; text: string; gapBefore: number; occupiedWidth: number }[] }[]
}[] = []

for (const scenario of SCENARIOS) {
  for (const width of RICH_WIDTHS) {
    const items: RichInlineItem[] = scenario.items.map(item => ({
      text: item.text,
      font: `${item.size}px Test`,
      letterSpacing: item.letterSpacing,
      break: item.break,
      extraWidth: item.extraWidth,
    }))
    const prepared = prepareRichInline(items)
    const lines: (typeof richResults)[number]['lines'] = []
    const lineCount = walkRichInlineLineRanges(prepared, width, range => {
      const line = materializeRichInlineLineRange(prepared, range)
      lines.push({
        width: line.width,
        fragments: line.fragments.map(fragment => ({
          itemIndex: fragment.itemIndex,
          text: fragment.text,
          gapBefore: fragment.gapBefore,
          occupiedWidth: fragment.occupiedWidth,
        })),
      })
    })
    richResults.push({
      label: scenario.label,
      items: scenario.items,
      width,
      lineCount,
      maxLineWidth: measureRichInlineStats(prepared, width).maxLineWidth,
      lines,
    })
  }
}

await Bun.write(`${OUT_DIR}/upstream-rich-corpus.json`, JSON.stringify(richResults))
console.log(`upstream-rich-corpus.json: ${richResults.length} cases`)

// --- dictionary boundaries for scripts written without spaces ---

const wordSegmenter = new Intl.Segmenter(undefined, { granularity: 'word' })
const continuaRe = /[\u0E00-\u0E7F\u0E80-\u0EFF\u1780-\u17FF\u1000-\u109F]+/gu
const dictionary: Record<string, number[]> = {}
for (const entry of TEXTS) {
  for (const match of entry.text.matchAll(continuaRe)) {
    const run = match[0]
    if (run.length < 2 || dictionary[run] !== undefined) continue
    const offsets: number[] = []
    for (const segment of wordSegmenter.segment(run)) {
      if (segment.index > 0) offsets.push(segment.index)
    }
    dictionary[run] = offsets
  }
}

await Bun.write(`${OUT_DIR}/native-word-dictionary.json`, JSON.stringify(dictionary))
console.log(`native-word-dictionary.json: ${Object.keys(dictionary).length} runs`)
