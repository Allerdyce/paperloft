#!/usr/bin/env python3
"""Verifier-owned AC-12 checker. Reads manifest.json written by the IndependentExport harness and checks
each accountant pack against the verifier's own expectations: CSV parses strictly (Python csv, strict=True),
row count matches the range, category and month totals match to the minor unit, summary.pdf opens and its
category/month/tax sections equal the CSV-derived and generator-derived lines, every listed file exists with
the recorded SHA-256, and the ZIP carries the same CSV and files."""
import collections, csv, decimal, hashlib, io, json, pathlib, sys, unicodedata, zipfile

work = pathlib.Path(sys.argv[1])
manifest = json.loads((work / "manifest.json").read_text())
records = {r["id"]: r for r in manifest["records"]}
HEADER = ["date", "vendor", "category", "kind", "currency", "total", "total_minor_units", "tax", "file", "sha256"]
failures, report = [], []
zip_utf8_flag, zip_nfd_names = set(), [0]  # observations only (portability), not AC-12 checks

def fmt(minor, digits):
    if digits == 0:
        return str(minor)
    sign = "-" if minor < 0 else ""
    minor = abs(minor)
    return f"{sign}{minor // 10 ** digits}.{minor % 10 ** digits:0{digits}d}"

def check(cond, message):
    if not cond:
        failures.append(message)
    return cond

def section(lines, start, stop):
    try:
        i = lines.index(start)
    except ValueError:
        return None
    out = []
    for line in lines[i + 1:]:
        if line == stop:
            return out
        if line:
            out.append(line)
    return out

