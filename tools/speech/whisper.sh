#!/bin/zsh
# Transcribes every speech fixture with WhisperKit (brew install whisperkit-cli), the language given and word timestamps on,
# one folder of JSON reports per model, to score against Apple's with score.py (LOCALIZATION.md §5, "Another recognizer").
# Usage: tools/speech/whisper.sh <out dir> <models dir> <model> [<model> …]   (models: large-v3-v20240930_turbo_632MB, …)
set -e
out_root=$1 models=$2; shift 2
fixtures="$(cd "$(dirname "$0")/../.." && pwd)/Cue StudioTests/Fixtures/Speech"
typeset -A code=(ar-SA ar da-DK da de-DE de en-US en es-ES es fr-FR fr hi-IN hi id-ID id it-IT it ja-JP ja ko-KR ko nb-NO no
  nl-NL nl pt-BR pt sv-SE sv th-TH th tr-TR tr vi-VN vi zh-CN zh zh-TW zh)
for model in "$@"; do
  out="$out_root/out-$model"; mkdir -p "$out"
  for lang in ${(k)code}; do
    args=(); for f in "$fixtures/speech-$lang.m4a" "$fixtures"/Human/human-$lang-*.m4a; do args+=(--audio-path "$f"); done
    whisperkit-cli transcribe --model "$model" --download-model-path "$models" --download-tokenizer-path "$models" $args \
      --language ${code[$lang]} --word-timestamps --report --report-path "$out" --concurrent-worker-count 1 > "$out/$lang.log" 2>&1
  done
done
