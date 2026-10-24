# People's voices for the speech tests (FLEURS)

`Cue StudioTests/Fixtures/Speech/Human` holds four readings a language (two women, two men) from Google's FLEURS
(https://huggingface.co/datasets/google/fleurs, CC BY 4.0, Conneau et al. 2022), listed in `human-speech.json`. The device
suites play them with `TEST_RUNNER_CUE_SPEECH_VOICE=human` or `both` (`CLAUDE.md`, results in `LOCALIZATION.md` §5).

To rebuild them (needs `ffmpeg` and Xcode's `swift`), from an empty folder outside the repo:

1. `python3 -I fetch.py raw` streams each language's test pack and stops once four clips are picked (6–16 s, enough words).
2. `python3 -I topup.py raw` replaces two clips with the other voice from the train split where the test split has one voice.
3. `python3 -I build.py raw "<repo>/Cue StudioTests/Fixtures/Speech/Human"` encodes them (AAC 16 kHz mono, −16 LUFS), converts
   zh-TW transcripts to Traditional characters (`hant.swift`) and writes the manifest.

To read a run: `python3 -I collect.py build/logs/test-device.log` (system voice against people, per language);
`python3 -I table.py captions.log following.log spoken.log latency.log` prints the table in `LOCALIZATION.md` §5.

What the creator sees, without a phone: a `CaptionSpeechTests` run with `both` prints every word heard (`CAPTION WORDS`);
`python3 -I heard_fixture.py build/logs/test-device.log "Cue StudioTests/Fixtures/Speech/heard-captions.json" "iPhone 15 Pro,
iOS 27.0, <date>"` keeps them for `CaptionReplayTests`, which rebuilds the lines with each script in the simulator
(`TEST_RUNNER_CUE_REPLAY_REPORT=<file>` writes its table and every reading's lines). Record it again when iOS changes.

Another recognizer against Apple's: `zsh whisper.sh <out> <models> large-v3-v20240930_turbo_632MB` (WhisperKit, about
0.6–1 GB a model; delete them after), then `python3 -I score.py build/logs/test-device.log <out>/out-<model> --json
<file>`: one rule for all (WER, CER for ja/zh/th/ko, Chinese folded to Simplified with `hans.swift`).

