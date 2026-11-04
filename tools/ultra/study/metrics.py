#!/usr/bin/env python3
"""Deterministic measures of every script the Ultra study wrote (out/*.json from UltraStudyTests), next to the judges' reading: length and
whether it fits the asked range, list shape (the "primeiro… segundo… terceiro…" habit), AI tics ("não é X, é Y", triads, dashes, stock
phrases), calls to action, the creator's catchphrase and narrator, numbers the request never gave, repetition, sentence rhythm, the opening
line and the literal words kept, accents lost, how far the title moved from the card's, and what each script cost and took.

    tools/ultra/study/metrics.py <study folder>                 writes <study folder>/metrics.json and prints a table per configuration
    tools/ultra/study/metrics.py <study folder> --by case       the table per case
    tools/ultra/study/metrics.py <study folder> --job <id>      every measure of one job
"""
import argparse
import difflib
import glob
import json
import math
import os
import re
import statistics
import unicodedata
from collections import Counter, defaultdict

# USD per million tokens (Claude API, 11/2026; claude-api skill). Thinking is billed inside output tokens.
PRICES = {
    "claude-opus-5-5": {"input": 4.0, "cache": 0.20 * 2, "output": 20.0},
    "claude-sonnet-5-5": {"input": 2.0, "cache": 0.10 * 2, "output": 10.0},
}
# Words a minute at a natural pace (ReadTime: 150 × pace for the language).
PACE = {"pt-BR": 150, "en-US": 150, "es-ES": 165}
# The other languages' pace as a share of English's 150 words a minute (`ReadTime.pace(for:)`); the measures of style below exist in
# Portuguese, English and Spanish only, so the other languages get the length and cost measures alone.
PACE_SHARE = {"ko": 0.75, "tr": 0.8, "id": 0.85, "ar": 0.9, "es": 1.1, "hi": 1.1, "nb": 1.1, "nl": 1.1, "zh": 1.1, "fr": 1.15, "vi": 1.15}
# Words as the app counts them (`tools/ultra/study/appwords.swift`: by word for languages written without spaces), when the folder has them.
APP_WORDS = {}
# By case, the words a script written with a free length is measured against (apple_run.py folders: `targets.json`, "low to high").
TARGETS = {}


def pace(language):
    return PACE.get(language) or 150 * PACE_SHARE.get(language[:2], 1)
CATCHPHRASES = {
    "pt-beauty": "Fala, galera!", "en-fitness": "Okay, real talk.", "es-ceramics": "Hola, familia.", "pt-money": "Bora lá",
    "pt-filming": "Simbora", "pt-cooking": "Olha que delícia",
}
SPEAKS_AS_WE = {"es-ceramics"}

