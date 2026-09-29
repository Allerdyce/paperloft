#!/usr/bin/env python3
"""Truth-side projection only; field matching belongs to unchanged score_eval.py.
No private inputs, no thresholds, and no email-gate verdicts.
"""
import argparse
import email.policy
import hashlib
import json
from email.parser import BytesParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "Tests/MailFixtures"

def write_rows(path, rows):
    with path.open("x") as stream:
        stream.write("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows))

def project(run):
    run = run.resolve()
    if run.parent != (ROOT / "build/email-diagnostics").resolve():
        raise ValueError("Only an explicit local synthetic diagnostic run is accepted")
    output_names = ["labels.jsonl", "predictions.jsonl", "body-labels.jsonl", "body-predictions.jsonl", "candidate-truth.jsonl", "selection-observations.jsonl", "projection-summary.json", "projection-manifest.json"]
    if any((run / name).exists() for name in output_names):
        raise FileExistsError("Projection outputs are immutable; preserve this run and choose a new run")
    labels = {}
    for row in map(json.loads, (FIXTURES / "labels.jsonl").read_text().splitlines()):
        if row["id"] in labels: raise ValueError("Repeated truth identifier")
        labels[row["id"]] = row
    manifest = json.loads((run / "run-manifest.json").read_text())
    ids = manifest["ids"]
    if not ids or len(set(ids)) != len(ids) or set(ids) - labels.keys():
        raise ValueError("Unknown or repeated synthetic fixture identifiers")
    raw = {}
    for line in (run / "raw-predictions.jsonl").read_text().splitlines():
        row = json.loads(line)
        if row["id"] in raw or row["id"] not in ids:
            raise ValueError("Unknown or repeated prediction identifier")
        raw[row["id"]] = row
    truths, predictions, body_truths, body_predictions, selections, identity_truth = [], [], [], [], [], []
    for id in ids:
        label, prediction = labels[id], raw.get(id, {})
        truth = {"id": id, **label.get("receipt", {"kind": "not_receipt"})}
        truths.append(truth)
        if label["group"] == "body": body_truths.append(truth)
        original = (FIXTURES / (id + ".eml")).read_bytes()
        fixture_hash = hashlib.sha256(original).hexdigest()
        if manifest["fixtureHashes"].get(id) != fixture_hash:
            raise ValueError("Fixture bytes changed since prediction manifest; preserve the run")
        preserved = prediction.get("sourcePreserved") is True and prediction.get("sourceHash") == fixture_hash
        chosen = [c for c in prediction.get("candidates", []) if c["selected"]]
        expected = "body" if label["expectedBodySelected"] else "attachment"
        expected_hash = None
        if expected == "attachment":
            # Explicit development-corpus contract: generator emits receipt PDF
            # first, followed by terms. This provisional sidecar is not an
            # independently approved truth set or a rule in prediction code.
            message = BytesParser(policy=email.policy.default).parsebytes(original)
            pdfs = [p.get_payload(decode=True) for p in message.walk() if p.get_content_type() == "application/pdf"]
            if len(pdfs) != label["expectedPDFParts"]: raise ValueError("Unexpected fixture PDF structure")
            expected_hash = hashlib.sha256(pdfs[0]).hexdigest()
        identity_truth.append({"id": id, "source": expected, "attachmentIndex": 0 if expected == "attachment" else None, "contentHash": expected_hash, "basis": "provisional generator contract"})
        usable = preserved and not prediction.get("error") and len(chosen) == 1 and chosen[0].get("fields") is not None and not chosen[0].get("error") and not chosen[0]["fields"].get("classificationError")
        correct_identity = usable and chosen[0]["source"] == expected and (expected == "body" or (chosen[0].get("attachmentIndex") == 0 and chosen[0].get("contentHash") == expected_hash))
        # Wrong/ambiguous selections cannot earn receipt-field accuracy by
        # choosing whichever candidate happens to match the truth.
        if correct_identity:
            row = {"id": id, **{f: chosen[0]["fields"].get(f) for f in ("kind", "vendor", "date", "total", "category")}}
            predictions.append(row)
            if label["group"] == "body": body_predictions.append(row)
        receipt_kinds = {"receipt", "invoice", "bill"}
        receipt_count = sum(c.get("fields", {}).get("kind") in receipt_kinds for c in chosen if c.get("fields"))
        selections.append({"id": id, "correctIdentity": bool(correct_identity), "expectedReceiptCount": label["expectedReceiptCount"], "actualReceiptCount": receipt_count,
            "bodyAlongsideExpectedReceiptAttachment": expected == "attachment" and any(c["source"] == "body" for c in chosen),
            "correctNegative": label["group"] == "not_receipt" and correct_identity and chosen[0]["fields"].get("kind") == "not_receipt",
            "sourcePreserved": preserved})
    for name, rows in [("labels", truths), ("predictions", predictions), ("body-labels", body_truths), ("body-predictions", body_predictions), ("candidate-truth", identity_truth), ("selection-observations", selections)]:
        write_rows(run / (name + ".jsonl"), rows)
    summary = {"status": "diagnostic only; no gate verdict", "messages": len(ids), "bodyMessages": len(body_truths), "category": "unlabelled; disregard scorer category output",
        "exactIdentityObservations": sum(r["correctIdentity"] for r in selections), "bodySuppressionViolations": sum(r["bodyAlongsideExpectedReceiptAttachment"] for r in selections),
        "correctNegatives": sum(r["correctNegative"] for r in selections), "negativeMessages": sum(labels[id]["group"] == "not_receipt" for id in ids),
        "allSourcesPreserved": all(r["sourcePreserved"] for r in selections), "selectionTruth": "provisional generator contract; independent difficulty/truth approval pending"}
    with (run / "projection-summary.json").open("x") as stream:
        stream.write(json.dumps(summary, indent=2) + "\n")
    evidence = {"rawSHA256": hashlib.sha256((run / "raw-predictions.jsonl").read_bytes()).hexdigest(),
        "runManifestSHA256": hashlib.sha256((run / "run-manifest.json").read_bytes()).hexdigest(),
        "labelsSHA256": hashlib.sha256((FIXTURES / "labels.jsonl").read_bytes()).hexdigest(),
        "fixtureHashes": manifest["fixtureHashes"],
        "projectionScriptSHA256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "outputHashes": {name: hashlib.sha256((run / name).read_bytes()).hexdigest() for name in output_names[:-1]}}
    with (run / "projection-manifest.json").open("x") as stream:
        stream.write(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(summary, sort_keys=True))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    project(parser.parse_args().run)
