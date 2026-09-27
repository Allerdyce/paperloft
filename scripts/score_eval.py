#!/usr/bin/env python3
"""Frozen extraction scorer for the Paperloft factory. Never edit this file.

The builder's scripts/eval.sh runs the app's extraction over a document set and
writes predictions; this script alone decides the score, so the thresholds and
matching rules in ACCEPTANCE.md (AC-03 to AC-06) cannot drift.

Inputs (JSON Lines, one object per document):
  labels       {"id", "kind", "vendor", "date", "total", "category", "tags": [...]}
  predictions  {"id", "kind", "vendor", "date", "total", "category"}
  kind is one of: receipt, invoice, bill, not_receipt
  date is YYYY-MM-DD; total is a decimal string such as "74.90"
  tags (labels only) may include: photo, long, confusable

Modes and thresholds:
  fixtures  AC-03  >= 150 docs; date .97 total .97 vendor .92 kind .95 category .80;
                   also enforces the fixture mix (30% photo, 20% long,
                   10% not_receipt, 10% confusable)
  holdout   AC-04  >= 60 docs; AC-03 thresholds minus 3 points; totals only,
                   never per-document output
  parser    AC-05  >= 150 docs; date .90 total .90; also reports the
                   difficulty check (parser total above 98% = fixtures too easy)
  private   AC-06  reported only, never gated; totals only

Exit 0 when every gated threshold is met, 1 otherwise, 2 on bad input.
Python 3.9 standard library only.
"""

import argparse
import csv
import datetime
import difflib
import json
import os
import re
import sys
from decimal import Decimal, InvalidOperation

FIELDS = ["date", "total", "vendor", "kind", "category"]
BASE = {"date": 0.97, "total": 0.97, "vendor": 0.92, "kind": 0.95, "category": 0.80}
MODES = {
    "fixtures": {"min_docs": 150, "thresholds": dict(BASE), "details": True, "mix": True},
    "holdout": {"min_docs": 60, "thresholds": {k: v - 0.03 for k, v in BASE.items()}, "details": False, "mix": False},
    "parser": {"min_docs": 150, "thresholds": {"date": 0.90, "total": 0.90}, "details": True, "mix": False},
    "private": {"min_docs": 1, "thresholds": {}, "details": False, "mix": False},
}
MIX = {"photo": 0.30, "long": 0.20, "not_receipt": 0.10, "confusable": 0.10}
KINDS = {"receipt", "invoice", "bill", "not_receipt"}
VENDOR_SUFFIXES = {"inc", "llc", "ltd", "co", "corp", "corporation", "company", "store", "the"}
DIFFICULTY_LIMIT = 0.98


def load(path):
    rows = {}
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                sys.exit("bad JSON on line %d of %s" % (n, path))
            doc_id = str(obj.get("id", ""))
            if not doc_id:
                sys.exit("missing id on line %d of %s" % (n, path))
            if doc_id in rows:
                sys.exit("duplicate id %s in %s" % (doc_id, path))
            rows[doc_id] = obj
    return rows


def norm_vendor(v):
    words = re.sub(r"[^a-z0-9 ]+", " ", str(v or "").lower()).split()
    words = [w for w in words if w not in VENDOR_SUFFIXES and not re.fullmatch(r"\d+", w)]
    return " ".join(words)


def money(v):
    try:
        return Decimal(str(v).replace(",", "").replace("$", "").strip()).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        return None


def match(field, truth, guess):
    if guess is None:
        return False
    if field == "total":
        t, g = money(truth), money(guess)
        return t is not None and t == g
    if field == "vendor":
        t, g = norm_vendor(truth), norm_vendor(guess)
        return bool(t) and (t == g or difflib.SequenceMatcher(None, t, g).ratio() >= 0.85)
    if field in ("kind", "category"):
        return str(truth).strip().lower() == str(guess).strip().lower()
    return str(truth).strip() == str(guess).strip()  # date