ORDINALS = {
    "pt": r"\b(primeir[oa]|segund[oa]|terceir[oa]|quart[oa]|quint[oa]|em primeiro lugar|em segundo lugar|por último|número (um|dois|três)|dica (número )?(um|dois|três|\d))\b",
    "en": r"\b(first(ly)?|second(ly)?|third(ly)?|fourth|fifth|number (one|two|three)|tip (number )?(one|two|three|\d)|step (one|two|three|\d)|last but not least)\b",
    "es": r"\b(primer[oa]?|segund[oa]|tercer[oa]?|cuart[oa]|quint[oa]|en primer lugar|en segundo lugar|por último|número (uno|dos|tres)|consejo (número )?(uno|dos|tres|\d))\b",
}
CONTRAST = {
    "pt": r"\bnão (é|são|foi|era|tem a ver com|se trata de)\b[^.!?\n]{1,70}?[,.;:]\s*(é|são|foi|era|tem a ver com|se trata de)\b",
    "en": r"\b(it'?s|this is|that'?s|it is|isn'?t|aren'?t|is not|are not)\b(?: not)?[^.!?\n]{1,70}?[,.;:]\s*(it'?s|it is|they'?re|it was)\b",
    "es": r"\bno (es|son|fue|era|se trata de)\b[^.!?\n]{1,70}?[,.;:]\s*(es|son|fue|era|se trata de)\b",
}
CTA = {
    "pt": r"\b(comenta|comente|comentário|segue|siga|me segue|salva|salve|compartilh\w*|curte|curta|me conta|me fala|deixa aqui|manda pra)\b",
    "en": r"\b(comment|follow|save this|share this|share it|like this|let me know|tell me|drop a)\b",
    "es": r"\b(comenta|coméntame|sígue\w*|síguenos|guarda|comparte|cuéntame|cuéntanos|dale like|déjanos|déjame)\b",
}
STOCK = {
    "pt": [r"\ba verdade é que\b", r"\bvamos combinar\b", r"\bsabe aquele\b", r"\bo segredo (é|está)\b", r"\bmuda tudo\b",
           r"\bvirar o jogo\b", r"\bno final das contas\b", r"\bpensa comigo\b", r"\bfaz sentido\?", r"\bé sobre isso\b",
           r"\bsimples assim\b", r"\bponto\.", r"\bisso mesmo\b", r"\bspoiler\b", r"\bplot twist\b"],
    "en": [r"\bhere'?s the thing\b", r"\bthe truth is\b", r"\bgame[- ]changer\b", r"\bthe secret is\b", r"\blet that sink in\b",
           r"\bat the end of the day\b", r"\bit'?s that simple\b", r"\bspoiler\b", r"\bplot twist\b", r"\bperiod\."],
    "es": [r"\bla verdad es que\b", r"\bel secreto (es|está)\b", r"\bcambia todo\b", r"\bal final del día\b", r"\basí de simple\b",
           r"\bspoiler\b", r"\bpunto\."],
}
UNACCENTED = {
    "pt": {"voce", "voces", "nao", "entao", "tambem", "porem", "alguem", "ninguem", "facil", "dificil", "rapido", "proprio", "propria",
           "saude", "agua", "unico", "unica", "ultimo", "ultima", "possivel", "otimo", "pratico", "codigo", "tres", "mae", "irma"},
    "es": {"tambien", "facil", "dificil", "rapido", "ultimo", "ultima", "unico", "unica", "aqui", "despues", "ademas", "mas facil",
           "porque es", "dias", "asi", "taza es"},
}
NUMBER_WORDS = {
    "pt": {"dois", "duas", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez", "onze", "doze", "quinze", "vinte", "trinta",
           "quarenta", "cinquenta", "cem", "cento", "mil", "milhão", "milhões", "metade", "dobro", "triplo", "terço"},
    "en": {"two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "twelve", "fifteen", "twenty", "thirty", "fifty",
           "hundred", "thousand", "million", "half", "double", "triple", "third", "quarter"},
    "es": {"dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "doce", "quince", "veinte", "treinta", "cincuenta",
           "cien", "ciento", "mil", "millón", "millones", "mitad", "doble", "triple", "tercio"},
}
STOPWORDS = set("""a o as os um uma de da do das dos e é em no na nos nas para pra por com que se seu sua meu minha the a an of to and in on for
with your my how why what is are el la los las un una y en con por para que su mi mis tus tu como por qué""".split())


def lang_of(record):
    return record["job"]["case"]["language"][:2]


def words(text):
    return [w for w in re.split(r"\s+", text.strip()) if re.search(r"\w", w)]


def sentences(text):
    parts = re.split(r"(?<=[.!?…])\s+|\n+", text.strip())
    return [p for p in parts if re.search(r"\w", p)]


