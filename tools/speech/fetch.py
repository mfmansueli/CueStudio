"""Picks a few FLEURS test clips per Cue language, reading each language's audio pack as a stream and stopping as soon as
the picks are made (the packs are 300-700 MB; only their first megabytes are read).

Usage: python3 -I fetch.py <out_dir>   (writes <out_dir>/<cue_language>/<n>.wav and <out_dir>/picks.json)
"""
import csv, io, json, os, sys, tarfile, urllib.request

BASE = "https://huggingface.co/datasets/google/fleurs/resolve/main/data"
# Cue language → FLEURS config, and what isn't an exact match.
LANGS = [
    ("en-US", "en_us", None), ("es-ES", "es_419", "Latin American Spanish (FLEURS has no Spain Spanish)"),
    ("pt-BR", "pt_br", None), ("fr-FR", "fr_fr", None), ("de-DE", "de_de", None), ("it-IT", "it_it", None),
    ("ja-JP", "ja_jp", None), ("ko-KR", "ko_kr", None), ("zh-CN", "cmn_hans_cn", None),
    ("zh-TW", "cmn_hans_cn", "Mainland Mandarin speakers; transcript converted to Traditional characters"),
    ("hi-IN", "hi_in", None), ("id-ID", "id_id", None),
    ("ar-SA", "ar_eg", "Egyptian speakers reading Modern Standard Arabic (FLEURS has no Saudi set)"),
    ("tr-TR", "tr_tr", None), ("th-TH", "th_th", None), ("vi-VN", "vi_vn", None), ("nl-NL", "nl_nl", None),
    ("sv-SE", "sv_se", None), ("da-DK", "da_dk", None), ("nb-NO", "nb_no", None),
]
NO_SPACES = {"ja_jp", "cmn_hans_cn", "th_th"}
PER_LANGUAGE = 4
MIN_SECONDS, MAX_SECONDS = 6.0, 16.0
MAX_MEMBERS = 500


def long_enough(config, text):
    if config in NO_SPACES:
        return sum(ch.isalnum() for ch in text) >= 20
    return len(text.split()) >= 12


def table(config):
    with urllib.request.urlopen(f"{BASE}/{config}/test.tsv", timeout=60) as response:
        rows = list(csv.reader(io.TextIOWrapper(response, encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE))
    # id, file, raw transcription, transcription, characters, samples, gender
    return {row[1]: {"sentence": int(row[0]), "raw": row[2], "samples": int(row[5]), "gender": row[6].lower()} for row in rows}


def pick(config, rows, taken, out):
    """Streams the pack and keeps up to PER_LANGUAGE clips: two women and two men when there are, sentences not taken."""
    want = {"female": PER_LANGUAGE // 2, "male": PER_LANGUAGE - PER_LANGUAGE // 2}
    picks, seen = [], 0
    with urllib.request.urlopen(f"{BASE}/{config}/audio/test.tar.gz", timeout=120) as response:
        with tarfile.open(fileobj=response, mode="r|gz") as pack:
            for member in pack:
                if not member.isfile():
                    continue
                seen += 1
                name = os.path.basename(member.name)
                row = rows.get(name)
                if row is None or row["sentence"] in taken:
                    continue
                seconds = row["samples"] / 16000
                if not (MIN_SECONDS <= seconds <= MAX_SECONDS) or not long_enough(config, row["raw"]):
                    continue
                gender = row["gender"]
                late = seen > MAX_MEMBERS // 2  # past half the budget, any voice will do
                if want.get(gender, 0) <= 0 and not late:
                    continue
                data = pack.extractfile(member).read()
                path = os.path.join(out, f"{len(picks) + 1}.wav")
                with open(path, "wb") as file:
                    file.write(data)
                picks.append({"fleursFile": name, "sentence": row["sentence"], "raw": row["raw"], "gender": gender,
                              "seconds": round(seconds, 2)})
                taken.add(row["sentence"])
                if gender in want:
                    want[gender] -= 1
                if len(picks) == PER_LANGUAGE or seen >= MAX_MEMBERS:
                    break
    return picks, seen


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    result, taken_by_config, tables = [], {}, {}
    for cue, config, note in LANGS:
        rows = tables.setdefault(config, table(config))
        taken = taken_by_config.setdefault(config, set())
        out = os.path.join(out_dir, cue)
        os.makedirs(out, exist_ok=True)
        picks, seen = pick(config, rows, taken, out)
        print(f"{cue} ({config}): {len(picks)} picks from the first {seen} clips · "
              + ", ".join(f"{p['gender'][0]} {p['seconds']}s" for p in picks), flush=True)
        result.append({"language": cue, "config": config, "note": note, "picks": picks})
    with open(os.path.join(out_dir, "picks.json"), "w", encoding="utf-8") as file:
        json.dump(result, file, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1])
