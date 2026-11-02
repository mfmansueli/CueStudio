#!/usr/bin/env python3
"""Q0, the approval battery of the creator-inputs plan (reports/entradas-do-criador-2026-11-01-completo.md, 11.8).

Reads the samples CreatorInputsDeviceTests writes (one JSON per case, route and idea: creator-inputs-<case>-<route>-<idea>.json) and gives four
separate counts for each run and route, every one over what was ASKED, so a change can't look better by answering fewer of the hard cases:

  1. executed     a sample came back for the case (written or failed)
  2. written      the sample has a script
  3. constraints  every hard constraint of the case held (a script that didn't come counts as not held)
  4. editorial    the three Q1 questions are all "sim" (read by hand; from --q1, else not counted)

Preferences (an opening style, an ending the creator usually uses) are habits, not constraints: they are reported apart, as how often they show,
never as pass or fail. What is a constraint is the owner's decision (B1, B8, B9, B11); the default spec below holds only what the profile says
with a "never" or the app's own rule, and --spec replaces it.

  tools/creator_inputs/q0.py --run DIR:app,device [--run DIR2:cloud] [--labels classificacao.csv] [--q1 q1.csv] [--spec spec.json]

--labels takes the hand labels (columns case, idea_index, file, engagement_cta_at_end, asks_to_follow, catchphrase_used, opens_with_question,
speaker_gender_mark): a label wins over the automatic check of the same thing.
"""
import argparse
import csv
import json
import math
import re
from pathlib import Path

IDEAS_PER_CASE = 3

# What each case of CreatorInputsDeviceTests asks. constraints: must hold in every script; preferences: shown as a share only.
DEFAULT_SPEC = {
    "pt-fitness-woman": {"language": "pt", "constraints": [], "preferences": []},
    "es-beauty-woman": {"language": "es", "constraints": [], "preferences": []},
    "it-food-woman": {"language": "it", "constraints": [], "preferences": []},
    "fr-travel-woman": {"language": "fr", "constraints": [], "preferences": []},
    "en-no-cta": {
        "language": "en", "phrase": "Here's the thing",
        "constraints": ["no_engagement_cta_at_end", "phrase_not_first_words"],
        "preferences": ["opens_with_question", "phrase_used"],
    },
    "pt-follow-cta": {
        "language": "pt", "phrase": "Bora lá",
        "constraints": ["phrase_not_first_words"],
        "preferences": ["opens_with_question", "phrase_used", "asks_to_follow"],
    },
}

CTA = {
    "en": r"\b(follow|subscribe|comment|save (this|it)|like|share|link in (my )?bio|let me know|tell me|drop a)\b",
    "pt": r"\b(me segu[ei]|segue|siga|seguir|comenta|comente|salva|salve|compartilh|curt[ae]|link na bio|me conta|conta aqui)\w*",
}
FOLLOW = {"en": r"\bfollow\b", "pt": r"\b(me segu[ei]|segue|siga|seguir)\w*"}


def spoken(text):
    return re.sub(r"\[[^\]]*\]", " ", text or "")


def paragraphs(text):
    return [part.strip() for part in re.split(r"\n\s*\n", spoken(text)) if part.strip()]


def first_sentence(text):
    clean = spoken(text).strip()
    match = re.search(r"^.*?[.!?¿¡]+(?=\s|$)", clean, re.S)
    return (match.group(0) if match else clean[:160]).strip()


def fold(text):
    return re.sub(r"[^\w]+", " ", (text or "").lower()).strip()


def automatic(check, sample, case):
    """The screening check; None when it can't be told automatically."""
    text, lang = sample.get("text") or "", case["language"]
    if check == "no_engagement_cta_at_end":
        last = paragraphs(text)[-1:] or [""]
        return re.search(CTA.get(lang, CTA["en"]), last[0], re.I) is None
    if check == "asks_to_follow":
        return re.search(FOLLOW.get(lang, FOLLOW["en"]), spoken(text), re.I) is not None
    if check == "opens_with_question":
        return "?" in first_sentence(text)
    if check == "phrase_used":
        return fold(case["phrase"]) in fold(text)
    if check == "phrase_not_first_words":
        return not fold(spoken(text)).startswith(fold(case["phrase"]))
    return None


