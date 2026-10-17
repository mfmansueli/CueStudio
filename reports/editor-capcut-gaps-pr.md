# Editor: CapCut gaps (find and replace, select lines, replace clip, extract audio) and technical leftovers (plurals, HDR freeze frame, toast after a sheet)

Builds on `feature/editor-award` and `feature/export-reliability` (from `afce6f9`). Details, numbers and what isn't validated:
`reports/editor-capcut-gaps-report.md`. Current state of each screen: `DESIGN_PROJECT.md` §37.

## What's new

- **Find and replace in captions** (Captions › Find and replace, and the captions menu): a word in every line that plays, marked; Replace one
  match or Replace all in one undo step. Case and width don't matter, accents do. Line and word times stay.
- **Select lines** (Captions › Select lines, or hold a line): pick several lines, then Emphasis (the whole line in the highlight color), Size
  (Regular, Bigger, Biggest), move them together a tenth at a time (inside their clip, never onto another line) or delete them. Each action
  is one undo step. The line style (`CaptionCue.lineStyle`) is drawn by the same renderer in the preview and the export; old edits read as
  plain. While picking, the panel grows and the actions stay pinned under the list, as in CapCut.
- **Replace clip** (clip bar): a video from Photos takes the clip's place from its start, for the clip's length (shorter if the video is),
  keeping speed, zoom, volume, transition and look; what's pinned to the clip stays at the same moment.
- **Extract audio** (clip bar, and the media bar for a video with sound): the sound, as Cue plays it (Studio Voice, leveling, the clip's
  speed), goes to the music track as an editable clip where it played; the clip or video is muted. It follows its moment when something
  before it is cut, and never takes music's room.

## Technical

- **Plurals:** the editor's counts vary by plural in the String Catalog in all 20 languages (Arabic's six forms); the "1 …" keys that dodged
  plurals are gone. `scripts/strings.py add` writes plural forms in Xcode's format and checks each language's categories.
- **HDR freeze frame:** a frame of an HDR recording is written as the decoded 10-bit frame in HEVC Main 10 with the recording's primaries,
  transfer function, matrix and transform; SDR stays H.264; if HDR can't be written it freezes in SDR.
- **Toast after a sheet:** measured with an XCUITest probe, the toast is in the accessibility tree; the old test looked for it after waiting
  for the sheet to go, when its 2 s were over. The paste-look UI test now checks it. No app change.

## Tests

- New unit suites: `CaptionFindReplaceTests`, `QuickEditCaptionFindTests`, `CaptionLineStyleRenderingTests`, `QuickEditCaptionPicksTests`,
  `QuickEditReplaceClipTests`, `QuickEditExtractAudioTests`, `PluralStringsTests`; real files: `SoundExtractorTests`, `FreezeFrameHDRTests`
  (its HLG export case runs only on an iPhone: the Simulator's VideoToolbox can't convert HLG to BGRA, `-12905`).
- New UI tests: `CaptionToolsUITests` (find and replace in `UISmoke`; select lines), `ExtractAudioUITests`.
- Test phase, run on `feature/editor-motion`, which contains this branch whole:
  - `scripts/check-warnings.sh` reports no warnings on the Simulator, device and Release builds.
  - Full: 3,862 tests passed. Two export tests timed out under the parallel plan's load and pass when run alone; one stale UI label was fixed.
  - `FreezeFrameHDRTests`: 3/3 on an iPhone 15 Pro, including the HLG export.
  - Contrast measured on captures of the new screens. The Find and replace prompt was raised from 4.3 to 5.1:1.
  - Two review fixes: Replace keeps what plays on the other part of a cut clip, and Extract audio on a muted clip no longer doubles the voice.

## Not in this PR

- Choosing which part of the new video goes into a replaced clip (CapCut has it; here it starts from the beginning and the clip's handles
  trim it).
- Plurals in strings with two counts ("2 of 3 recordings").

🤖 Generated with [Claude Code](https://claude.com/claude-code)
