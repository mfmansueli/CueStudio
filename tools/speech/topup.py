"""Where a language's FLEURS test clips are all one voice, replaces picks 3 and 4 with two clips of the other voice from the
train split (streamed, stopped as soon as both are found).

Usage: python3 -I topup.py <out_dir>   (updates <out_dir>/picks.json and the wav files)
"""
import csv, io, json, os, sys, tarfile, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetch import BASE, MAX_SECONDS, MIN_SECONDS, long_enough  # noqa: E402

MAX_MEMBERS = 600


def table(config, split):
    with urllib.request.urlopen(f"{BASE}/{config}/{split}.tsv", timeout=60) as response:
        rows = list(csv.reader(io.TextIOWrapper(response, encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE))
    return {row[1]: {"sentence": int(row[0]), "raw": row[2], "samples": int(row[5]), "gender": row[6].lower()} for row in rows}


def main(out_dir):
    path = os.path.join(out_dir, "picks.json")
    languages = json.load(open(path, encoding="utf-8"))
    for entry in languages:
        voices = {pick["gender"] for pick in entry["picks"]}
        if len(voices) > 1:
            continue
        missing = "female" if voices == {"male"} else "male"
        config = entry["config"]
        taken = {pick["sentence"] for pick in entry["picks"][:2]}
        rows = table(config, "train")
        found, seen = [], 0
        with urllib.request.urlopen(f"{BASE}/{config}/audio/train.tar.gz", timeout=120) as response:
            with tarfile.open(fileobj=response, mode="r|gz") as pack:
                for member in pack:
                    if not member.isfile():
                        continue
                    seen += 1
                    row = rows.get(os.path.basename(member.name))
                    if row is None or row["gender"] != missing or row["sentence"] in taken:
                        continue
                    seconds = row["samples"] / 16000
                    if not (MIN_SECONDS <= seconds <= MAX_SECONDS) or not long_enough(config, row["raw"]):
                        continue
                    number = 3 + len(found)
                    with open(os.path.join(out_dir, entry["language"], f"{number}.wav"), "wb") as file:
                        file.write(pack.extractfile(member).read())
                    found.append({"fleursFile": os.path.basename(member.name), "sentence": row["sentence"], "raw": row["raw"],
                                  "gender": missing, "seconds": round(seconds, 2), "split": "train"})
                    taken.add(row["sentence"])
                    if len(found) == 2 or seen >= MAX_MEMBERS:
                        break
        entry["picks"] = entry["picks"][:2] + found + entry["picks"][2 + len(found):]
        print(f"{entry['language']}: {len(found)} {missing} clips from the first {seen} train clips", flush=True)
    json.dump(languages, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1])