def main():
    ap = argparse.ArgumentParser(description="Frozen extraction scorer (see module docstring).")
    ap.add_argument("--labels", required=True)
    ap.add_argument("--predictions", required=True)
    ap.add_argument("--mode", required=True, choices=sorted(MODES))
    ap.add_argument("--history", help="append a row to this CSV (not in holdout or private mode)")
    ap.add_argument("--commit", default="")
    ap.add_argument("--details", action="store_true", help="list mismatches (fixtures and parser modes only)")
    args = ap.parse_args()

    cfg = MODES[args.mode]
    labels = load(args.labels)
    preds = load(args.predictions)

    bad_kinds = [i for i, r in labels.items() if r.get("kind") not in KINDS]
    if bad_kinds:
        sys.exit("labels with unknown kind: %s" % ", ".join(sorted(bad_kinds)[:5]))
    if len(labels) < cfg["min_docs"]:
        print("FAIL %s needs at least %d documents, found %d" % (args.mode, cfg["min_docs"], len(labels)))
        return 1

    extra = set(preds) - set(labels)
    if extra:
        print("WARN %d predictions have no label and were ignored" % len(extra))

    scored = {f: [0, 0] for f in FIELDS}  # field -> [correct, total]
    misses = []
    for doc_id, truth in labels.items():
        guess = preds.get(doc_id, {})
        for field in FIELDS:
            if field != "kind" and truth.get("kind") == "not_receipt":
                continue
            scored[field][1] += 1
            if match(field, truth.get(field), guess.get(field)):
                scored[field][0] += 1
            else:
                misses.append((doc_id, field, truth.get(field), guess.get(field)))

    ok = True
    acc = {}
    print("mode=%s documents=%d missing_predictions=%d" % (args.mode, len(labels), len(set(labels) - set(preds))))
    for field in FIELDS:
        correct, total = scored[field]
        acc[field] = correct / total if total else 0.0
        need = cfg["thresholds"].get(field)
        if need is None:
            verdict = "REPORT"
        elif acc[field] + 1e-9 >= need:
            verdict = "PASS"
        else:
            verdict = "FAIL"
            ok = False
        need_s = "" if need is None else "  (needs %.1f%%)" % (need * 100)
        print("%-6s %-9s %6.2f%%  %d/%d%s" % (verdict, field, acc[field] * 100, correct, total, need_s))

    if cfg["mix"]:
        n = float(len(labels))
        for tag, need in sorted(MIX.items()):
            if tag == "not_receipt":
                have = sum(1 for r in labels.values() if r.get("kind") == "not_receipt")
            else:
                have = sum(1 for r in labels.values() if tag in (r.get("tags") or []))
            share = have / n
            verdict = "PASS" if share + 1e-9 >= need else "FAIL"
            ok = ok and verdict == "PASS"
            print("%-6s mix:%-11s %5.1f%%  (needs %.0f%%)" % (verdict, tag, share * 100, need * 100))

    if args.mode == "parser":
        verdict = "FAIL" if acc["total"] > DIFFICULTY_LIMIT else "PASS"
        print("%-6s difficulty: parser total %.2f%% (fixtures are too easy above %.0f%%)"
              % (verdict, acc["total"] * 100, DIFFICULTY_LIMIT * 100))

    if args.details and cfg["details"]:
        for doc_id, field, truth, guess in misses[:200]:
            print("MISS   %s %s: expected %r, got %r" % (doc_id, field, truth, guess))

    if args.history and args.mode not in ("holdout", "private"):
        new = not os.path.exists(args.history)
        with open(args.history, "a", newline="") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["time", "commit", "mode", "documents"] + FIELDS)
            w.writerow([datetime.datetime.now().isoformat(timespec="seconds"), args.commit, args.mode, len(labels)]
                       + ["%.4f" % acc[k] for k in FIELDS])

    if args.mode == "private":
        return 0
    print("SCORE %s: %s" % (args.mode, "PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
