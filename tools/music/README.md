# Cue's music and recorded sound effects

The tracks in the editor's music library and most of its sound effects are rendered here. Each track starts as a score written in Python
(`tracks/*.py`), is played on recorded instruments, and is then mixed, mastered and copied into the app. Every recording used is
**CC0**: the owner decided on 29/10/2026 that the library must ask no credit of anyone, neither Cue nor the creator. The app still thanks
these libraries in Settings › Acknowledgements as a courtesy.

## Setup

The recordings stay outside the repository, about 7.5 GB of them:

- `CUE_AUDIO_SOURCES` holds the recordings. It defaults to `~/Desktop/Projects/CueStudio-Audio/sources`, and its `PROVENANCE.txt` lists
  where each one came from and at which commit.
- `CUE_AUDIO_RENDERS` holds the output. It defaults to `~/Desktop/Projects/CueStudio-Audio/renders`.

The Python environment lives next to them. Create it with `python3 -m venv venv`, then
`venv/bin/pip install numpy scipy soundfile pyloudnorm`.

## Sources

| Library | Licence | Where | Plays |
|---|---|---|---|
| VSCO 2 CE (Versilian Studios) | CC0 | github.com/sgossner/VSCO-2-CE @ `44030090` | Strings, harp, woodwinds, brass, marimba, glockenspiel, xylophone, timpani, orchestral percussion (bass drum, cymbals, gong, congas, tambourine…) |
| VCSL (Versilian Community Sample Library) | CC0 | github.com/sgossner/VCSL @ `c1ea7bcc` (sparse) | Steinway B grand, Knight upright, vibraphone, kalimba, hand chimes, tubular bells, cajon, bass drum, tom, sleigh bells, claps, shakers, bongos and the effects' objects |
| Virtuosity Drums v0.925 (Versilian, Karoryfer) | CC0 | github.com/sfzinstruments/virtuosity_drums | The drum kit (`mid` and `lofi` microphones) |
| Swirly Drums v1.104 (Karoryfer) | CC0 | github.com/sfzinstruments/karoryfer.swirly-drums | The brush kit and brush stirs |
| FreePats Spanish Classical Guitar (2019-06-18) | CC0 | freepats.zenvoid.org | The nylon guitar |
| Kenney (interface, casino, RPG, UI sets) | CC0 | opengameart.org | Some sound effects |

`export_app.py` writes the libraries each track plays into `music-library.json` (`sources`). It refuses a recording from any library
missing from its `LIBRARIES` map. A new library therefore needs three things: its licence checked, its line in `PROVENANCE.txt`, and an
entry in `LIBRARIES` and in the app's `SoundSource`.

### What octave a file is named in

File names give a note, but libraries disagree on which octave is which. Each folder was measured:

- **An octave up** (`transpose=12`, named with C3 as middle C): VSCO 2 CE strings, woodwinds, brass, marimba and glockenspiel; the VCSL
  vibraphone and Knight upright.
- **An octave up because of the instrument** (also `transpose=12`): the kalimba sounds an octave above its file names, and hand chimes
  are written an octave below how they sound, as handbells are.
- **As named** (no transpose): the Steinway grand (C4 is middle C). Tubular bells also stay as named: their strike tone is the named
  note, even though the partials measure an octave up.

`instruments.EXCLUDED` lists recordings left out because their attack has a digital click.

### The grand piano's tone

The Steinway's layers were recorded louder than the tracks play them, so they come out brighter than a soft touch would. `SOFT_GRAND`
corrects this. A track adds it to its own EQ, and it brings the Steinway to a soft grand's balance: within 3 dB band by band up to
8 kHz, measured under the same score.

## Rules every track follows

- **Instrumental only.** No vocals, no choirs, no vocal chops.
- **Built for speech.** A track marked `under_speech` (the app's "for talking") must work under someone talking:
  - no crackle, hiss or constant swish;
  - soft drums or none;
  - nothing busy in the voice's band.
  `render.py` measures that band (1–4 kHz, `voiceBandShareDb`). The approved tracks for talking sit between −14.9 and −21.8 dB. When a
  track comes out above that, find the stem that fills the band (render with `--stems`) and darken or lower it.
- **Clean output.** Every render is −16 LUFS integrated, at most −1 dBTP, with **zero clicks** (`dsp.clicks`).

## Making a track

1. Write `tracks/<name>.py` with a `make() -> Track`. Use the `score.py` parts (`Grid`, `Part`, `voice`, `bass_key`, `phrase`) and the
   `instruments.py` builders. Give it the next free seed range for its `Part`s.
2. Render it with `venv/bin/python tools/music/render.py <name> [--stems]`. You get the `.wav`, the `.m4a` and a `.json` of facts (tempo,
   downbeats, loudness, peak, clicks, the voice's band, low end, mono correlation). `--stems` also writes each stem as mixed, to find
   what fills a band or where a click comes from. Delete the stems afterwards.
3. The owner listens and decides. The listening pages pair a track with the one it replaces.
4. Add it to `MUSIC` in `export_app.py`, under the id the app knows it by. Run `venv/bin/python tools/music/export_app.py --check`, which
   measures what would ship and writes nothing, then run it without `--check`.
5. Run the export again after every change to a score, so the app ships the render the owner heard.

The export writes three things:

- `Cue Studio/SupportFiles/Sounds/Music/music-<id>.m4a`: AAC at 128 kbps, 48 kHz stereo.
- `Sounds/Effects/sfx-<id>.caf`: ALAC, 48 kHz mono.
- `Sounds/music-library.json`, holding per track the duration, tempo, beats per bar, `beats` (quarters from the first downbeat to the
  final chord, for the editor's beat snapping), `forTalking` and `sources`.

The files carry a prefix because Xcode copies a synchronized folder's resources flat into the bundle.

## Sound effects

- `sounds.py` builds an effect from recordings and levels it as the app does: mono, the loudest 400 ms at −14 LUFS, never above
  −3 dBFS, at least half a second.
- `variants.py` renders the second takes the owner chose from.
- `EFFECTS` in `export_app.py` lists which render each app effect ships.
- Effects missing from `EFFECTS` stay synthesized by the app.
