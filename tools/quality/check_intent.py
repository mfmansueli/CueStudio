#!/usr/bin/env python3
"""Check exact required literals in collected intent samples; semantic quality stays unvalidated.

  python3 tools/quality/check_intent.py <quality-run.json> > build/reports/intent-review.json

No network, model, dependencies or device required. Input comes from collect.py. Missing/failed
generations never count as passing. A literal pass is not a factual, creative or semantic verdict.
"""

import argparse
import json
import re
import unicodedata


def contains_literal(text, literal):
    text = unicodedata.normalize("NFC", text)
    literal = unicodedata.normalize("NFC", literal)
    if not literal:
        return False

    def bounded(char):
        return char == "_" or unicodedata.category(char)[0] in "NM" or "LATIN" in unicodedata.name(char, "")

    for match in re.finditer(re.escape(literal), text):
        before = text[match.start() - 1] if match.start() else None
        after = text[match.end()] if match.end() < len(text) else None
        if bounded(literal[0]) and before and bounded(before):
            continue
        if bounded(literal[-1]) and after and bounded(after):
            continue
        return True
    return False


def evaluate(sample):
    text = sample.get("text") or ""
    generated = bool(text.strip()) and not sample.get("failure")
    required = sample.get("requiredLiterals")
    missing = [item for item in (required or []) if not contains_literal(text, item)]
    if not generated:
        status = "not_generated"
    elif required is None:
        status = "not_configured"
    elif not required:
        status = "not_applicable"
    else:
        status = "fail" if missing else "pass"
    return {
        "caseID": sample.get("caseID"), "run": sample.get("run"), "model": sample.get("model"),
        "requestedReasoning": sample.get("requestedReasoning") or "default",
        "literal_status": status, "missing_literals": missing,
        "quality_status": "not_validated", "expected_direction_for_review": sample.get("expectedDirection"),
        "human_review_checks": sample.get("reviewChecks") or [],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("samples")
    args = parser.parse_args()
    with open(args.samples, encoding="utf-8") as handle:
        samples = json.load(handle)
    if isinstance(samples, dict):
        samples = [samples]
    results = [evaluate(sample) for sample in samples if sample.get("caseID")]
    print(json.dumps({"samples": results, "semantic_quality": "not_validated"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
