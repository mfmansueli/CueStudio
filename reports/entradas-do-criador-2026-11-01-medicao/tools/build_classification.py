"""Builds classificacao.csv: one row per script of the two device runs, with the hand classification of 02/11/2026.

The automatic screen (score_inputs.py) only pointed where to look; every value below was read by hand. Run from anywhere:
python3 -I tools/build_classification.py <measurement folder>
"""
import csv
import json
import os
import re
import sys

root = sys.argv[1]
RUNS = {
    "run1-iago-lima": ("iago Lima iphone", "iPhone 15 Pro (iPhone16,1)", "iOS 27.2 (24B119)"),
    "run2-mansuelli": ("Mansuelli iPhone 18 Pro Max", "iPhone 18 Pro Max (iPhone19,7)", "iOS 27.0.1 (24A446)"),
}

# Speaker-gender agreement in the first person (women personas; the profile says nothing of gender). Key: (run, case, route, idea).
GENDER = {
    ("run1-iago-lima", "fr-travel-woman", "app", 1): ("M", "Je suis parti trop tôt"),
    ("run1-iago-lima", "fr-travel-woman", "device", 1): ("M", "Je me suis réveillé tard"),
    ("run1-iago-lima", "fr-travel-woman", "device", 2): ("M", "Je suis passé à l'essentiel"),
    ("run1-iago-lima", "es-beauty-woman", "device", 0): ("F", "confianza en mí misma"),
    ("run2-mansuelli", "es-beauty-woman", "cloud", 2): ("M", "me sentí perdido"),
    ("run2-mansuelli", "fr-travel-woman", "cloud", 1): ("M", "je suis arrivé"),
    ("run2-mansuelli", "it-food-woman", "cloud", 1): ("M", "mi sono reso conto"),
}

# Ending cases. engagement = the last block asks the viewer to comment, save, follow, share or like (an instruction to apply the tip is not one).
ENDINGS = {
    ("run1-iago-lima", "en-no-cta", "app", 0): ("Y", "Comment below."),
    ("run1-iago-lima", "en-no-cta", "app", 1): ("Y", "Comment your morning goal."),
    ("run1-iago-lima", "en-no-cta", "app", 2): ("N", "Try setting that timer. (instruction, not engagement)"),
    ("run1-iago-lima", "en-no-cta", "device", 0): ("N", ""),
    ("run1-iago-lima", "en-no-cta", "device", 1): ("N", ""),
    ("run1-iago-lima", "en-no-cta", "device", 2): ("Y", "Save this."),
    ("run2-mansuelli", "en-no-cta", "cloud", 0): ("N", "Try skipping the list (instruction)"),
    ("run2-mansuelli", "en-no-cta", "cloud", 1): ("Y", "Now go save this idea for later"),
    ("run2-mansuelli", "en-no-cta", "cloud", 2): ("Y", "Now save this so you can try step one tomorrow"),
}
# "Follow for more": (asks to follow, asks something else of the viewer, quote).
FOLLOW = {
    ("run1-iago-lima", "pt-follow-cta", "app", 0): ("N", "Y", "Comente qual mudança você gostaria de ter."),
    ("run1-iago-lima", "pt-follow-cta", "app", 1): ("Y", "Y", "Comente sua rotina e siga."),
    ("run1-iago-lima", "pt-follow-cta", "app", 2): ("N", "Y", "Comente qual é o seu erro matinal"),
    ("run1-iago-lima", "pt-follow-cta", "device", 0): ("Y", "Y", "Comente qual é o seu ritual matinal. Seguam para mais dicas. (misspelt)"),
    ("run1-iago-lima", "pt-follow-cta", "device", 1): ("N", "Y", "Comente qual método você usa. [follow] (stage cue only, not spoken)"),
    ("run1-iago-lima", "pt-follow-cta", "device", 2): ("Y", "Y", "Comente seu método e siga para mais dicas."),
    ("run2-mansuelli", "pt-follow-cta", "cloud", 0): ("Y", "Y", "comece por um simples save  siga para mais dicas"),
    ("run2-mansuelli", "pt-follow-cta", "cloud", 1): ("Y", "Y", "salvar esse vídeo  siga para mais dicas rápidas"),
    ("run2-mansuelli", "pt-follow-cta", "cloud", 2): ("N", "N", "Agora eu salvo esse momento no meu celular (the creator, not the viewer)"),
}
OPENS_WITH_QUESTION_NO = {
    ("run2-mansuelli", "en-no-cta", "cloud", 2),
    ("run1-iago-lima", "pt-follow-cta", "app", 0), ("run1-iago-lima", "pt-follow-cta", "app", 2), ("run1-iago-lima", "pt-follow-cta", "device", 0),
}
CATCHPHRASE_MISSING = {("run1-iago-lima", "pt-follow-cta", "app", 2)}

