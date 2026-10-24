"""Turns the picked FLEURS clips into Cue's human speech fixtures: AAC 16 kHz mono like the synthetic ones, loudness-normalized,
and a manifest with each clip's script, voice, origin and the dataset's credit.

Usage: python3 -I build.py <raw_dir> <fixtures_dir>
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def cleaned(text):
    """The FLEURS tables keep CSV quoting in some transcripts (outer quotes, doubled inner ones)."""
    text = text.strip()
    if text.startswith('"') and text.endswith('"') and '""' in text:
        text = text[1:-1].strip()
    text = text.replace('""', '"')
    for _ in range(2):
        if text.count('"') % 2 == 1 and text.startswith('"'):
            text = text[1:].strip()
        if text.count('"') % 2 == 1 and text.endswith('"'):
            text = text[:-1].strip()
    return text


def traditional(lines):
    result = subprocess.run(["swift", os.path.join(HERE, "hant.swift")], input="\n".join(lines) + "\n",
                            capture_output=True, text=True, check=True)
    converted = result.stdout.rstrip("\n").split("\n")
    assert len(converted) == len(lines) and "FAILED" not in converted
    return converted


def main(raw_dir, fixtures_dir):
    os.makedirs(fixtures_dir, exist_ok=True)
    languages = json.load(open(os.path.join(raw_dir, "picks.json"), encoding="utf-8"))
    samples = []
    for entry in languages:
        language = entry["language"]
        scripts = [cleaned(pick["raw"]) for pick in entry["picks"]]
        if language == "zh-TW":
            scripts = traditional(scripts)
        for number, (pick, script) in enumerate(zip(entry["picks"], scripts), 1):
            name = f"human-{language}-{number}"
            subprocess.run([
                "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
                "-i", os.path.join(raw_dir, language, f"{number}.wav"),
                "-af", "loudnorm=I=-16:TP=-2:LRA=11", "-ac", "1", "-ar", "16000", "-c:a", "aac", "-b:a", "32k",
                os.path.join(fixtures_dir, f"{name}.m4a"),
            ], check=True)
            samples.append({
                "language": language, "file": name, "script": script, "voice": pick["gender"], "seconds": pick["seconds"],
                "fleurs": {"config": entry["config"], "split": pick.get("split", "test"), "file": pick["fleursFile"],
                           "sentence": pick["sentence"]},
                "note": entry["note"],
            })
    manifest = {
        "source": "FLEURS, Google (https://huggingface.co/datasets/google/fleurs)",
        "citation": "Conneau et al., FLEURS: Few-shot Learning Evaluation of Universal Representations of Speech, 2022",
        "license": "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
        "changes": "Four clips per language (two women, two men), from the test split, or the train split where the test "
                   "split has a single voice; loudness-normalized to -16 LUFS and encoded as AAC 16 kHz mono; outer CSV "
                   "quotes removed from transcripts; zh-TW transcripts converted to Traditional characters (ICU Hans-Hant).",
        "samples": samples,
    }
    with open(os.path.join(fixtures_dir, "human-speech.json"), "w", encoding="utf-8") as file:
        json.dump(manifest, file, ensure_ascii=False, indent=1)
        file.write("\n")
    print(len(samples), "samples")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
