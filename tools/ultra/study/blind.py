#!/usr/bin/env python3
"""Blind judging packets for the Ultra study: one per case, with the context the app sent (the draft prompt it built, plus how the creator
speaks, which only the polish gets) and every script written for that case under a random label, in a random order that differs for each
judge. The key (label → job) is written apart, in <folder>/judging/keys/<judge>.json, and never shown to a judge.

    tools/ultra/study/blind.py <study folder> --judges claude,agent1,agent2 [--configs A,B,…] [--variants -,formatFull] [--seed 7]
                               [--judging judging-formats] [--titles] [--context-config F]

Packets: <folder>/<judging>/packets/<judge>/<case>.md. Judges write <folder>/<judging>/results/<judge>/<case>.json (rubric.md, "Judge
output"). --variants keeps the jobs whose variant set is one of the listed ones ('-' is none, '+' joins two). When the scripts of a packet
were asked for different lengths, the context says so and each script's header gives its own asked range. --titles shows each script's
title (the title packets of title-rubric.md); a subtitle job shows the idea's title with its subtitle, as the app would. --context-config
takes the context from that configuration's script when the packet has one (phase 4 mixes the app's code before and after the study's
changes, whose prompts differ: the judges see one request for all, not the definitions only one side got).

Apple Intelligence's records (apple_run.py) carry the writer's standing instructions, shown in the context (the creator's voice is there),
and on Auto ask for no length: --targets <json> gives, by case, the words the creator expects ("low to high", the request's own range),
shown in place of a free length.
"""
import argparse
import glob
import json
import os
import random
import re

LABELS = ["K", "M", "P", "R", "T", "V", "X", "Z", "H", "N", "Q", "W"]
# Words a minute at a natural pace, by language (`ReadTime.pace(for:)`: 150 in English times the language's share).
PACE_SHARE = {"ko": 0.75, "tr": 0.8, "id": 0.85, "ar": 0.9, "es": 1.1, "hi": 1.1, "nb": 1.1, "nl": 1.1, "zh": 1.1, "fr": 1.15, "vi": 1.15}


def pace(language):
    return 150 * PACE_SHARE.get(language[:2], 1)


def delivery_section(record):
    """The "How the creator speaks" section of the polish prompt (only the polish gets it), or "" when the voice is off."""
    for call in record.get("calls", []):
        if call["stage"] == "review":
            match = re.search(r"How the creator speaks \(.*?\):\n(.*?)(?:\n\n[A-Z\"]|\Z)", call["prompt"], re.S)
            return match.group(1).strip() if match else ""
    return ""


TARGETS = {}


def asked(record):
    """The words the app's length line asks for, as "low to high" (Ultra's "about … words", Apple Intelligence's "between … spoken words"),
    or None when the length is free."""
    match = re.search(r"about (\d+) to (\d+) words", record["appDraftPrompt"]) \
        or re.search(r"between (\d+) and (\d+) spoken words", record["appDraftPrompt"])
    return f"{match.group(1)} to {match.group(2)}" if match else None


def apple_target(record):
    """An Apple Intelligence script's words to judge against: the seconds its request was written to at a natural pace, never the words
    the request named (the device is asked for up to 1.5× what the seconds hold, `ScriptPromptBuilder.askedRange`, because it writes about
    half; Private Cloud Compute near the top). A window job on Auto: its window; any other: the case's own range (--targets)."""
    case = record["job"]["case"]
    window = re.search(r"w(\d+)-(\d+)$", record["job"]["config"]["id"])
    if window and case.get("length", "auto") == "auto":
        rate = pace(case["language"]) / 60
        return f"{round(int(window.group(1)) * rate)} to {round(int(window.group(2)) * rate)}"
    return TARGETS.get(case["id"])


def expected(record):
    """What the script is judged against, and whether the writer was told a length: the words asked for, or the case's own range when the
    writer was given none (--targets)."""
    told = asked(record) is not None
    if record.get("instructions"):
        return apple_target(record), told
    return (asked(record) if told else TARGETS.get(record["job"]["case"]["id"])), told


def shown_title(record):
    if "titleSubtitle" in (record["job"].get("variants") or []):
        subject = (record["job"]["case"].get("brief") or {}).get("subject", "")
        return f"{subject}  /  subtitle: {record.get('title', '')}"
    return record.get("title", "")


