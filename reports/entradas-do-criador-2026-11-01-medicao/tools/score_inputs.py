"""Screens the CreatorInputsDeviceTests samples: speaker-gender agreement (a triage, read by hand after), endings, openings, catchphrases."""
import json
import re
import sys
from pathlib import Path

folder = Path(sys.argv[1])
samples = []
for path in sorted(folder.rglob("creator-inputs-*.json")):
    try:
        samples.append(json.loads(path.read_text()))
    except (json.JSONDecodeError, UnicodeDecodeError):
        pass

# First-person predicates whose adjective/participle agrees with the speaker. Captures the word that agrees.
PATTERNS = {
    "pt": r"\b(?:eu\s+)?(?:estou|estava|fiquei|fico|sou|era|me senti|me sinto|me sentia|me vi|estive|cheguei|voltei|acordei|continuo|continuei)\s+(?:muito\s+|tão\s+|super\s+|meio\s+|bem\s+|completamente\s+|totalmente\s+)?([a-zà-ú]+)",
    "es": r"\b(?:yo\s+)?(?:estoy|estaba|estuve|me quedé|me sentí|me siento|me sentía|soy|era|fui|me vi|me puse|me pongo|terminé|acabé)\s+(?:muy\s+|tan\s+|súper\s+|bastante\s+|totalmente\s+|completamente\s+)?([a-zá-úñ]+)",
    "it": r"\b(?:io\s+)?(?:sono|ero|mi sono|mi sento|mi sentivo|mi sentii|rimasi|resto|restai)\s+(?:stat[oa]\s+)?(?:molto\s+|così\s+|super\s+|davvero\s+|completamente\s+|proprio\s+)?([a-zà-ù]+)",
    "fr": r"\b(?:je\s+suis|j'étais|j’étais|je me suis|je me sens|je me sentais|je suis\s+rest[ée]e?|je suis\s+devenue?)\s+(?:très\s+|tellement\s+|super\s+|complètement\s+|vraiment\s+|si\s+)?([a-zà-ÿ]+)",
}
FEM = {"pt": r"a$", "es": r"a$", "it": r"a$", "fr": r"(ée|e)$"}
MASC = {"pt": r"o$", "es": r"o$", "it": r"o$", "fr": r"é$"}
# Words that look agreeing but are not (adverbs, invariable, nouns...).
SKIP = {
    "pt": {"para", "uma", "tipo", "toda", "nessa", "nesta", "assim", "agora", "mesmo", "pouco", "muito", "isso", "aquilo", "fora", "sempre", "de", "em", "no", "na", "a", "o", "com", "sem", "que", "como", "pela", "pelo", "nada", "tudo", "mais", "menos", "pra", "pro", "aqui", "casa", "treino", "dieta", "perto", "longe", "só", "também", "tentando", "treinando", "fazendo", "pensando", "sentindo", "comendo", "achando", "olhando", "esperando", "indo", "vendo"},
    "es": {"una", "toda", "esta", "esa", "para", "nada", "muy", "poco", "mucho", "mismo", "como", "que", "de", "en", "a", "el", "la", "un", "sin", "con", "aquí", "ahí", "fuera", "casa", "siempre", "también", "probando", "haciendo", "pensando", "buscando", "mirando", "usando", "intentando"},
    "it": {"una", "tutta", "questa", "quella", "per", "nella", "nel", "a", "da", "in", "il", "la", "lo", "un", "con", "senza", "che", "come", "molto", "poco", "proprio", "davvero", "sempre", "ancora", "qui", "lì", "fuori", "casa", "anche", "io", "stata", "stato"},
    "fr": {"une", "toute", "cette", "pour", "la", "le", "un", "à", "en", "de", "dans", "avec", "sans", "que", "comme", "très", "trop", "peu", "si", "là", "ici", "toujours", "aussi", "encore", "pas", "plus", "partie", "restée", "resté"},
}
FIXED = {
    "pt": [r"\bobrigad[ao]\b", r"\bsozinh[ao]\b", r"\bdeterminad[ao]\b"],
    "es": [r"\bsol[ao]\b(?! una| un)", r"\bagradecid[ao]\b"],
    "it": [r"\bsola\b|\bsolo\b(?= io)", r"\bgrat[ao]\b"],
    "fr": [r"\bseule?\b", r"\bprête?\b"],
}

CTA = {
    "en": r"\b(follow|subscribe|comment|save this|save it|like|share|link in (my )?bio|let me know|tell me|drop a)\b",
    "pt": r"\b(me segu[ei]|segue|siga|seguir|comenta|comente|salva|salve|compartilh|curt[ae]|link na bio|me conta|conta aqui)\w*",
}
FOLLOW = {"en": r"\bfollow\b", "pt": r"\b(me segu[ei]|segue|siga|seguir|segue o perfil|segue a página)\w*"}


def language(case_id):
    return case_id.split("-")[0]


def blocks(text):
    return [part.strip() for part in re.split(r"\n\s*\n", text or "") if part.strip()]


def first_sentence(text):
    clean = re.sub(r"\[[^\]]*\]", "", text or "").strip()
    match = re.search(r"^.*?[.!?¿¡]+(?=\s|$)", clean, re.S)
    return (match.group(0) if match else clean[:160]).strip()


def gender_hits(text, lang):
    found = []
    low = re.sub(r"\[[^\]]*\]", "", (text or "").lower())
    for match in re.finditer(PATTERNS[lang], low):
        word = match.group(1)
        if word in SKIP[lang] or len(word) < 4:
            continue
        kind = "F" if re.search(FEM[lang], word) else ("M" if re.search(MASC[lang], word) else None)
        if kind:
            start = max(0, match.start() - 30)
            found.append((kind, low[start:match.end() + 20].replace("\n", " ")))
    for pattern in FIXED[lang]:
        for match in re.finditer(pattern, low):
            word = match.group(0)
            kind = "F" if re.search(FEM[lang], word) else ("M" if re.search(MASC[lang], word) else None)
            if kind:
                start = max(0, match.start() - 30)
                found.append((kind, low[start:match.end() + 20].replace("\n", " ")))
    return found


rows = []
for sample in sorted(samples, key=lambda s: (s["caseID"], s["route"], s["ideaIndex"])):
    case, route, text = sample["caseID"], sample["route"], sample.get("text") or ""
    lang = language(case)
    row = {"case": case, "route": route, "model": sample.get("model"), "i": sample["ideaIndex"], "s": round(sample["seconds"], 1),
           "words": len(re.sub(r"\[[^\]]*\]", "", text).split()), "failure": sample.get("failure")}
    if case.endswith("woman"):
        hits = gender_hits(text, lang)
        row["F"] = sum(1 for h in hits if h[0] == "F")
        row["M"] = sum(1 for h in hits if h[0] == "M")
        row["hits"] = hits
    else:
        last = blocks(text)[-1] if blocks(text) else ""
        row["last"] = last[:220].replace("\n", " ")
        row["cta_in_last"] = bool(re.search(CTA[lang], last.lower()))
        row["follow_in_last"] = bool(re.search(FOLLOW[lang], last.lower()))
        opening = first_sentence(text)
        row["opening"] = opening[:160]
        row["opens_with_question"] = "?" in opening
        phrase = "here's the thing" if lang == "en" else "bora lá"
        row["catchphrase"] = phrase in text.lower().replace("’", "'")
    rows.append(row)

print(json.dumps(rows, ensure_ascii=False, indent=1))
