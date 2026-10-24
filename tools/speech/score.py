"""Scores Apple's captions (raw and on screen, from a CaptionSpeechTests device log) and WhisperKit's transcripts against
each recording's script, with one rule for all: WER by words, CER by letters for ja/zh/th/ko. Chinese is folded to
Simplified on both sides. Prints a table per language (system voice, people mean and worst) and writes details to JSON.

Usage: python3 -I score.py <device log> <whisper out dir> [<whisper out dir> ...] --json <out.json>
"""
import json, re, statistics, subprocess, sys, unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / "Cue StudioTests/Fixtures/Speech"
HANS = Path(__file__).with_name("hans.swift")
CHARS = {"ja-JP", "zh-CN", "zh-TW", "th-TH", "ko-KR"}
CASES = {"english": "en-US", "spanish": "es-ES", "portugueseBrazil": "pt-BR", "french": "fr-FR", "german": "de-DE",
         "italian": "it-IT", "japanese": "ja-JP", "korean": "ko-KR", "chineseSimplified": "zh-CN", "hindi": "hi-IN",
         "indonesian": "id-ID", "arabic": "ar-SA", "turkish": "tr-TR", "thai": "th-TH", "vietnamese": "vi-VN",
         "chineseTraditional": "zh-TW", "dutch": "nl-NL", "swedish": "sv-SE", "danish": "da-DK", "norwegian": "nb-NO"}


def scripts():
    found = {}
    for sample in json.load(open(FIX / "Human/human-speech.json"))["samples"]:
        found[Path(sample["file"]).stem] = (sample["language"], sample["script"])
    source = (ROOT / "Cue StudioTests/Language/VoiceFollowingSpeechTests.swift").read_text()
    for case, text in re.findall(r'^\s+\.(\w+): "(.*)",?$', source, re.M):
        if case in CASES:
            found[f"speech-{CASES[case]}"] = (CASES[case], text.replace('\\"', '"'))
    return found


def apple(log):
    raw, screen, sync = {}, {}, {}
    name = r"((?:speech|human)-[a-z]{2}-[A-Z]{2}(?:-\d)?)(?: \(\w+\))?"
    for line in open(log, encoding="utf-8", errors="replace"):
        if m := re.search(r"CAPTION WORDS " + name + r": (.*)$", line):
            raw[m[1]] = " ".join(w for w, _, _ in re.findall(r"(\S+?)@(-?[\d.]+)–(-?[\d.]+)", m[2]))
        elif m := re.search(r"CAPTION SCREEN " + name + r": (.*)$", line):
            screen[m[1]] = m[2].replace(" | ", " ")
        elif m := re.search(r"CAPTIONS \S+ " + name + r": .*?first word ([\d.]+) s \(voice at ([\d.]+) s\) · last word ([\d.]+) s"
                            r" \(voice stops at ([\d.]+) s\)", line):
            sync[m[1]] = tuple(float(x) for x in m.groups()[1:])
    return raw, screen, sync


def whisper(folder):
    out = {}
    for path in Path(folder).glob("*.json"):
        data = json.load(open(path))
        words = [w for s in data.get("segments", []) for w in s.get("words", [])]
        text = " ".join(w["word"].strip() for w in words) if words else data.get("text", "")
        first = words[0]["start"] if words else None
        last = words[-1]["end"] if words else None
        out[path.stem] = (text, first, last)
    return out


def to_hans(texts):
    if not texts:
        return []
    done = subprocess.run(["swift", str(HANS)], input="\n".join(t.replace("\n", " ") for t in texts), capture_output=True,
                          text=True, check=True)
    return done.stdout.split("\n")[: len(texts)]


def normalized(text):
    text = unicodedata.normalize("NFKC", text).casefold()
    return "".join(" " if unicodedata.category(c)[0] in "PSZ" else c for c in text)


def tokens(text, language):
    text = normalized(text)
    return [c for c in text if not c.isspace()] if language in CHARS else text.split()


def errors(ref, hyp):
    previous = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        current = [i] + [0] * len(hyp)
        for j, h in enumerate(hyp, 1):
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (r != h))
        previous = current
    return previous[-1] / max(1, len(ref))


def main(args):
    out_json = args[args.index("--json") + 1]
    args = args[: args.index("--json")]
    log, folders = args[0], args[1:]
    refs = scripts()
    raw, screen, sync = apple(log)
    systems = {"apple raw": {k: (v, None, None) for k, v in raw.items()},
               "apple screen": {k: (v, None, None) for k, v in screen.items()}}
    for folder in folders:
        systems["whisper " + Path(folder).name.removeprefix("out-")] = whisper(folder)
    # Fold Chinese to Simplified everywhere.
    zh = [(name, k) for name, entries in systems.items() for k in entries if refs.get(k, ("",))[0].startswith("zh")]
    folded = to_hans([systems[n][k][0] for n, k in zh])
    for (n, k), text in zip(zh, folded):
        systems[n][k] = (text,) + systems[n][k][1:]
    zh_refs = sorted(k for k in refs if refs[k][0].startswith("zh"))
    for k, text in zip(zh_refs, to_hans([refs[k][1] for k in zh_refs])):
        refs[k] = (refs[k][0], text)

    details = {}
    for name, entries in systems.items():
        for k, (text, first, last) in entries.items():
            if k not in refs:
                continue
            language, script = refs[k]
            rate = errors(tokens(script, language), tokens(text, language))
            onset = sync.get(k)
            details.setdefault(k, {"language": language, "script": script})[name] = {
                "error": round(rate, 3), "text": text,
                "first_off": round(first - onset[0], 2) if onset and first is not None else None,
                "last_off": round(last - onset[2], 2) if onset and last is not None else None,
            }
    json.dump(details, open(out_json, "w"), ensure_ascii=False, indent=1)

    names = list(systems)
    print("| Language | " + " | ".join(f"{n}: system · people (worst)" for n in names) + " |")
    print("|---|" + "---|" * len(names))
    for language in sorted({d["language"] for d in details.values()}):
        cells = []
        for n in names:
            system = [d[n]["error"] for k, d in details.items() if d["language"] == language and k.startswith("speech-") and n in d]
            people = [d[n]["error"] for k, d in details.items() if d["language"] == language and k.startswith("human-") and n in d]
            pct = lambda x: f"{round(100 * x)}%"
            cells.append((pct(system[0]) if system else "–") + " · "
                         + (f"{pct(statistics.mean(people))} ({pct(max(people))})" if people else "–"))
        unit = "CER" if language in CHARS else "WER"
        print(f"| {language} {unit} | " + " | ".join(cells) + " |")
    for n in names:
        offs = [abs(d[n]["first_off"]) for d in details.values() if n in d and d[n].get("first_off") is not None]
        if offs:
            print(f"{n}: first word vs voice, median {statistics.median(offs):.2f} s, worst {max(offs):.2f} s (n={len(offs)})")


if __name__ == "__main__":
    main(sys.argv[1:])
