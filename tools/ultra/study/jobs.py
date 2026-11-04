#!/usr/bin/env python3
"""Writes the Ultra study's jobs.json (read by Cue StudioTests/UltraStudy/UltraStudyTests.swift): every case of a cases file crossed with
the chosen configurations (configs.json), prompt variants, length policies and repetitions. A job's id names all of it, so the test's
resume (a saved job is not written again) and the reports group by it.

    tools/ultra/study/jobs.py --cases tools/ultra/study/cases/phase1.json --configs A,B,C,D,E,F,G --phase p1 --out <study folder>/jobs.json

Several calls with --append build one jobs.json out of several crossings (e.g. variants only on the cases that have a brief).
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VARIANTS = {"formatFull", "angleKind", "autoFull", "titleKeep", "titleSubtitle"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", required=True)
    parser.add_argument("--configs", required=True, help="comma-separated ids of configs.json")
    parser.add_argument("--phase", required=True, help="prefix of every job id (p1, p2…)")
    parser.add_argument("--variants", default="", help="comma-separated variant sets; '+' joins variants in one set, '-' is none")
    parser.add_argument("--length", default="", help="kind:low-high, e.g. ideal:120-150 (empty keeps the app's policy)")
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--only", default="", help="comma-separated case ids (default all)")
    parser.add_argument("--briefs-only", action="store_true", help="only cases that came from the card or Find inspiration")
    parser.add_argument("--out", required=True)
    parser.add_argument("--append", action="store_true")
    args = parser.parse_args()

    cases = json.load(open(args.cases))
    configs = json.load(open(os.path.join(HERE, "configs.json")))
    chosen = [c.strip() for c in args.configs.split(",") if c.strip()]
    unknown = [c for c in chosen if c not in configs]
    if unknown:
        sys.exit(f"Unknown configs: {unknown}")
    only = {c for c in args.only.split(",") if c}
    variant_sets = parse_variants(args.variants)
    length = parse_length(args.length)

    jobs = json.load(open(args.out)) if args.append and os.path.exists(args.out) else []
    seen = {j["id"] for j in jobs}
    for case in cases:
        if only and case["id"] not in only:
            continue
        if args.briefs_only and not case.get("brief"):
            continue
        for config_id in chosen:
            config = {k: v for k, v in configs[config_id].items() if k != "label"}
            for variants in variant_sets:
                for repetition in range(args.repetitions):
                    parts = [args.phase, case["id"], config_id]
                    if variants:
                        parts.append("+".join(variants))
                    if length:
                        parts.append(f"{length['kind']}{int(length['low'] or 0)}-{int(length['high'] or 0)}")
                    if args.repetitions > 1:
                        parts.append(f"r{repetition}")
                    job_id = "_".join(parts)
                    if job_id in seen:
                        continue
                    seen.add(job_id)
                    jobs.append({
                        "id": job_id, "case": normalized(case), "config": {"id": config_id, **config}, "variants": variants,
                        "length": length, "repetition": repetition,
                    })
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(jobs, f, ensure_ascii=False, indent=1)
    print(f"{len(jobs)} jobs in {args.out}")


def normalized(case):
    """The case as UltraStudyJob.Case decodes it: every optional key present."""
    return {
        "id": case["id"], "language": case["language"], "creator": case["creator"], "voice": case["voice"],
        "idea": case.get("idea"), "brief": case.get("brief"), "platform": case["platform"], "format": case.get("format", "auto"),
        "length": case.get("length", "auto"), "brand": case.get("brand"),
    }


def parse_variants(text):
    if not text:
        return [[]]
    sets = []
    for chunk in text.split(","):
        chunk = chunk.strip()
        if chunk in ("", "-"):
            sets.append([])
            continue
        names = chunk.split("+")
        bad = [n for n in names if n not in VARIANTS]
        if bad:
            sys.exit(f"Unknown variants: {bad}")
        sets.append(names)
    return sets


def parse_length(text):
    if not text:
        return None
    kind, _, span = text.partition(":")
    if kind == "free":
        return {"kind": "free", "low": None, "high": None}
    low, _, high = span.partition("-")
    return {"kind": kind, "low": float(low), "high": float(high)}


if __name__ == "__main__":
    main()
