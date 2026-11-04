#!/usr/bin/env python3
"""The Ultra study's scores: the judges' blind results (judging/results/<judge>/<case>.json) mapped back to their jobs (judging/keys), the
0–100 total of rubric.md, the judges' agreement (Krippendorff's α, interval), and each configuration against the reference with the
decision bar's numbers (paired bootstrap of the mean difference over cases, wins, redo rate, per-criterion drop, worst segment).

    tools/ultra/study/score.py <study folder> [--reference A] [--judges claude,agent1,agent2] [--segment angle] [--judging judging-formats]

An arm is a configuration with its prompt variants and length ("C", "C+formatFull", "A@ideal150-180"); every arm is compared with the
reference arm on the cases both have. Title packets (title-rubric.md) also get the mean of each title score per arm.
"""
import argparse
import glob
import json
import os
import random
import statistics
from collections import defaultdict

TITLE_SCORES = ["title_match", "title_quality", "delivers_title"]
CRITERIA = {"hook": 15, "substance": 20, "format": 15, "naturalness": 15, "voice": 15, "accuracy": 10, "ending": 5, "length": 5}


def total(scores):
    return sum(weight * (scores[name] - 1) / 4 for name, weight in CRITERIA.items())


def arm(row):
    """The configuration with its variants and length, as the comparisons name it."""
    name = row.get("config", "?")
    if row.get("variants", "-") != "-":
        name += "+" + row["variants"]
    if row.get("length", "app") != "app":
        name += "@" + row["length"]
    return name


def load(folder, judges, judging="judging"):
    """{judge: {job id: result}} for every result whose label the key knows."""
    root = os.path.join(folder, judging)
    out = {}
    for judge in judges:
        key_path = os.path.join(root, "keys", f"{judge}.json")
        if not os.path.exists(key_path):
            continue
        key = json.load(open(key_path))
        out[judge] = {}
        for path in glob.glob(os.path.join(root, "results", judge, "*.json")):
            result = json.load(open(path))
            case = result.get("packet") or os.path.splitext(os.path.basename(path))[0]
            labels = key.get(case, {})
            ranking = result.get("ranking", [])
            for label, scores in result.get("scripts", {}).items():
                job = labels.get(label)
                if not job:
                    continue
                entry = dict(scores)
                entry["total"] = total(scores)
                entry["rank"] = ranking.index(label) + 1 if label in ranking else None
                entry["of"] = len(ranking)
                out[judge][job] = entry
    return out


def alpha_interval(units):
    """Krippendorff's α for interval data. units: list of lists of the values the judges gave one unit (missing values left out)."""
    pairable = [u for u in units if len(u) >= 2]
    values = [v for u in pairable for v in u]
    n = len(values)
    if n < 2:
        return float("nan")
    observed = sum(sum((a - b) ** 2 for i, a in enumerate(u) for j, b in enumerate(u) if i != j) / (len(u) - 1) for u in pairable) / n
    expected = sum((a - b) ** 2 for i, a in enumerate(values) for j, b in enumerate(values) if i != j) / (n * (n - 1))
    return 1 - observed / expected if expected else float("nan")


