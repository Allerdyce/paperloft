import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("projection", REPO / "scripts/project_email_diagnostics.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=REPO / "build")
        self.root = Path(self.temp.name)
        self.old = module.ROOT, module.FIXTURES
        module.ROOT = self.root
        module.FIXTURES = self.root / "Tests/MailFixtures"
        module.FIXTURES.mkdir(parents=True)
        self.run = self.root / "build/email-diagnostics/run"
        self.run.mkdir(parents=True)
        self.labels = [{"id": "body", "group": "body", "expectedBodySelected": True, "expectedReceiptCount": 1, "receipt": {"kind": "receipt", "vendor": "Synthetic", "date": "2026-01-01", "total": "1.00"}}]
        (module.FIXTURES / "labels.jsonl").write_text(json.dumps(self.labels[0]) + "\n")
        (module.FIXTURES / "body.eml").write_bytes(b"synthetic")
        self.serial = 0

    def tearDown(self):
        module.ROOT, module.FIXTURES = self.old
        self.temp.cleanup()

    def row(self):
        return {"id": "body", "sourceHash": module.hashlib.sha256(b"synthetic").hexdigest(), "sourcePreserved": True, "candidates": [{"source": "body", "selected": True, "fields": dict(self.labels[0]["receipt"])}]}

    def project(self, rows):
        self.serial += 1
        self.run = self.root / "build/email-diagnostics" / ("run-" + str(self.serial))
        self.run.mkdir()
        (self.run / "run-manifest.json").write_text(json.dumps({"ids": ["body"], "fixtureHashes": {"body": module.hashlib.sha256(b"synthetic").hexdigest()}}))
        module.write_rows(self.run / "raw-predictions.jsonl", rows)
        module.project(self.run)
        return (self.run / "body-predictions.jsonl").read_text()

    def testCorrectBodyPreservesTruthWithoutInventedCategory(self):
        result = json.loads(self.project([self.row()]))
        self.assertEqual(result["total"], "1.00")
        self.assertIsNone(result["category"])
        self.assertNotIn("category", json.loads((self.run / "body-labels.jsonl").read_text()))

    def testMissingAndAmbiguousPredictionsRemainFailures(self):
        self.assertEqual(self.project([]), "")
        self.assertEqual(len((self.run / "body-labels.jsonl").read_text().splitlines()), 1)
        row = self.row(); row["candidates"] *= 2
        self.assertEqual(self.project([row]), "")

    def testWrongIdentityOrChangedOriginalCannotEarnFields(self):
        row = self.row(); row["candidates"][0]["source"] = "attachment"
        self.assertEqual(self.project([row]), "")
        row = self.row(); row["sourcePreserved"] = False
        self.assertEqual(self.project([row]), "")

    def testProjectionRefusesOverwriteAndRecordsInputHashes(self):
        self.project([self.row()])
        before = (self.run / "body-predictions.jsonl").read_bytes()
        with self.assertRaises(FileExistsError): module.project(self.run)
        self.assertEqual((self.run / "body-predictions.jsonl").read_bytes(), before)
        manifest = json.loads((self.run / "projection-manifest.json").read_text())
        self.assertEqual(manifest["rawSHA256"], module.hashlib.sha256((self.run / "raw-predictions.jsonl").read_bytes()).hexdigest())

    def testDuplicateAndUnknownRowsFailClosed(self):
        with self.assertRaises(ValueError): self.project([self.row(), self.row()])
        row = self.row(); row["id"] = "unknown"
        with self.assertRaises(ValueError): self.project([row])

if __name__ == "__main__":
    unittest.main()
