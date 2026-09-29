# Synthetic email diagnostics

Developer-only, separately invoked harness. It compiles the **same** app-layer `MailReviewPreparation.swift` and `EmailBodyRenderer.swift` and links the production PaperloftKit. The only production refactor moves `MailReviewPreparation` unchanged from AppModel to a shared source file. It is included in both the main app's synchronized source folder and the unit target's explicit sources.

Predictions enumerate only this checkout's `Tests/MailFixtures/*.eml`. They never read labels, select an expected candidate, open a mailbox, or read private/holdout directories. Each original is hashed before/after. Every attempted attachment and available body is recorded with selected state, identity/hash, model fields or errors; omitted/unrendered bodies have no invented fields. Body extraction uses the renderer's header-free `bodyText` plus production low-confidence envelope hints. The harness does not file receipts or exercise the app's durable inbox/Message-ID ledger.

## Build and run

```
scripts/build_email_diagnostics.sh
python3 Tools/EmailDiagnostics/test_projection.py
```

The build supports Xcode 27's swiftbuild product object and older SwiftPM object layouts. Release optimization, Swift 6 complete concurrency and warnings-as-errors apply. Build manifest records revision, dirty state and relevant source hashes. The script builds only; it never runs a model.

Reserve the project's exclusive GUI lock before running the AppKit/WebKit harness, even though it uses prohibited activation and displays no window. Root currently coordinates that lock. With ownership established, a five-message parser smoke is:

```
build/email-diagnostics/EmailDiagnostics parser automatic "$PWD/build/email-diagnostics/parser-smoke-UNIQUE" email-001 email-029 email-030 email-053 email-065
python3 scripts/project_email_diagnostics.py build/email-diagnostics/parser-smoke-UNIQUE
python3 scripts/score_eval.py --mode private --labels build/email-diagnostics/parser-smoke-UNIQUE/body-labels.jsonl --predictions build/email-diagnostics/parser-smoke-UNIQUE/body-predictions.jsonl
```

Output must be a new immediate child of `build/email-diagnostics`; an existing directory is refused. Input IDs are optional, but **omitting them evaluates all 80 messages**. `parser` and `system` are explicit backend choices; use system after the parser smoke is sound, with a separately recorded evaluation. `automatic` uses the app's WebKit/native-fallback policy. `native` explicitly exercises only its native renderer and must be reported as such. The standalone process is not App Sandbox; sandbox renderer behavior has separate native evidence.

Raw predictions and run/build manifests are retained. An exclusive directory claim prevents run overwrite. Fixture hashes are fixed in the run manifest, the binary is checked against its build manifest, and projection outputs refuse overwrites. `projection-manifest.json` links raw/run/label/fixture/output hashes; changed fixture bytes fail closed. Scoring adapter writes `labels.jsonl`, `predictions.jsonl`, their `body-` subsets, `candidate-truth.jsonl`, `selection-observations.jsonl`, and `projection-summary.json`. No production extraction reads those outputs. The adapter rejects repeated/unknown IDs. Declared run IDs, not successfully produced rows, define the denominator. Wrong/ambiguous document identity or a changed original cannot earn field accuracy. Missing rows remain missing predictions for the frozen scorer.

## Interpretation

`--mode private` above is the frozen scorer's **report-only mode with explicit synthetic paths**; it does not authorize or access private data. Never substitute `scripts/eval.sh --private`, which points to real private samples. Exit zero is not an accuracy gate. Category is unlabelled and its scorer output must be disregarded. Do not append these observations to the 1.0 gated score history.

Selection truth is a provisional, documented generator contract: body for body/negative groups; the first PDF for PDF/mixed groups. The separate adapter uses Python's standard MIME parser to record the first PDF's hash and ordinal. Existing corpus integrity tests check its text against the labelled fields. Count-only matching is insufficient, so wrong PDFs cannot receive field credit. Independent truth/difficulty approval is still required before formal email evaluation. No expected-document decisions enter the runner or product code.

The 80 fixtures have eight repeating simple text layouts, sixteen merchants, uncomplicated selectable PDFs, and terms-only mixed distractions. These diagnostics do not establish AC-103–105, fresh holdout performance, diverse real-world email accuracy, UI performance or end-to-end filing correctness. Preserve unsuccessful rows and all renderer/model errors. Formal scorer extension and add-on baseline remain pending.