def context(record, mixed_lengths=False):
    draft = record["appDraftPrompt"]
    if mixed_lengths:
        draft = re.sub(r"^(Length: |Platform duration is informational).*$",
                       "Length: differs per script in this packet; each script's header gives the words it is judged against.", draft, flags=re.M)
    speaks = delivery_section(record)
    parts = ["## What the app sent the writer (verbatim)", "```", draft, "```"]
    if record.get("instructions"):
        parts += ["", "## The writer's standing instructions, with the creator's voice (verbatim)", "```", record["instructions"], "```"]
    elif speaks:
        parts += ["", "## How the creator speaks (sent only to the final polish)", "```", speaks, "```"]
    else:
        parts += ["", "(No delivery notes: the creator's voice is off or has none.)"]
    return "\n".join(parts)


def words(text):
    return len([w for w in re.split(r"\s+", text.strip()) if re.search(r"\w", w)])


def app_words(folder):
    """The app's own word counts (appwords.swift), which segment Japanese, Chinese and Thai; empty when they weren't made."""
    path = os.path.join(folder, "appwords.json")
    return json.load(open(path)) if os.path.exists(path) else {}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--judges", required=True)
    parser.add_argument("--configs", default="")
    parser.add_argument("--variants", default="", help="comma-separated variant sets to keep ('-' is none, '+' joins two)")
    parser.add_argument("--judging", default="judging", help="folder of packets, keys and results inside the study folder")
    parser.add_argument("--titles", action="store_true", help="show each script's title")
    parser.add_argument("--lengths", default="", help="comma-separated length overrides to keep, as metrics names them (ideal75-105)")
    parser.add_argument("--cases", default="")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--context-config", default="", help="the configuration whose prompt the context shows (default a random one)")
    parser.add_argument("--targets", default="", help="JSON of case → \"low to high\" words, for scripts written with a free length")
    args = parser.parse_args()
    if args.targets:
        TARGETS.update(json.load(open(args.targets)))

    records = [json.load(open(p)) for p in sorted(glob.glob(os.path.join(args.folder, "out", "*.json")))]
    configs = {c for c in args.configs.split(",") if c}
    cases = {c for c in args.cases.split(",") if c}
    variant_sets = {v for v in args.variants.split(",") if v}
    lengths = {v for v in args.lengths.split(",") if v}
    by_case = {}
    for record in records:
        job = record["job"]
        if record.get("outcome") != "ok":
            continue
        if configs and job["config"]["id"] not in configs:
            continue
        if variant_sets and ("+".join(job.get("variants") or []) or "-") not in variant_sets:
            continue
        if cases and job["case"]["id"] not in cases:
            continue
        span = job.get("length") or {}
        if lengths and f"{span.get('kind', 'app')}{int(span.get('low') or 0)}-{int(span.get('high') or 0)}" not in lengths:
            continue
        by_case.setdefault(job["case"]["id"], []).append(record)

    counted = app_words(args.folder)
    judges = [j for j in args.judges.split(",") if j]
    rng = random.Random(args.seed)
    root = os.path.join(args.folder, args.judging)
    for judge in judges:
        os.makedirs(os.path.join(root, "packets", judge), exist_ok=True)
        os.makedirs(os.path.join(root, "results", judge), exist_ok=True)
        os.makedirs(os.path.join(root, "keys"), exist_ok=True)
        key_path = os.path.join(root, "keys", f"{judge}.json")
        key = json.load(open(key_path)) if os.path.exists(key_path) else {}
        for case_id, group in sorted(by_case.items()):
            order = group[:]
            rng.shuffle(order)
            labels = LABELS[:len(order)]
            rng.shuffle(labels)
            key[case_id] = {label: record["job"]["id"] for label, record in zip(labels, order)}
            first = next((r for r in order if r["job"]["config"]["id"] == args.context_config), order[0])
            language = first["job"]["case"]["language"]
            mixed = len({expected(r) for r in order}) > 1 or any(not expected(r)[1] and expected(r)[0] for r in order)
            lines = [f"# Packet {case_id}", "", context(first, mixed), "", "## Scripts", ""]
            for label, record in sorted(zip(labels, order), key=lambda pair: pair[0]):
                count = counted.get(record["job"]["id"]) or words(record["script"])
                target, told = expected(record)
                span = ("" if not mixed else f"; judged against {target} words, the length the writer was asked for" if told
                        else f"; the writer was given no length; the creator expects {target} words" if target else "; a free length")
                lines += [f"### Script {label}  ({count} words, about {round(count / pace(language) * 60)} s at a natural pace{span})", ""]
                if args.titles:
                    lines += [f"Title: {shown_title(record)}", ""]
                lines += [record["script"].strip(), ""]
            with open(os.path.join(root, "packets", judge, f"{case_id}.md"), "w") as f:
                f.write("\n".join(lines))
        with open(key_path, "w") as f:
            json.dump(key, f, indent=1)
    print(f"{len(by_case)} packets for {len(judges)} judges in {root}")


if __name__ == "__main__":
    main()
