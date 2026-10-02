import re, sys, json, pathlib
root = pathlib.Path(sys.argv[1])
out = {}
for line in (root / "ACCEPTANCE.lock").read_text().splitlines():
    parts = line.split(None, 1)
    if len(parts) != 2: continue
    path = parts[1].strip()
    if not path.endswith(".swift"): continue
    text = (root / path).read_text()
    classes = []
    # XCTest: class Foo: XCTestCase { ... func testX
    current = None
    for ln in text.splitlines():
        m = re.match(r'\s*(?:final\s+)?(?:@\w+\s+)*class\s+(\w+)\s*:\s*XCTestCase', ln)
        if m: current = m.group(1)
        m2 = re.match(r'\s*(?:@\w+\s+)*(?:override\s+)?func\s+(test\w*)\s*\(', ln)
        if m2 and current:
            out.setdefault(path, []).append(f"{current}/{m2.group(1)}()")
        m3 = re.match(r'\s*@Test', ln)
        if m3:
            out.setdefault(path, []).append("SWIFT-TESTING:" + ln.strip())
    out.setdefault(path, out.get(path, []))
json.dump(out, sys.stdout, indent=1)