def normalized(text):
    text = unicodedata.normalize("NFD", text.lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return re.sub(r"[^\w\s%]", " ", text)


def tokens(text):
    return [t for t in normalized(text).split() if t not in STOPWORDS]


def asked_range(record):
    """The words the app's length line asks for (from the draft prompt the app built), or None when the length is free."""
    prompt = record.get("appDraftPrompt", "")
    if record.get("instructions"):
        # Apple Intelligence: the seconds the request was written to (blind.py `apple_target`), never the inflated words it names.
        case = record["job"]["case"]
        window = re.search(r"w(\d+)-(\d+)$", record["job"]["config"]["id"])
        if window and case.get("length", "auto") == "auto":
            rate = pace(case["language"]) / 60
            return round(int(window.group(1)) * rate), round(int(window.group(2)) * rate)
        target = TARGETS.get(case["id"])
        return tuple(int(n) for n in target.split(" to ")) if target else None
    match = re.search(r"about (\d+) to (\d+) words", prompt)
    if not match and TARGETS.get(record["job"]["case"]["id"]):
        low, high = TARGETS[record["job"]["case"]["id"]].split(" to ")
        return int(low), int(high)
    return (int(match.group(1)), int(match.group(2))) if match else None


def request_text(record):
    case = record["job"]["case"]
    parts = [case.get("idea") or ""]
    if case.get("brief"):
        parts += [case["brief"]["subject"], case["brief"]["angle"], case["brief"]["openingLine"]]
    if case.get("brand"):
        parts += [str(v) for v in case["brand"].values()]
    return " ".join(parts)


def numbers_in(text, lang):
    found = set(re.findall(r"\d+(?:[.,]\d+)?\s?%?", text))
    found = {n.strip() for n in found}
    low = normalized(text).split()
    words_found = {w for w in low if normalized(w).strip() in {normalized(x).strip() for x in NUMBER_WORDS.get(lang, set())}}
    return found | words_found


def cost(calls):
    total = 0.0
    for call in calls:
        price = PRICES.get(call["model"])
        if not price or call.get("outcome") == "skipped":
            continue
        input_tokens = call.get("inputTokens") or 0
        cached = call.get("cacheReadTokens") or 0
        total += (input_tokens - cached) * price["input"] / 1e6 + cached * price["cache"] / 2 / 1e6
        total += (call.get("outputTokens") or 0) * price["output"] / 1e6
    return total


def measure(record):
    job = record["job"]
    case = job["case"]
    lang = lang_of(record)
    script = record.get("script", "")
    out = {
        "id": job["id"], "case": case["id"], "config": job["config"]["id"], "variants": "+".join(job.get("variants") or []) or "-",
        "length": (job.get("length") or {}).get("kind", "app") + (f"{int(job['length']['low'])}-{int(job['length']['high'])}"
                                                                   if job.get("length") and job["length"].get("high") else ""),
        "repetition": job.get("repetition", 0), "language": case["language"], "voice": case["voice"], "platform": case["platform"],
        "format": case["format"], "angle": (case.get("brief") or {}).get("angleKind", "typed"), "outcome": record.get("outcome"),
    }
    calls = record.get("calls", [])
    out["cost"] = round(cost(calls), 5)
    out["calls"] = sum(1 for c in calls if c.get("outcome") != "skipped")
    out["seconds"] = round(record.get("seconds", 0), 1)
    out["attempts_extra"] = sum(max(0, (c.get("attempts") or 1) - 1) for c in calls)
    out["output_tokens"] = sum(c.get("outputTokens") or 0 for c in calls)
    out["input_tokens"] = sum(c.get("inputTokens") or 0 for c in calls)
    out["stage_tokens"] = {c["stage"]: c.get("outputTokens") for c in calls}
    out["fit"] = any(c["stage"] == "fit" and c.get("outcome") == "ok" for c in calls)
    if out["outcome"] != "ok":
        return out

    w = words(script)
    count = APP_WORDS.get(job["id"]) or len(w)
    out["words"] = count
    out["seconds_spoken"] = round(count / pace(case["language"]) * 60)
    span = asked_range(record)
    out["range_words"] = span
    if span:
        low, high = span
        out["in_range"] = low <= count <= high
        out["off_range_pct"] = round(100 * (max(0, low - count) + max(0, count - high)) / high, 1)
    out["words_draft"] = len(words(record.get("draft", "")))
    out["words_before_fit"] = len(words(record["beforeFit"])) if record.get("beforeFit") else None

    if lang not in ORDINALS:
        return out
    low_text = script.lower()
    paragraphs = [p for p in script.split("\n\n") if p.strip()]
    out["paragraphs"] = len(paragraphs)
    ordinal_hits = re.findall(ORDINALS[lang], low_text)
    out["ordinals"] = len(ordinal_hits)
    numbered = sum(1 for p in paragraphs if re.match(r"^\s*(\d+[.)º°]|#\d)", p))
    out["list_shape"] = len(ordinal_hits) >= 2 or numbered >= 2
    out["contrast_not_x_y"] = len(re.findall(CONTRAST[lang], low_text))
    out["triads"] = len(re.findall(r"\b[\wÀ-ÿ]+(?: [\wÀ-ÿ]+){0,2}, [\wÀ-ÿ]+(?: [\wÀ-ÿ]+){0,2},? (?:e|and|y) [\wÀ-ÿ]+", script))
    out["dashes"] = script.count("—") + script.count(" – ")
    out["stock_phrases"] = [p for p in STOCK[lang] if re.search(p, low_text)]
    sents = sentences(script)
    questions = [s for s in sents if s.strip().endswith("?")]
    out["questions"] = len(questions)
    last = paragraphs[-1].lower() if paragraphs else ""
    out["ends_with_question"] = last.strip().endswith("?")
    out["cta_last_paragraph"] = bool(re.search(CTA[lang], last))
    out["cta_anywhere"] = len(re.findall(CTA[lang], low_text))

    phrase = CATCHPHRASES.get(case["creator"])
    if phrase and case["voice"] != "none":
        core = normalized(phrase).strip()
        out["catchphrase"] = normalized(script).count(core)
    tokens_lower = re.findall(r"[\wÀ-ÿ']+", low_text)
    first_singular = {"pt": {"eu", "meu", "minha", "meus", "minhas", "comigo"}, "en": {"i", "my", "me", "mine", "i'm", "i've"},
                      "es": {"yo", "mi", "mis", "conmigo"}}[lang]
    first_plural = {"pt": {"nós", "nosso", "nossa", "nossos", "nossas"}, "en": {"we", "our", "us", "we're", "we've"},
                    "es": {"nosotros", "nosotras", "nuestro", "nuestra", "nuestros", "nuestras"}}[lang]
    out["i_words"] = sum(1 for t in tokens_lower if t in first_singular)
    out["we_words"] = sum(1 for t in tokens_lower if t in first_plural)
    if case["voice"] != "none":
        out["narrator_ok"] = (out["i_words"] <= 1) if case["creator"] in SPEAKS_AS_WE else (out["we_words"] <= out["i_words"] + 2)

    given = numbers_in(request_text(record), lang)
    out["new_numbers"] = sorted(n for n in numbers_in(script, lang) if n not in given)

    grams = Counter(tuple(tokens_lower[i:i + 4]) for i in range(len(tokens_lower) - 3))
    out["repeated_4grams"] = sum(c - 1 for c in grams.values() if c > 1)
    lengths = [len(words(s)) for s in sents]
    out["sentence_mean"] = round(statistics.mean(lengths), 1) if lengths else 0
    out["sentence_sd"] = round(statistics.pstdev(lengths), 1) if len(lengths) > 1 else 0
    out["sentence_max"] = max(lengths) if lengths else 0

    brief = case.get("brief")
    if brief and brief.get("openingLine"):
        opening = set(tokens(brief["openingLine"]))
        head = set(tokens(" ".join(w[:max(25, len(brief['openingLine'].split()) + 8)])))
        out["opening_kept"] = round(len(opening & head) / max(1, len(opening)), 2)
    literal = re.findall(r"[\"“]([^\"”]+)[\"”]", case.get("idea") or "")
    brand = case.get("brand") or {}
    must = [x for x in literal + [brand.get("mustSay", ""), brand.get("link", ""), brand.get("code", "")] if x]
    if must:
        out["literal_kept"] = [m for m in must if normalized(m).strip() in normalized(script)]
        out["literal_missing"] = [m for m in must if normalized(m).strip() not in normalized(script)]
    if brand.get("neverSay"):
        out["never_say_hit"] = "substitui o fogão" in low_text or "substitui o fogao" in low_text
    out["accent_losses"] = sorted({t for t in normalized_words(script) if t in UNACCENTED.get(lang, set())}
                                  - {t for t in normalized_words(request_text(record))})

    if brief:
        subject, title = brief["subject"], record.get("title", "")
        a, b = set(tokens(subject)), set(tokens(title))
        out["title"] = title
        out["title_jaccard"] = round(len(a & b) / max(1, len(a | b)), 2)
        out["title_ratio"] = round(difflib.SequenceMatcher(None, normalized(subject), normalized(title)).ratio(), 2)
        out["title_kind"] = ("same" if out["title_ratio"] > 0.9 else "close" if out["title_jaccard"] >= 0.4
                             else "shifted" if out["title_jaccard"] > 0 else "new")
    else:
        out["title"] = record.get("title", "")
    return out


def normalized_words(text):
    """Words as written (accents kept), lower-cased: an accent the model dropped shows as the word without it."""
    return set(re.findall(r"[a-zçãõáéíóúâêôàü]+", text.lower()))


def load(folder):
    records = []
    for path in sorted(glob.glob(os.path.join(folder, "out", "*.json"))):
        with open(path) as f:
            records.append(json.load(f))
    return records


def summarize(rows, key):
    groups = defaultdict(list)
    for row in rows:
        groups[row[key]].append(row)
    header = f"{key:<22}{'n':>4}{'ok':>4}{'USD':>8}{'s':>6}{'words':>7}{'range':>7}{'fit':>5}{'list':>6}{'ord':>6}{'notXY':>7}{'cta':>5}{'q?end':>6}{'new#':>6}{'title=':>7}"
    print(header)
    for name in sorted(groups):
        g = groups[name]
        ok = [r for r in g if r.get("outcome") == "ok"]

        def mean(field, rows=ok):
            values = [r[field] for r in rows if r.get(field) is not None]
            return statistics.mean(values) if values else float("nan")

        def share(field, rows=ok):
            values = [bool(r[field]) for r in rows if field in r]
            return 100 * sum(values) / len(values) if values else float("nan")

        titled = [r for r in ok if "title_kind" in r]
        same = 100 * sum(r["title_kind"] in ("same", "close") for r in titled) / len(titled) if titled else float("nan")
        print(f"{str(name):<22}{len(g):>4}{len(ok):>4}{mean('cost', g):>8.4f}{mean('seconds', g):>6.0f}{mean('words'):>7.0f}"
              f"{share('in_range'):>6.0f}%{share('fit'):>4.0f}%{share('list_shape'):>5.0f}%{mean('ordinals'):>6.1f}"
              f"{mean('contrast_not_x_y'):>7.2f}{share('cta_last_paragraph'):>4.0f}%{share('ends_with_question'):>5.0f}%"
              f"{statistics.mean([len(r.get('new_numbers', [])) for r in ok]) if ok else float('nan'):>6.2f}{same:>6.0f}%")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--by", default="config")
    parser.add_argument("--job")
    args = parser.parse_args()
    records = load(args.folder)
    counted = os.path.join(args.folder, "appwords.json")
    if os.path.exists(counted):
        APP_WORDS.update(json.load(open(counted)))
    targets = os.path.join(args.folder, "targets.json")
    if os.path.exists(targets):
        TARGETS.update(json.load(open(targets)))
    rows = [measure(r) for r in records]
    with open(os.path.join(args.folder, "metrics.json"), "w") as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)
    if args.job:
        for row in rows:
            if row["id"] == args.job:
                print(json.dumps(row, ensure_ascii=False, indent=1))
        return
    failed = glob.glob(os.path.join(args.folder, "failed", "*.json"))
    print(f"{len(rows)} scripts measured, {len(failed)} waiting to be written again (API failures)")
    summarize(rows, args.by)


if __name__ == "__main__":
    main()