digits_by_currency = {r["currency"]: r["digits"] for r in manifest["records"]}
for pack in manifest["packs"]:
    name = pack["name"]
    folder = pathlib.Path(pack["folder"])
    expected = [records[i] for i in pack["expectedIDs"]]
    raw = (folder / "transactions.csv").read_bytes()
    text = raw.decode("utf-8")  # strict: raises on invalid UTF-8
    rows = list(csv.reader(io.StringIO(text, newline=""), strict=True))
    check(rows and rows[0] == HEADER, f"{name}: header {rows[:1]}")
    data = rows[1:]
    check(all(len(r) == 10 for r in data), f"{name}: a row does not have 10 fields")
    check(len(data) == len(expected), f"{name}: {len(data)} CSV rows, expected {len(expected)}")
    got = collections.Counter((r[0], r[1], r[2], r[4], int(r[6]), r[7], r[9]) for r in data)
    want = collections.Counter((e["date"], e["vendor"], e["category"], e["currency"], e["minor"],
                                "" if e.get("tax") is None else fmt(e["tax"], e["digits"]), e["sha256"]) for e in expected)
    check(got == want, f"{name}: CSV rows differ from the generated receipts in range")
    listed = set()
    cat_csv, month_csv, cat_dec = collections.Counter(), collections.Counter(), collections.Counter()
    for r in data:
        check(r[3] == "receipt", f"{name}: kind {r[3]!r}")
        check(r[5] == fmt(int(r[6]), digits_by_currency[r[4]]), f"{name}: total {r[5]!r} vs minor {r[6]}")
        check(not r[8].startswith("/") and ".." not in r[8].split("/"), f"{name}: unsafe listed path {r[8]!r}")
        path = folder / r[8]
        if check(path.is_file() and not path.is_symlink(), f"{name}: listed file missing {r[8]!r}"):
            check(hashlib.sha256(path.read_bytes()).hexdigest() == r[9], f"{name}: hash mismatch {r[8]!r}")
        listed.add(r[8])
        cat_csv[r[2] + " | " + r[4]] += int(r[6])
        month_csv[r[0][:7] + " | " + r[4]] += int(r[6])
        cat_dec[r[2] + " | " + r[4]] += decimal.Decimal(r[5]).scaleb(digits_by_currency[r[4]])
    check(dict(cat_csv) == pack["expectedCategoryTotals"], f"{name}: category totals from CSV differ from the generator's")
    check({k: int(v) for k, v in cat_dec.items()} == pack["expectedCategoryTotals"], f"{name}: decimal totals differ")
    check(dict(month_csv) == pack["expectedMonthTotals"], f"{name}: month totals differ")
    on_disk = {str(p.relative_to(folder)) for p in folder.rglob("*") if p.is_file()} - {"transactions.csv", "summary.pdf"}
    check(on_disk == listed, f"{name}: files in pack {len(on_disk)} vs listed {len(listed)}")
    # summary.pdf
    check(pack["pdfOpened"] and pack["pdfPages"] > 0, f"{name}: summary.pdf did not open")
    lines = [l.strip() for l in pathlib.Path(pack["pdfTextFile"]).read_text().splitlines()]
    check(f"{len(expected)} documents" in lines, f"{name}: PDF document count line missing")
    check(any("Not tax advice" in l for l in lines), f"{name}: PDF lacks 'Not tax advice'")
    cur = lambda key: key.rsplit(" | ", 1)[1]
    want_cat = sorted(f"{k} | {fmt(v, digits_by_currency[cur(k)])}" for k, v in cat_csv.items())
    want_month = sorted(f"{k} | {fmt(v, digits_by_currency[cur(k)])}" for k, v in month_csv.items())
    got_cat = section(lines, "Totals by category", "Totals by month")
    got_month = section(lines, "Totals by month", "Recorded tax by currency")
    check(got_cat is not None and sorted(got_cat) == want_cat, f"{name}: PDF category section != CSV totals\n  pdf={got_cat}\n  csv={want_cat}")
    check(got_month is not None and sorted(got_month) == want_month, f"{name}: PDF month section != CSV totals")
    tax = collections.defaultdict(lambda: [0, 0, 0])
    for e in expected:
        t = tax[e["currency"]]
        if e.get("tax") is None:
            t[2] += 1
        else:
            t[0] += e["tax"]; t[1] += 1
    want_tax = sorted(f"{c} | {'Unknown' if v[1] == 0 else fmt(v[0], digits_by_currency[c])} | {v[1]} recorded | {v[2]} unknown" for c, v in tax.items())
    got_tax = [l for l in lines if l.count(" | ") == 3 and l.endswith(" unknown")]
    check(sorted(got_tax) == want_tax, f"{name}: PDF tax lines differ")
    # ZIP
    if check(pack["zip"] and pathlib.Path(pack["zip"]).is_file(), f"{name}: ZIP missing"):
        # Apple's archiver writes UTF-8 (NFD) names without the ZIP UTF-8 flag; decode them explicitly.
        with zipfile.ZipFile(pack["zip"]) as archive:
            infos = archive.infolist()
            def entry_name(info):
                return info.filename if info.flag_bits & 0x800 else info.filename.encode("cp437").decode("utf-8")
            names = {entry_name(i): i for i in infos}
            csv_entry = [n for n in names if n.endswith("/transactions.csv")]
            if check(len(csv_entry) == 1, f"{name}: ZIP CSV entries {csv_entry}"):
                check(archive.read(names[csv_entry[0]]) == raw, f"{name}: ZIP CSV differs from folder CSV")
            prefix = folder.name + "/"
            zipped_files = {unicodedata.normalize("NFC", n[len(prefix):]): names[n] for n in names
                            if n.startswith(prefix) and not n.endswith("/") and n[len(prefix):] not in ("transactions.csv", "summary.pdf")}
            check(set(zipped_files) == {unicodedata.normalize("NFC", p) for p in listed}, f"{name}: ZIP document set differs from CSV")
            for row in data:
                info = zipped_files.get(unicodedata.normalize("NFC", row[8]))
                if check(info is not None, f"{name}: {row[8]!r} not in ZIP"):
                    check(hashlib.sha256(archive.read(info)).hexdigest() == row[9], f"{name}: ZIP bytes differ for {row[8]!r}")
            zip_utf8_flag.update(bool(i.flag_bits & 0x800) for i in infos)
            zip_nfd_names[0] += sum(1 for n in names if unicodedata.normalize("NFC", n) != n)
    report.append(f"{name} [{pack['start']}..{pack['end']}]: {len(data)} rows (expected {len(expected)}), "
                  f"{len(cat_csv)} category totals, {len(month_csv)} month totals, {pack['pdfPages']} PDF page(s), "
                  f"{len(listed)} files listed and present")

print(f"seed {manifest['seed']}, {len(records)} receipts filed")
print("\n".join(report))
print(f"observation (not AC-12): ZIP UTF-8 name flag values {sorted(zip_utf8_flag)}; entries whose names are not NFC: {zip_nfd_names[0]}")
if failures:
    print("FAILURES:\n- " + "\n- ".join(failures))
    sys.exit(1)
print("AC-12 independent check: PASS")
