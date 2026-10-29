#!/usr/bin/env python3
"""Blind comparison of the scripts three engines wrote for the same ideas: `apple` (Apple Intelligence), `polished` (Ultra AI, draft and
polish) and `checked` (Ultra AI, draft, claim check and polish). A device run keeps one attachment per idea, `ultra-quality-<run>-<id>.json`.

  tools/ultra/compare.py collect <run> build/results/device-….xcresult [more.xcresult …]
      merges the ideas into research_notes/Ultra AI/quality-<run>.json, each engine with its `metrics`, and prints them
  tools/ultra/compare.py pairs <run> [--seed N]
      writes quality-<run>-pairs.json and quality-<run>-pairs.md (blind: no engine names) and quality-<run>-key.json (who is A and B)
  tools/ultra/compare.py score <run> <verdicts.json>
      joins a judge's verdicts with the key: wins, mean scores and errors per engine, also in quality-<run>-score-<verdicts>.json

An idea found in a later xcresult replaces the one of the same id from an earlier one; ideas already in the file are kept unless replaced.
Pairs: apple against checked for every idea with both texts; polished against checked for every technical idea with both texts.
The metrics are leads to read the texts with, never a verdict: seconds are words at 150 a minute, new numbers are numbers the request did
not supply (maybe invented, maybe common knowledge).

Verdicts: {"P01": {"winner": "A" | "B" | "tie", "scores": {"A": {"development": 1-5, …}, "B": {…}}, "errors": {"A": ["…"], "B": []}}, …}
"""

import argparse
import glob
import json
import os
import random
import re
import subprocess
import sys
import tempfile
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = os.path.join(ROOT, "research_notes", "Ultra AI")
ENGINES = ["apple", "polished", "checked"]
COMPARISONS = ["apple-vs-checked", "polished-vs-checked"]
CRITERIA = ["development", "fidelity", "voice", "naturalness", "accuracy", "length"]
WORDS_PER_MINUTE = 150

CTA = {
    "en": ["follow", "comment", "save this", "like", "subscribe", "share", "tell me"],
    "pt": ["segue", "siga", "comenta", "comente", "salva", "salve", "curte", "curta", "compartilha", "compartilhe", "me conta", "me conte"],
    "es": ["sígueme", "sigue", "síguenos", "comenta", "comenten", "guarda", "comparte", "dale like", "cuéntame"],
}
CTA_PATTERNS = {
    language: [(word, re.compile(r"(?<!\w)" + r"\s+".join(map(re.escape, word.split())) + r"(?!\w)", re.IGNORECASE)) for word in words]
    for language, words in CTA.items()
}
NUMBER = re.compile(r"(?<!\w)((?:R\$|US\$|\$|€|£)\s?)?(\d+(?:[.,]\d+)*)"
                    r"(\s?%|\s?€|\s+(?:por\s+cento|percent|per\s+cent|por\s+ciento)(?!\w))?", re.IGNORECASE)
SENTENCE = re.compile(r"[^.!?…？！。\n]+(?:[.!?…？！。]+|$)")
MARKDOWN_LINE = re.compile(r"^\s*(?:#{1,6}\s|[-*•]\s|\d+[.)]\s)")
CLOSERS = "\"'”’»«“‘)]"


def words(text):
    return len((text or "").split())


def estimated_seconds(count):
    return round(count / WORDS_PER_MINUTE * 60, 1)


def length_fit(seconds, asked):
    """"in", "short" or "long" for a required range, the ratio to a reference, None when the length was free or unreadable."""
    asked = (asked or "").strip()
    required = re.match(r"required\s+(\d+(?:\.\d+)?)\s*[–-]\s*(\d+(?:\.\d+)?)\s*s", asked)
    if required:
        low, high = float(required.group(1)), float(required.group(2))
        return "short" if seconds < low else "long" if seconds > high else "in"
    reference = re.match(r"reference\s+(\d+(?:\.\d+)?)\s*s", asked)
    if reference and float(reference.group(1)) > 0:
        return round(seconds / float(reference.group(1)), 2)
    return None