LABEL_COLUMNS = {
    "no_engagement_cta_at_end": ("engagement_cta_at_end", lambda value: value != "Y"),
    "asks_to_follow": ("asks_to_follow", lambda value: value == "Y"),
    "opens_with_question": ("opens_with_question", lambda value: value == "Y"),
    "phrase_used": ("catchphrase_used", lambda value: value == "Y"),
}


def wilson(hits, total):
    if total == 0:
        return (0.0, 0.0)
    z, p = 1.96, hits / total
    centre = (p + z * z / (2 * total)) / (1 + z * z / total)
    margin = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / (1 + z * z / total)
    return (max(0.0, centre - margin), min(1.0, centre + margin))


def share(hits, total):
    low, high = wilson(hits, total)
    return f"{hits}/{total} ({hits / total:.0%}, IC95 {low:.0%}–{high:.0%})" if total else "0/0"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run", action="append", required=True, help="DIR:route[,route]: a run's folder and the routes it was asked for")
    parser.add_argument("--labels", help="hand labels (classificacao.csv)")
    parser.add_argument("--q1", help="Q1 labels: columns file, all_three (sim/não)")
    parser.add_argument("--spec", help="JSON that replaces the default constraints and preferences")
    args = parser.parse_args()
    spec = json.loads(Path(args.spec).read_text()) if args.spec else DEFAULT_SPEC

    labels = {}
    if args.labels:
        with open(args.labels, encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                labels[Path(row["file"]).name] = row
    q1 = {}
    if args.q1:
        with open(args.q1, encoding="utf-8") as handle:
            for row in csv.DictReader(handle):
                q1[Path(row["file"]).name] = row["all_three"].strip().lower() == "sim"

    for run in args.run:
        folder, _, routes = run.rpartition(":")
        folder = Path(folder)
        for route in [r for r in routes.split(",") if r]:
            asked = executed = written = held = editorial = constrained = 0
            preferences, broken, models = {}, {}, {}
            for case_id, case in spec.items():
                for idea in range(IDEAS_PER_CASE):
                    asked += 1
                    constrained += 1 if case["constraints"] else 0
                    name = f"creator-inputs-{case_id}-{route}-{idea}.json"
                    path = folder / name
                    sample = json.loads(path.read_text()) if path.exists() else None
                    if sample is None:
                        continue
                    executed += 1
                    model = sample.get("model") or "none"
                    models[model] = models.get(model, 0) + 1
                    if not (sample.get("text") or "").strip():
                        continue
                    written += 1
                    label = labels.get(name, {})

                    def verdict(check):
                        column = LABEL_COLUMNS.get(check)
                        if column and label.get(column[0], "") != "":
                            return column[1](label[column[0]])
                        return automatic(check, sample, case)

                    results = {check: verdict(check) for check in case["constraints"]}
                    if results and all(results.values()):
                        held += 1
                    for check, ok in results.items():
                        if not ok:
                            broken[check] = broken.get(check, 0) + 1
                    for check in case["preferences"]:
                        seen, count = preferences.get(check, (0, 0))
                        preferences[check] = (seen + (1 if verdict(check) else 0), count + 1)
                    if q1.get(name):
                        editorial += 1
            # The model that wrote it: a route asked for Private Cloud Compute may have been written on the iPhone.
            print(f"== {folder.name} · {route} · written by {models or 'nothing'}")
            print(f"  1. executed     {share(executed, asked)}")
            print(f"  2. written      {share(written, asked)}")
            print(f"  3. constraints  {share(held, constrained)} of the cases that have one" + (f"   broken: {broken}" if broken else ""))
            print(f"  4. editorial    {share(editorial, asked)}" + ("" if q1 else "   (no --q1: not read)"))
            for check, (seen, count) in sorted(preferences.items()):
                print(f"     preference {check}: {seen}/{count} of the written")


if __name__ == "__main__":
    main()