def bootstrap(diffs, rounds=10000, seed=11):
    rng = random.Random(seed)
    means = sorted(statistics.mean(rng.choice(diffs) for _ in diffs) for _ in range(rounds))
    return means[int(0.025 * rounds)], means[int(0.975 * rounds) - 1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--reference", default="A")
    parser.add_argument("--judges", default="claude,agent1,agent2")
    parser.add_argument("--segment", default="")
    parser.add_argument("--judging", default="judging")
    args = parser.parse_args()

    judges = [j for j in args.judges.split(",") if j]
    results = load(args.folder, judges, args.judging)
    metrics = {m["id"]: m for m in json.load(open(os.path.join(args.folder, "metrics.json")))}
    jobs = sorted({job for judged in results.values() for job in judged})
    if not jobs:
        raise SystemExit("No judged scripts yet")

    # Agreement between the judges, on the total and on each criterion.
    print("Agreement (Krippendorff's α, interval), judges:", ", ".join(results))
    for field in ["total", *CRITERIA]:
        units = [[results[j][job][field] for j in results if job in results[j]] for job in jobs]
        print(f"  {field:<12}{alpha_interval(units):6.2f}   ({sum(1 for u in units if len(u) >= 2)} scripts)")
    # The decision compares configurations on the same case, judged by the same judges, so what has to agree is the difference between
    # scripts of one case: α with each judge's mean for that case removed (a judge's harshness and the case's difficulty cancel).
    by_case = defaultdict(list)
    for job in jobs:
        by_case[job.split("_")[1]].append(job)
    within = []
    for case_jobs in by_case.values():
        shared = [j for j in results if all(job in results[j] for job in case_jobs)]
        if len(shared) < 2:
            continue
        means = {j: statistics.mean(results[j][job]["total"] for job in case_jobs) for j in shared}
        within += [[results[j][job]["total"] - means[j] for j in shared] for job in case_jobs]
    print(f"  {'within case':<12}{alpha_interval(within):6.2f}   ({len(within)} scripts; the decision's measure)")

    # The consensus per script: the judges' mean.
    consensus = {}
    for job in jobs:
        given = [results[j][job] for j in results if job in results[j]]
        entry = {name: statistics.mean(g[name] for g in given) for name in [*CRITERIA, "total"]}
        verdicts = [g.get("verdict") for g in given]
        entry["redo"] = sum(v == "redo" for v in verdicts) / len(verdicts)
        entry["record"] = sum(v == "record" for v in verdicts) / len(verdicts)
        entry["flags"] = sorted({f for g in given for f in g.get("flags", [])})
        entry["judges"] = len(given)
        for name in TITLE_SCORES:
            marks = [g[name] for g in given if isinstance(g.get(name), (int, float))]
            if marks:
                entry[name] = statistics.mean(marks)
        consensus[job] = entry

    by_config = defaultdict(dict)
    for job, entry in consensus.items():
        m = metrics.get(job, {})
        by_config[arm(m)][m.get("case", job)] = (entry, m)

    print("\nPer configuration (consensus of the judges)")
    width = max(5, *(len(a) + 1 for a in by_config))
    print(f"{'arm':<{width}}{'n':>4}{'total':>8}{'redo%':>7}{'rec%':>6}{'USD':>8}" + "".join(f"{c[:5]:>7}" for c in CRITERIA))
    for config in sorted(by_config):
        rows = list(by_config[config].values())
        print(f"{config:<{width}}{len(rows):>4}{statistics.mean(r[0]['total'] for r in rows):>8.1f}"
              f"{100 * statistics.mean(r[0]['redo'] for r in rows):>6.0f}%{100 * statistics.mean(r[0]['record'] for r in rows):>5.0f}%"
              f"{statistics.mean(r[1].get('cost', 0) for r in rows):>8.4f}"
              + "".join(f"{statistics.mean(r[0][c] for r in rows):>7.2f}" for c in CRITERIA)
              + "".join(f"  {t.split('_')[-1] if t != 'delivers_title' else 'delivers'} {statistics.mean(r[0][t] for r in rows if t in r[0]):.2f}"
                        for t in TITLE_SCORES if any(t in r[0] for r in rows)))

    reference = by_config.get(args.reference, {})
    print(f"\nAgainst {args.reference} (paired by case)")
    print(f"{'arm':<{width}}{'pairs':>6}{'Δmean':>8}{'95% CI':>17}{'win%':>7}{'Δredo':>7}  worst criterion")
    for config in sorted(by_config):
        if config == args.reference:
            continue
        shared = [case for case in by_config[config] if case in reference]
        if not shared:
            continue
        diffs = [by_config[config][c][0]["total"] - reference[c][0]["total"] for c in shared]
        low, high = bootstrap(diffs)
        wins = sum(1.0 if d > 1e-9 else 0.5 if abs(d) <= 1e-9 else 0.0 for d in diffs) / len(diffs)
        redo = statistics.mean(by_config[config][c][0]["redo"] - reference[c][0]["redo"] for c in shared)
        drops = {name: statistics.mean(by_config[config][c][0][name] - reference[c][0][name] for c in shared) for name in CRITERIA}
        worst = min(drops, key=drops.get)
        print(f"{config:<{width}}{len(shared):>6}{statistics.mean(diffs):>8.1f}  [{low:6.1f}, {high:5.1f}]{100 * wins:>6.0f}%"
              f"{100 * redo:>6.0f}pp  {worst} {drops[worst]:+.2f}")
        if args.segment:
            segments = defaultdict(list)
            for case, d in zip(shared, diffs):
                segments[by_config[config][case][1].get(args.segment, "?")].append(d)
            for name, values in sorted(segments.items()):
                losses = sum(d < -1e-9 for d in values)
                print(f"      {args.segment}={name:<14}{len(values):>3} pairs  Δ{statistics.mean(values):+6.1f}  lost {losses}")

    with open(os.path.join(args.folder, "scores.json"), "w") as f:
        json.dump({"consensus": consensus, "judges": {j: results[j] for j in results}}, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