def sentences(text):
    return [s.strip() for s in SENTENCE.findall(text or "") if any(c.isalnum() for c in s)]


def trimmed_end(text):
    """The text without what may trail its last punctuation: spaces, quotes, emoji and other symbols."""
    text = (text or "").rstrip()
    while text and (text[-1].isspace() or text[-1] in CLOSERS or unicodedata.category(text[-1]).startswith(("S", "M", "Cf"))
                    or text[-1] == "️"):
        text = text[:-1]
    return text


def ends_with_question(text):
    return trimmed_end(text).endswith(("?", "？"))


def cta_in_ending(text, language):
    """The calls to action in the last two sentences, in the order they appear; None for a language without a list."""
    patterns = CTA_PATTERNS.get((language or "").split("-")[0].lower())
    if patterns is None:
        return None
    ending = " ".join(sentences(text)[-2:])
    found = sorted((match.start(), word) for word, pattern in patterns for match in pattern.finditer(ending))
    out = []
    for _, word in found:
        if word not in out:
            out.append(word)
    return out


def plain_words(text):
    kept = "".join(c if unicodedata.category(c)[0] in "LN" else " " for c in (text or "").lower())
    return kept.split()


def catchphrases(text, phrases):
    """How many times each creator phrase is said, its words in order, whatever the case and punctuation."""
    said = plain_words(text)
    out = {}
    for phrase in phrases or []:
        wanted = plain_words(phrase)
        size = len(wanted)
        out[phrase] = sum(1 for i in range(len(said) - size + 1) if said[i:i + size] == wanted) if size else 0
    return out


def em_dashes(text):
    return sum((text or "").count(dash) for dash in "—–")


def has_markdown(text):
    text = text or ""
    return "**" in text or "__" in text or any(MARKDOWN_LINE.match(line) for line in text.splitlines())


def number_core(match):
    return match.group(2).replace(",", ".")


def new_numbers(text, supplied):
    """The numbers in the text that none of the supplied texts (the idea, the brief, the creator line) has, deduplicated in order."""
    known = {number_core(m) for source in supplied if source for m in NUMBER.finditer(source)}
    out = []
    for match in NUMBER.finditer(text or ""):
        token = " ".join(match.group(0).split())
        if number_core(match) not in known and token not in out:
            out.append(token)
    return out


def title_issue(title):
    title = (title or "").strip()
    issues = []
    if not title:
        issues.append("empty")
    if words(title) > 8:
        issues.append("long")
    if title.endswith("."):
        issues.append("period")
    return ", ".join(issues) or None


def supplied_texts(idea):
    brief = idea.get("brief") or {}
    creator = idea.get("creator") or {}
    return [idea.get("idea"), brief.get("subject"), brief.get("angle"), brief.get("openingLine"), creator.get("summary")]


def metrics(engine, idea):
    """What can be counted in one engine's script for the idea; None when the engine wrote nothing."""
    text = engine.get("text")
    if not text:
        return None
    count = words(text)
    seconds = estimated_seconds(count)
    title = engine.get("title") or ""
    return {
        "words": count,
        "estimatedSeconds": seconds,
        "lengthFit": length_fit(seconds, idea.get("lengthAsked")),
        "endsWithQuestion": ends_with_question(text),
        "ctaInEnding": cta_in_ending(text, idea.get("language")),
        "catchphrases": catchphrases(text, (idea.get("creator") or {}).get("phrases")),
        "emDashes": em_dashes(text),
        "markdown": has_markdown(text),
        "newNumbers": new_numbers(text, supplied_texts(idea)),
        "titleWords": words(title),
        "titleIssue": title_issue(title),
    }


def enrich(idea):
    engines = idea.get("engines") or {}
    for engine in engines.values():
        if isinstance(engine, dict):
            engine["metrics"] = metrics(engine, idea)
    return idea


