# AC-10: understanding two documents at once doesn't raise throughput (2026-09-30)

**Question:** AC-10 measures throughput (100 documents in ≤ 240 s), not latency. Would the app finish sooner if it understood two documents at the same time?

**Method:** `Tools/ConcurrencyProbe` (`scripts/build_concurrency_probe.sh`) runs the production `SystemBackend.extract` (field extraction with concurrent classification) on new, single-use synthetic receipts and invoices, 250–700 characters each.
- No fixture is used and nothing is resubmitted.
- Arms alternate in blocks of six: one at a time, then two at a time with a bounded task group. Heat and background load therefore affect both arms.
- The raw rows are in `concurrency-probe-20260930.jsonl`.

| Arm | Documents | Seconds per document |
| --- | --- | --- |
| One at a time | 18 | **2.81** (blocks 3.03, 2.68, 2.71) |
| Two at a time | 18 | **2.83** (blocks 2.57, 2.99, 2.93) |

Each one-at-a-time block had one failed extraction (a thrown error, not retried); the two-at-a-time blocks had one in total.

**Conclusion:** there is no throughput gain. The on-device model serializes requests from separate sessions, so a concurrent pipeline would add complexity for nothing. This rules out a third approach, after prewarming (rejected earlier) and concurrent classification (5–10%, adopted).

With the current schema, a short synthetic document takes about 2.8 s of model time, before OCR (about 0.2 s). The fixture mix measured 3.1–3.6 s. The 2.4 s-per-document budget can't be met by scheduling. See the AC-10 entry in PROPOSALS.md for the options.