# Numbers that are not in the idea, by kind: structure (a list), rhetorical (a hook or a hypothesis), scene (a detail of an imagined
# first-person routine or story), advice (a step the viewer may take), result (an outcome attributed to the creator: weight, money, percentage).
NUMBERS = {
    ("run1-iago-lima", "en-no-cta", "device", 1): "scene: “a clear three-minute routine”",
    ("run1-iago-lima", "fr-travel-woman", "device", 2): "structure: “1. 2. 3.”",
    ("run1-iago-lima", "it-food-woman", "app", 0): "rhetorical: “Ventisette piatti in un'ora: è possibile?” (idea: twenty people)",
    ("run1-iago-lima", "pt-fitness-woman", "app", 1): "RESULT: “Eu perdi 2 quilos em 7 dias”",
    ("run1-iago-lima", "pt-fitness-woman", "device", 0): "scene: “três vezes por semana”",
    ("run1-iago-lima", "pt-fitness-woman", "device", 2): "scene: “2 vezes por semana”",
    ("run2-mansuelli", "en-no-cta", "cloud", 2): "advice: “a timer for twenty minutes”",
    ("run2-mansuelli", "pt-follow-cta", "cloud", 0): "scene: “só cinco minutos”, “três coisas boas”",
    ("run2-mansuelli", "it-food-woman", "cloud", 0): "scene: “ho cotto tutto per venti minuti” (the idea's number, venti persone, back with another unit)",
}
NOTES = {
    ("run1-iago-lima", "pt-follow-cta", "device", 0): "conjugation error “Seguam” (Sigam)",
    ("run2-mansuelli", "pt-fitness-woman", "cloud", 0): "broken: one line ending in a stray quote; “ginásio” (gym in pt-PT; in pt-BR usually “academia”): possible pt-PT leak",
    ("run2-mansuelli", "pt-follow-cta", "cloud", 0): "“isso me deixa mais calmo”: masculine for a persona whose gender is not given",
}

rows = []
for run, (device, model_name, os_version) in RUNS.items():
    folder = os.path.join(root, run)
    for name in sorted(os.listdir(folder)):
        if not (name.startswith("creator-inputs-") and name.endswith(".json")):
            continue
        s = json.load(open(os.path.join(folder, name)))
        key = (run, s["caseID"], s["route"], s["ideaIndex"])
        text = s.get("text") or ""
        spoken = re.sub(r"\[[^\]]*\]", "", text)
        row = {
            "run": run, "device": device, "hardware": model_name, "os": os_version,
            "route_requested": s["route"], "model_effective": s.get("model") or "", "case": s["caseID"], "idea_index": s["ideaIndex"],
            "idea": s["idea"], "words": len(spoken.split()), "seconds": round(s["seconds"], 1), "failure": s.get("failure") or "",
            "speaker_gender_mark": "", "gender_quote": "", "engagement_cta_at_end": "", "asks_to_follow": "", "other_viewer_action": "",
            "ending_quote": "", "opens_with_question": "", "catchphrase_used": "", "numbers_not_in_idea": NUMBERS.get(key, ""),
            "notes": NOTES.get(key, ""), "file": f"{run}/{name}",
        }
        if s["caseID"].endswith("woman"):
            mark, quote = GENDER.get(key, ("none", ""))
            row["speaker_gender_mark"], row["gender_quote"] = mark, quote
        if s["caseID"] == "en-no-cta":
            row["engagement_cta_at_end"], row["ending_quote"] = ENDINGS[key]
        if s["caseID"] == "pt-follow-cta":
            row["asks_to_follow"], row["other_viewer_action"], row["ending_quote"] = FOLLOW[key]
        if s["caseID"] in ("en-no-cta", "pt-follow-cta"):
            row["opens_with_question"] = "N" if key in OPENS_WITH_QUESTION_NO else "Y"
            row["catchphrase_used"] = "N" if key in CATCHPHRASE_MISSING else "Y"
        rows.append(row)

with open(os.path.join(root, "classificacao.csv"), "w", newline="") as out:
    writer = csv.DictWriter(out, fieldnames=list(rows[0].keys()))
    writer.writeheader()
    writer.writerows(rows)

def count(case, field, value):
    hits = [r for r in rows if r["case"] == case and r[field] == value]
    return len(hits), len([r for r in rows if r["case"] == case])

print("rows", len(rows), "models", sorted({r["model_effective"] for r in rows}))
print("gender M", sum(r["speaker_gender_mark"] == "M" for r in rows), "F", sum(r["speaker_gender_mark"] == "F" for r in rows),
      "none", sum(r["speaker_gender_mark"] == "none" for r in rows))
print("no-cta engagement at end", count("en-no-cta", "engagement_cta_at_end", "Y"))
print("follow", count("pt-follow-cta", "asks_to_follow", "Y"), "other action", count("pt-follow-cta", "other_viewer_action", "Y"))
print("question en", count("en-no-cta", "opens_with_question", "Y"), "pt", count("pt-follow-cta", "opens_with_question", "Y"))
print("catchphrase en", count("en-no-cta", "catchphrase_used", "Y"), "pt", count("pt-follow-cta", "catchphrase_used", "Y"))