def manifest_names(folder):
    path = os.path.join(folder, "manifest.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        manifest = json.load(handle)
    names = {}
    for test in manifest if isinstance(manifest, list) else []:
        for attachment in test.get("attachments", []):
            if "exportedFileName" in attachment:
                names[attachment["exportedFileName"]] = attachment.get("suggestedHumanReadableName", "")
    return names


def read_export(folder, run):
    """The ideas of the run among the attachments exported into a folder, named through the export's manifest."""
    names = manifest_names(folder)
    for path in sorted(glob.glob(os.path.join(folder, "*.json"))):
        file = os.path.basename(path)
        if file == "manifest.json":
            continue
        if names and not names.get(file, "").startswith("ultra-quality-" + run + "-"):
            continue
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict) and data.get("run") == run and "id" in data and "engines" in data:
            yield data


def attachments(result, run):
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", folder],
                       check=True, capture_output=True)
        yield from read_export(folder, run)


def path_for(folder, run, suffix=""):
    return os.path.join(folder, "quality-" + run + suffix + ".json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def merge(existing, found):
    ideas = {idea["id"]: idea for idea in existing}
    for idea in found:
        ideas[idea["id"]] = idea
    return [enrich(ideas[key]) for key in sorted(ideas)]


def collect(run, results, folder=FOLDER, read=attachments):
    path = path_for(folder, run)
    existing = load(path) if os.path.exists(path) else []
    found = [idea for result in results for idea in read(result, run)]
    ideas = merge(existing, found)
    save(path, ideas)
    print(f"{len(found)} ideas read, {len(ideas)} in {os.path.relpath(path, ROOT)}")
    print(table(ideas))
    return ideas


def table(ideas):
    lines = [f"{'id':<28}{'engine':<10}{'words':>6}{'≈ s':>7}{'fit':>7}{'?':>3}  {'cta':<18}{'catch':>6}{'new#':>5}  failure"]
    for idea in ideas:
        for name in ENGINES:
            engine = (idea.get("engines") or {}).get(name)
            if engine is None:
                continue
            m = engine.get("metrics")
            if not m:
                lines.append(f"{idea['id']:<28}{name:<10}{'–':>6}{'–':>7}{'–':>7}{'–':>3}  {'–':<18}{'–':>6}{'–':>5}  "
                             f"{engine.get('failure') or 'no text'}")
                continue
            fit = m["lengthFit"]
            fit = "–" if fit is None else f"{fit:.2f}" if isinstance(fit, float) else fit
            cta = "–" if m["ctaInEnding"] is None else ",".join(m["ctaInEnding"]) or "no"
            lines.append(f"{idea['id']:<28}{name:<10}{m['words']:>6}{m['estimatedSeconds']:>7.1f}{fit:>7}"
                         f"{'y' if m['endsWithQuestion'] else 'n':>3}  {cta[:17]:<18}{sum(m['catchphrases'].values()):>6}"
                         f"{len(m['newNumbers']):>5}  {engine.get('failure') or ''}")
    return "\n".join(lines)


def has_text(idea, name):
    engine = (idea.get("engines") or {}).get(name)
    return bool(engine and engine.get("text"))


def build_pairs(ideas, seed=29):
    """Blind pairs, shuffled with the seed, and the key that tells which engine wrote A and B."""
    candidates = []
    for idea in sorted(ideas, key=lambda i: i["id"]):
        if has_text(idea, "apple") and has_text(idea, "checked"):
            candidates.append((idea, "apple-vs-checked", "apple", "checked"))
        if idea.get("kind") == "technical" and has_text(idea, "polished") and has_text(idea, "checked"):
            candidates.append((idea, "polished-vs-checked", "polished", "checked"))
    rng = random.Random(seed)
    rng.shuffle(candidates)
    pairs, key = [], {}
    for number, (idea, comparison, first, second) in enumerate(candidates, 1):
        name = f"P{number:02d}"
        a, b = (first, second) if rng.random() < 0.5 else (second, first)
        engines = idea["engines"]
        pairs.append({
            "pair": name, "id": idea["id"], "language": idea.get("language"), "platform": idea.get("platform"),
            "lengthAsked": idea.get("lengthAsked"), "idea": idea.get("idea"), "brief": idea.get("brief"),
            "creator": idea.get("creator"), "context": idea.get("context"),
            "A": {"title": engines[a].get("title"), "text": engines[a]["text"]},
            "B": {"title": engines[b].get("title"), "text": engines[b]["text"]},
        })
        key[name] = {"comparison": comparison, "A": a, "B": b, "id": idea["id"], "kind": idea.get("kind"),
                     "language": idea.get("language")}
    return pairs, key


def creator_line(creator):
    if not creator:
        return "no voice given"
    parts = [creator.get("summary") or ""]
    for label, field in (("phrases", "phrases"), ("openings", "openings"), ("endings", "endings")):
        if creator.get(field):
            parts.append(label + ": " + "; ".join(creator[field]))
    return " | ".join(p for p in parts if p)


def render_markdown(run, pairs):
    out = [f"# Blind pairs, run {run}", "",
           "Each pair is two scripts written for the same request. Judge them side by side; the sides are in random order.", ""]
    for pair in pairs:
        out += [f"## {pair['pair']}", "",
                f"- **Request:** {pair.get('idea') or ''}",
                f"- **Language and platform:** {pair.get('language') or ''}, {pair.get('platform') or ''}",
                f"- **Length asked:** {pair.get('lengthAsked') or ''}",
                f"- **Creator:** {creator_line(pair.get('creator'))}"]
        brief = pair.get("brief")
        if brief:
            out.append(f"- **Brief:** {brief.get('subject') or ''} / {brief.get('angle') or ''} / "
                       f"opening line: {brief.get('openingLine') or ''}")
        if pair.get("context"):
            out += ["", "**Context:**", "", "```", pair["context"].strip(), "```"]
        for side in ("A", "B"):
            out += ["", f"### Script {side}", "", f"**{pair[side].get('title') or '(no title)'}**", "", pair[side]["text"].strip()]
        out.append("")
    return "\n".join(out)


def revealing(pairs):
    """Pairs whose texts name an engine, to be read before a judge sees them."""
    pattern = re.compile(r"gemini|ultra ai|apple intelligence", re.IGNORECASE)
    return [pair["pair"] for pair in pairs if pattern.search(json.dumps(pair, ensure_ascii=False))]


def make_pairs(run, seed=29, folder=FOLDER):
    ideas = load(path_for(folder, run))
    pairs, key = build_pairs(ideas, seed)
    save(path_for(folder, run, "-pairs"), pairs)
    save(path_for(folder, run, "-key"), key)
    with open(os.path.join(folder, "quality-" + run + "-pairs.md"), "w", encoding="utf-8") as handle:
        handle.write(render_markdown(run, pairs))
    counts = {c: sum(1 for k in key.values() if k["comparison"] == c) for c in COMPARISONS}
    print(f"{len(pairs)} pairs ({', '.join(f'{c} {n}' for c, n in counts.items())}), seed {seed}, in {os.path.relpath(folder, ROOT)}")
    for name in revealing(pairs):
        print(f"warning: {name} names an engine in its texts")
    return pairs, key


def tally():
    return {"pairs": 0, "tie": 0}


def summarize(verdicts, key):
    """Wins and ties per comparison (all, by kind, by language), mean scores per engine and the errors each engine was given."""
    comparisons = {c: {"all": tally(), "kind": {}, "language": {}} for c in COMPARISONS}
    sums = {}
    errors = {}
    for name in sorted(verdicts):
        verdict, entry = verdicts[name], key.get(name)
        if entry is None:
            continue
        winner = verdict.get("winner")
        if winner not in ("A", "B", "tie"):
            raise ValueError(f"{name}: winner must be A, B or tie, not {winner!r}")
        comparison = comparisons.setdefault(entry["comparison"], {"all": tally(), "kind": {}, "language": {}})
        for bucket in (comparison["all"], comparison["kind"].setdefault(entry.get("kind") or "?", tally()),
                       comparison["language"].setdefault(entry.get("language") or "?", tally())):
            bucket["pairs"] += 1
            label = "tie" if winner == "tie" else entry[winner]
            bucket[label] = bucket.get(label, 0) + 1
        for side in ("A", "B"):
            engine = entry[side]
            for criterion, value in ((verdict.get("scores") or {}).get(side) or {}).items():
                if isinstance(value, (int, float)) and not isinstance(value, bool):
                    for group in (entry["comparison"], "all"):
                        cell = sums.setdefault(group, {}).setdefault(engine, {}).setdefault(criterion, [0, 0])
                        cell[0] += value
                        cell[1] += 1
            for error in ((verdict.get("errors") or {}).get(side) or []):
                errors.setdefault(engine, []).append({"pair": name, "id": entry.get("id"), "error": error})
    scores = {group: {engine: {criterion: {"mean": round(total / count, 2), "n": count} for criterion, (total, count) in criteria.items()}
                      for engine, criteria in engines.items()} for group, engines in sums.items()}
    return {
        "judged": sum(c["all"]["pairs"] for c in comparisons.values()),
        "missing": sorted(set(key) - set(verdicts)),
        "unknown": sorted(set(verdicts) - set(key)),
        "comparisons": comparisons,
        "scores": scores,
        "errors": errors,
    }


def wins_line(label, bucket, engines):
    parts = [f"{engine} {bucket.get(engine, 0)}" for engine in engines] + [f"tie {bucket.get('tie', 0)}"]
    return f"  {label:<14}" + "  ".join(f"{p:<12}" for p in parts) + f"({bucket['pairs']} pairs)"


def report(summary):
    lines = [f"{summary['judged']} pairs judged"]
    if summary["missing"]:
        lines.append("no verdict: " + ", ".join(summary["missing"]))
    if summary["unknown"]:
        lines.append("not in the key: " + ", ".join(summary["unknown"]))
    for name, comparison in summary["comparisons"].items():
        if not comparison["all"]["pairs"]:
            continue
        engines = name.split("-vs-")
        lines += ["", name, wins_line("all", comparison["all"], engines)]
        for group in ("kind", "language"):
            for label in sorted(comparison[group]):
                lines.append(wins_line(label, comparison[group][label], engines))
    for group, engines in summary["scores"].items():
        criteria = CRITERIA + sorted({c for e in engines.values() for c in e} - set(CRITERIA))
        lines += ["", f"mean scores, {group}", f"  {'engine':<10}" + "".join(f"{c[:11]:>12}" for c in criteria)]
        for engine in ENGINES:
            if engine in engines:
                cells = [engines[engine].get(c) for c in criteria]
                lines.append(f"  {engine:<10}" + "".join(f"{cell['mean']:>12.2f}" if cell else f"{'–':>12}" for cell in cells))
    for engine in ENGINES:
        if summary["errors"].get(engine):
            lines += ["", f"errors, {engine}"]
            lines += [f"  {e['pair']} {e['id']}: {e['error']}" for e in summary["errors"][engine]]
    return "\n".join(lines)


def score(run, verdicts_path, folder=FOLDER):
    summary = summarize(load(verdicts_path), load(path_for(folder, run, "-key")))
    stem = os.path.splitext(os.path.basename(verdicts_path))[0]
    summary = {"run": run, "verdicts": stem, **summary}
    save(path_for(folder, run, "-score-" + stem), summary)
    print(report(summary))
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("collect")
    command.add_argument("run")
    command.add_argument("results", nargs="+")
    command = commands.add_parser("pairs")
    command.add_argument("run")
    command.add_argument("--seed", type=int, default=29)
    command = commands.add_parser("score")
    command.add_argument("run")
    command.add_argument("verdicts")
    args = parser.parse_args(argv)
    if args.command == "collect":
        collect(args.run, args.results)
    elif args.command == "pairs":
        make_pairs(args.run, args.seed)
    else:
        score(args.run, args.verdicts)


if __name__ == "__main__":
    main(sys.argv[1:])
